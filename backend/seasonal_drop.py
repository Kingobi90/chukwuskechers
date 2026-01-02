"""Seasonal drop management - mark styles not in seasonal sheet as dropped."""
from typing import Dict, List
from backend.excel_parser import InventoryParser
from backend.database import get_session, Item


def process_seasonal_drop(excel_file_path: str, season_name: str) -> Dict:
    """
    Process seasonal drop: mark all styles NOT in the uploaded file as 'dropped'.
    
    Args:
        excel_file_path: Path to seasonal Excel file
        season_name: Name of the season (e.g., "Spring 2025")
        
    Returns:
        Dictionary with drop statistics and dropped items with locations
    """
    session = get_session()
    
    try:
        # Parse the seasonal Excel file to get active styles
        parser = InventoryParser(excel_file_path)
        active_styles = set(parser.get_all_styles())
        
        # Get all items from database
        all_items = session.query(Item).all()
        
        dropped_items = []
        kept_items = []
        
        for item in all_items:
            # Normalize style to 6 digits for comparison
            item_style = item.style.zfill(6)
            
            if item_style not in active_styles:
                # Mark as dropped
                old_status = item.status
                item.status = 'dropped'
                
                dropped_items.append({
                    'id': item.id,
                    'style': item.style,
                    'color': item.color,
                    'division': item.division,
                    'gender': item.gender,
                    'previous_status': old_status,
                    'location': None if not item.row_id else {
                        'room': item.row.shelf.room.name,
                        'shelf': item.row.shelf.name,
                        'row': item.row.name
                    }
                })
            else:
                kept_items.append(item.style)
        
        session.commit()
        
        # Organize dropped items by location
        items_with_location = [d for d in dropped_items if d['location']]
        items_without_location = [d for d in dropped_items if not d['location']]
        
        # Group by location
        by_location = {}
        for item in items_with_location:
            loc_key = f"{item['location']['room']} > {item['location']['shelf']} > {item['location']['row']}"
            if loc_key not in by_location:
                by_location[loc_key] = []
            by_location[loc_key].append(item)
        
        return {
            'season_name': season_name,
            'active_styles_count': len(active_styles),
            'dropped_count': len(dropped_items),
            'kept_count': len(kept_items),
            'dropped_with_location': len(items_with_location),
            'dropped_without_location': len(items_without_location),
            'dropped_items': dropped_items,
            'items_by_location': by_location,
            'items_without_location': items_without_location
        }
        
    except Exception as e:
        session.rollback()
        raise Exception(f"Seasonal drop failed: {str(e)}")
    finally:
        session.close()


def export_dropped_items_report(drop_result: Dict) -> str:
    """
    Generate a formatted text report of dropped items organized by location.
    
    Args:
        drop_result: Result from process_seasonal_drop
        
    Returns:
        Formatted report string
    """
    lines = []
    lines.append("=" * 80)
    lines.append(f"SEASONAL DROP REPORT - {drop_result['season_name']}")
    lines.append("=" * 80)
    lines.append("")
    lines.append(f"Active Styles in Season: {drop_result['active_styles_count']}")
    lines.append(f"Total Items Dropped: {drop_result['dropped_count']}")
    lines.append(f"  - With Location: {drop_result['dropped_with_location']}")
    lines.append(f"  - Without Location: {drop_result['dropped_without_location']}")
    lines.append("")
    lines.append("=" * 80)
    lines.append("DROPPED ITEMS BY WAREHOUSE LOCATION")
    lines.append("=" * 80)
    lines.append("")
    
    # Items organized by location
    for location, items in sorted(drop_result['items_by_location'].items()):
        lines.append(f"\n📍 {location}")
        lines.append("-" * 80)
        for item in sorted(items, key=lambda x: (x['style'], x['color'])):
            lines.append(f"  • {item['style']} - {item['color']} ({item['division']}, {item['gender']})")
        lines.append(f"  Total: {len(items)} items")
    
    # Items without location
    if drop_result['items_without_location']:
        lines.append("\n" + "=" * 80)
        lines.append("DROPPED ITEMS - NO LOCATION ASSIGNED")
        lines.append("=" * 80)
        for item in sorted(drop_result['items_without_location'], key=lambda x: (x['style'], x['color'])):
            lines.append(f"  • {item['style']} - {item['color']} ({item['division']}, {item['gender']}) - Status: {item['previous_status']}")
        lines.append(f"\nTotal: {len(drop_result['items_without_location'])} items")
    
    lines.append("\n" + "=" * 80)
    lines.append("END OF REPORT")
    lines.append("=" * 80)
    
    return "\n".join(lines)
