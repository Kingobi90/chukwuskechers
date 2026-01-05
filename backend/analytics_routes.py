from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func, and_, or_
from database import get_db, Item, StyleSummary, FileUpload, InventoryAction
from typing import List, Dict, Any, Optional
from datetime import datetime
import re
from collections import defaultdict

router = APIRouter(prefix="/analytics", tags=["analytics"])


def parse_date_from_filename(filename: str) -> Optional[datetime]:
    """Extract date from filename patterns like 'wof10.29.2025.xlsx' or 'wof 09.17.2025.xlsx'."""
    patterns = [
        r'(\d{1,2})\.(\d{1,2})\.(\d{4})',
        r'(\d{1,2})-(\d{1,2})-(\d{4})',
        r'(\d{4})\.(\d{1,2})\.(\d{1,2})',
        r'(\d{4})-(\d{1,2})-(\d{1,2})',
    ]
    
    for pattern in patterns:
        match = re.search(pattern, filename)
        if match:
            groups = match.groups()
            try:
                if len(groups[0]) == 4:
                    year, month, day = int(groups[0]), int(groups[1]), int(groups[2])
                else:
                    month, day, year = int(groups[0]), int(groups[1]), int(groups[2])
                
                if 1 <= month <= 12 and 1 <= day <= 31:
                    return datetime(year, month, day)
            except (ValueError, IndexError):
                continue
    
    return None


@router.get("/files/comparison")
async def compare_files(db: Session = Depends(get_db)):
    """Compare each file against all other files collectively."""
    files = db.query(FileUpload).order_by(FileUpload.uploaded_at).all()
    
    if not files:
        return {"files": [], "total_files": 0}
    
    # Get all items across all files
    all_items = db.query(Item).all()
    all_items_set = {f"{item.style}_{item.color}" for item in all_items}
    all_styles_set = {item.style for item in all_items}
    
    comparisons = []
    
    for file in files:
        file_date = parse_date_from_filename(file.filename)
        
        # Items in this file
        items_in_file = db.query(Item).filter(
            Item.source_files.contains(file.filename)
        ).all()
        
        # Items NOT in this file (all other files)
        items_not_in_file = db.query(Item).filter(
            ~Item.source_files.contains(file.filename)
        ).all()
        
        # Categorize items
        unique_to_file = []  # Only in this file
        shared_with_some = []  # In this file + some others
        shared_with_all = []  # In this file + all other files
        
        for item in items_in_file:
            if len(item.source_files) == 1:
                unique_to_file.append(item)
            elif len(item.source_files) == len(files):
                shared_with_all.append(item)
            else:
                shared_with_some.append(item)
        
        # Styles analysis
        styles_in_file = {item.style for item in items_in_file}
        styles_not_in_file = {item.style for item in items_not_in_file}
        unique_styles_to_file = styles_in_file - styles_not_in_file
        
        # Division breakdown
        divisions = defaultdict(int)
        genders = defaultdict(int)
        statuses = defaultdict(int)
        widths = defaultdict(int)
        
        for item in items_in_file:
            if item.division:
                divisions[item.division] += 1
            if item.gender:
                genders[item.gender] += 1
            if item.status:
                statuses[item.status] += 1
            
            if '(ww)' in item.color.lower():
                widths['extra_wide'] += 1
            elif '(w)' in item.color.lower():
                widths['wide'] += 1
            else:
                widths['regular'] += 1
        
        # Placement metrics
        placed_items = [item for item in items_in_file if item.row_id is not None]
        
        # Calculate percentages
        total_items = len(items_in_file)
        unique_pct = (len(unique_to_file) / total_items * 100) if total_items > 0 else 0
        shared_pct = ((len(shared_with_some) + len(shared_with_all)) / total_items * 100) if total_items > 0 else 0
        contribution_to_total = (total_items / len(all_items) * 100) if len(all_items) > 0 else 0
        
        comparisons.append({
            "filename": file.filename,
            "file_date": file_date.isoformat() if file_date else None,
            "uploaded_at": file.uploaded_at.isoformat(),
            "total_items": total_items,
            "total_styles": len(styles_in_file),
            
            # Uniqueness metrics
            "unique_items": len(unique_to_file),
            "unique_items_pct": round(unique_pct, 2),
            "unique_styles": len(unique_styles_to_file),
            
            # Sharing metrics
            "shared_with_some": len(shared_with_some),
            "shared_with_all": len(shared_with_all),
            "shared_items_pct": round(shared_pct, 2),
            
            # Contribution to overall inventory
            "contribution_to_total_pct": round(contribution_to_total, 2),
            
            # Placement metrics
            "placed_items": len(placed_items),
            "placement_rate": round((len(placed_items) / total_items * 100), 2) if total_items > 0 else 0,
            
            # Breakdowns
            "divisions": dict(divisions),
            "genders": dict(genders),
            "statuses": dict(statuses),
            "widths": dict(widths),
            "status": file.status
        })
    
    return {
        "files": comparisons,
        "total_files": len(files),
        "total_items_all_files": len(all_items),
        "total_styles_all_files": len(all_styles_set)
    }


@router.get("/files/{filename}/details")
async def file_details(filename: str, db: Session = Depends(get_db)):
    """Get detailed analytics for a specific file."""
    file = db.query(FileUpload).filter_by(filename=filename).first()
    if not file:
        raise HTTPException(status_code=404, detail="File not found")
    
    items = db.query(Item).filter(
        Item.source_files.contains(filename)
    ).all()
    
    styles = db.query(StyleSummary).filter(
        StyleSummary.source_files.contains(filename)
    ).all()
    
    unique_items = [item for item in items if len(item.source_files) == 1]
    shared_items = [item for item in items if len(item.source_files) > 1]
    
    placed_items = [item for item in items if item.row_id is not None]
    
    divisions_breakdown = defaultdict(lambda: {"count": 0, "styles": set()})
    for item in items:
        if item.division:
            divisions_breakdown[item.division]["count"] += 1
            divisions_breakdown[item.division]["styles"].add(item.style)
    
    divisions_data = {
        div: {"count": data["count"], "unique_styles": len(data["styles"])}
        for div, data in divisions_breakdown.items()
    }
    
    return {
        "filename": filename,
        "file_date": parse_date_from_filename(filename).isoformat() if parse_date_from_filename(filename) else None,
        "uploaded_at": file.uploaded_at.isoformat(),
        "total_items": len(items),
        "total_styles": len(styles),
        "unique_items": len(unique_items),
        "shared_items": len(shared_items),
        "placed_items": len(placed_items),
        "placement_rate": round((len(placed_items) / len(items) * 100), 2) if items else 0,
        "divisions": divisions_data,
        "top_styles": [
            {"style": s.style, "color_count": s.color_count, "division": s.division}
            for s in sorted(styles, key=lambda x: x.color_count, reverse=True)[:10]
        ]
    }


@router.get("/trends/timeline")
async def timeline_trends(db: Session = Depends(get_db)):
    """Comprehensive trend analysis: growth/decline, new vs returning styles, seasonality."""
    files = db.query(FileUpload).order_by(FileUpload.uploaded_at).all()
    
    if not files:
        return {"timeline": [], "growth_metrics": {}, "seasonality": {}}
    
    timeline = []
    cumulative_styles = set()
    cumulative_items = set()
    previous_styles = set()
    previous_items = set()
    
    monthly_data = defaultdict(lambda: {
        "items": 0,
        "styles": set(),
        "new_styles": set(),
        "files": []
    })
    
    for idx, file in enumerate(files):
        file_date = parse_date_from_filename(file.filename)
        
        items = db.query(Item).filter(
            Item.source_files.contains(file.filename)
        ).all()
        
        current_styles = set()
        current_items = set()
        
        for item in items:
            item_key = f"{item.style}_{item.color}"
            current_items.add(item_key)
            current_styles.add(item.style)
        
        # Calculate new vs returning
        truly_new_styles = current_styles - cumulative_styles
        returning_styles = current_styles & previous_styles
        dropped_styles = previous_styles - current_styles if idx > 0 else set()
        
        truly_new_items = current_items - cumulative_items
        returning_items = current_items & previous_items
        
        # Growth calculations
        growth_rate = 0
        if idx > 0 and len(previous_items) > 0:
            growth_rate = ((len(current_items) - len(previous_items)) / len(previous_items)) * 100
        
        # Update cumulative
        cumulative_styles.update(current_styles)
        cumulative_items.update(current_items)
        
        # Seasonality tracking
        if file_date:
            month_key = file_date.strftime("%Y-%m")
            monthly_data[month_key]["items"] += len(items)
            monthly_data[month_key]["styles"].update(current_styles)
            monthly_data[month_key]["new_styles"].update(truly_new_styles)
            monthly_data[month_key]["files"].append(file.filename)
        
        timeline.append({
            "filename": file.filename,
            "file_date": file_date.isoformat() if file_date else None,
            "uploaded_at": file.uploaded_at.isoformat(),
            "items_in_file": len(items),
            "styles_in_file": len(current_styles),
            
            # New vs Returning
            "new_styles": len(truly_new_styles),
            "returning_styles": len(returning_styles),
            "dropped_styles": len(dropped_styles),
            "new_items": len(truly_new_items),
            "returning_items": len(returning_items),
            
            # Growth metrics
            "growth_rate": round(growth_rate, 2),
            "cumulative_styles": len(cumulative_styles),
            "cumulative_items": len(cumulative_items),
            
            # Retention
            "style_retention_rate": round((len(returning_styles) / len(previous_styles) * 100), 2) if len(previous_styles) > 0 else 0,
        })
        
        previous_styles = current_styles.copy()
        previous_items = current_items.copy()
    
    # Calculate overall growth metrics
    if len(timeline) > 1:
        first_file_items = timeline[0]["items_in_file"]
        last_file_items = timeline[-1]["items_in_file"]
        overall_growth = ((last_file_items - first_file_items) / first_file_items * 100) if first_file_items > 0 else 0
        avg_growth = sum(t["growth_rate"] for t in timeline[1:]) / (len(timeline) - 1) if len(timeline) > 1 else 0
    else:
        overall_growth = 0
        avg_growth = 0
    
    # Seasonality patterns
    seasonality = []
    for month, data in sorted(monthly_data.items()):
        seasonality.append({
            "month": month,
            "total_items": data["items"],
            "unique_styles": len(data["styles"]),
            "new_styles": len(data["new_styles"]),
            "files_count": len(data["files"]),
            "files": data["files"]
        })
    
    return {
        "timeline": timeline,
        "total_files": len(files),
        "final_unique_styles": len(cumulative_styles),
        "final_unique_items": len(cumulative_items),
        "growth_metrics": {
            "overall_growth_pct": round(overall_growth, 2),
            "avg_growth_rate": round(avg_growth, 2),
            "total_new_styles_added": len(cumulative_styles),
            "peak_inventory": max(t["cumulative_items"] for t in timeline) if timeline else 0,
        },
        "seasonality": seasonality
    }


@router.get("/comparison/overlap")
async def file_overlap_analysis(db: Session = Depends(get_db)):
    """Analyze overlap between different files."""
    files = db.query(FileUpload).all()
    
    if len(files) < 2:
        return {"message": "Need at least 2 files for overlap analysis", "overlaps": []}
    
    overlaps = []
    
    for i, file1 in enumerate(files):
        for file2 in files[i+1:]:
            items_both = db.query(Item).filter(
                and_(
                    Item.source_files.contains(file1.filename),
                    Item.source_files.contains(file2.filename)
                )
            ).all()
            
            items_file1_only = db.query(Item).filter(
                and_(
                    Item.source_files.contains(file1.filename),
                    ~Item.source_files.contains(file2.filename)
                )
            ).count()
            
            items_file2_only = db.query(Item).filter(
                and_(
                    Item.source_files.contains(file2.filename),
                    ~Item.source_files.contains(file1.filename)
                )
            ).count()
            
            overlaps.append({
                "file1": file1.filename,
                "file2": file2.filename,
                "shared_items": len(items_both),
                "file1_unique": items_file1_only,
                "file2_unique": items_file2_only,
                "overlap_percentage": round((len(items_both) / (len(items_both) + items_file1_only + items_file2_only) * 100), 2) if (len(items_both) + items_file1_only + items_file2_only) > 0 else 0
            })
    
    return {"overlaps": overlaps}


@router.get("/division/trends")
async def division_trends(db: Session = Depends(get_db)):
    """Deep dive into division performance across files with market share changes."""
    files = db.query(FileUpload).order_by(FileUpload.uploaded_at).all()
    
    if not files:
        return {"trends": [], "market_share_changes": {}, "division_summary": {}}
    
    trends = []
    all_divisions = set()
    division_timeline = defaultdict(list)
    
    for file in files:
        file_date = parse_date_from_filename(file.filename)
        
        items = db.query(Item).filter(
            Item.source_files.contains(file.filename)
        ).all()
        
        divisions = defaultdict(lambda: {
            "count": 0,
            "styles": set(),
            "placed": 0,
            "pending": 0
        })
        
        for item in items:
            if item.division:
                divisions[item.division]["count"] += 1
                divisions[item.division]["styles"].add(item.style)
                if item.row_id is not None:
                    divisions[item.division]["placed"] += 1
                if item.status == 'pending':
                    divisions[item.division]["pending"] += 1
        
        total_items = len(items)
        division_data = {}
        
        for div, data in divisions.items():
            all_divisions.add(div)
            market_share = (data["count"] / total_items * 100) if total_items > 0 else 0
            division_data[div] = {
                "count": data["count"],
                "unique_styles": len(data["styles"]),
                "market_share_pct": round(market_share, 2),
                "placed": data["placed"],
                "pending": data["pending"],
                "placement_rate": round((data["placed"] / data["count"] * 100), 2) if data["count"] > 0 else 0
            }
            
            division_timeline[div].append({
                "filename": file.filename,
                "date": file_date.isoformat() if file_date else None,
                "market_share": round(market_share, 2),
                "count": data["count"]
            })
        
        trends.append({
            "filename": file.filename,
            "file_date": file_date.isoformat() if file_date else None,
            "divisions": division_data,
            "total_items": total_items
        })
    
    # Calculate market share changes
    market_share_changes = {}
    for div in all_divisions:
        timeline = division_timeline[div]
        if len(timeline) >= 2:
            first_share = timeline[0]["market_share"]
            last_share = timeline[-1]["market_share"]
            change = last_share - first_share
            market_share_changes[div] = {
                "initial_share": first_share,
                "current_share": last_share,
                "change_pct": round(change, 2),
                "trend": "growing" if change > 0 else "declining" if change < 0 else "stable"
            }
    
    # Division summary across all files
    all_items = db.query(Item).all()
    division_summary = defaultdict(lambda: {
        "total_items": 0,
        "unique_styles": set(),
        "files": set()
    })
    
    for item in all_items:
        if item.division:
            division_summary[item.division]["total_items"] += 1
            division_summary[item.division]["unique_styles"].add(item.style)
            division_summary[item.division]["files"].update(item.source_files)
    
    summary = {
        div: {
            "total_items": data["total_items"],
            "unique_styles": len(data["unique_styles"]),
            "files_present_in": len(data["files"]),
            "market_share_pct": round((data["total_items"] / len(all_items) * 100), 2) if len(all_items) > 0 else 0
        }
        for div, data in division_summary.items()
    }
    
    return {
        "trends": trends,
        "all_divisions": sorted(list(all_divisions)),
        "market_share_changes": market_share_changes,
        "division_summary": summary,
        "division_timeline": {div: timeline for div, timeline in division_timeline.items()}
    }


@router.get("/placement/analytics")
async def placement_analytics(db: Session = Depends(get_db)):
    """Analyze placement statistics across files."""
    files = db.query(FileUpload).all()
    
    analytics = []
    
    for file in files:
        items = db.query(Item).filter(
            Item.source_files.contains(file.filename)
        ).all()
        
        placed = sum(1 for item in items if item.row_id is not None)
        pending = sum(1 for item in items if item.status == 'pending')
        
        by_status = defaultdict(int)
        for item in items:
            by_status[item.status] += 1
        
        analytics.append({
            "filename": file.filename,
            "total_items": len(items),
            "placed": placed,
            "pending": pending,
            "placement_rate": round((placed / len(items) * 100), 2) if items else 0,
            "by_status": dict(by_status)
        })
    
    return {"placement_analytics": analytics}


@router.get("/styles/performance")
async def style_performance_metrics(db: Session = Depends(get_db)):
    """Analyze style performance: frequency across files, one-offs, lifecycle tracking."""
    files = db.query(FileUpload).order_by(FileUpload.uploaded_at).all()
    all_items = db.query(Item).all()
    
    if not all_items:
        return {"style_metrics": [], "summary": {}}
    
    # Track each style's performance
    style_data = defaultdict(lambda: {
        "items": [],
        "colors": set(),
        "files": set(),
        "first_seen": None,
        "last_seen": None,
        "file_appearances": [],
        "divisions": set(),
        "placed_count": 0,
        "total_count": 0
    })
    
    # Build style timeline
    for item in all_items:
        style = item.style
        style_data[style]["items"].append(item.id)
        style_data[style]["colors"].add(item.color)
        style_data[style]["files"].update(item.source_files)
        style_data[style]["total_count"] += 1
        
        if item.division:
            style_data[style]["divisions"].add(item.division)
        if item.row_id is not None:
            style_data[style]["placed_count"] += 1
        
        # Track appearances in files
        for source_file in item.source_files:
            if source_file not in [f["filename"] for f in style_data[style]["file_appearances"]]:
                file_obj = next((f for f in files if f.filename == source_file), None)
                if file_obj:
                    file_date = parse_date_from_filename(source_file)
                    style_data[style]["file_appearances"].append({
                        "filename": source_file,
                        "date": file_date.isoformat() if file_date else None
                    })
    
    # Calculate metrics for each style
    style_metrics = []
    for style, data in style_data.items():
        appearances = sorted(data["file_appearances"], key=lambda x: x["date"] or "")
        first_seen = appearances[0] if appearances else None
        last_seen = appearances[-1] if appearances else None
        
        # Determine lifecycle status
        file_count = len(data["files"])
        if file_count == 1:
            lifecycle = "one-off"
        elif file_count == len(files):
            lifecycle = "evergreen"
        elif last_seen == appearances[-1] if appearances else None:
            lifecycle = "active"
        else:
            lifecycle = "discontinued"
        
        # Calculate frequency score (appearances / total files)
        frequency_score = (file_count / len(files) * 100) if len(files) > 0 else 0
        
        style_metrics.append({
            "style": style,
            "total_items": data["total_count"],
            "color_variants": len(data["colors"]),
            "file_appearances": file_count,
            "frequency_score": round(frequency_score, 2),
            "lifecycle": lifecycle,
            "first_seen": first_seen["date"] if first_seen else None,
            "last_seen": last_seen["date"] if last_seen else None,
            "divisions": list(data["divisions"]),
            "placed_count": data["placed_count"],
            "placement_rate": round((data["placed_count"] / data["total_count"] * 100), 2) if data["total_count"] > 0 else 0,
            "files": list(data["files"])
        })
    
    # Sort by different criteria
    most_frequent = sorted(style_metrics, key=lambda x: x["frequency_score"], reverse=True)[:20]
    one_offs = [s for s in style_metrics if s["lifecycle"] == "one-off"]
    evergreen = [s for s in style_metrics if s["lifecycle"] == "evergreen"]
    discontinued = [s for s in style_metrics if s["lifecycle"] == "discontinued"]
    
    # Summary statistics
    summary = {
        "total_unique_styles": len(style_metrics),
        "one_offs": len(one_offs),
        "evergreen_styles": len(evergreen),
        "discontinued_styles": len(discontinued),
        "active_styles": len([s for s in style_metrics if s["lifecycle"] == "active"]),
        "avg_file_appearances": round(sum(s["file_appearances"] for s in style_metrics) / len(style_metrics), 2) if style_metrics else 0,
        "avg_color_variants": round(sum(s["color_variants"] for s in style_metrics) / len(style_metrics), 2) if style_metrics else 0,
        "one_off_percentage": round((len(one_offs) / len(style_metrics) * 100), 2) if style_metrics else 0
    }
    
    return {
        "style_metrics": style_metrics,
        "most_frequent": most_frequent,
        "one_offs": one_offs[:50],  # Limit for performance
        "evergreen": evergreen,
        "discontinued": discontinued[:50],
        "summary": summary
    }


@router.get("/style-families")
async def style_family_analysis(db: Session = Depends(get_db)):
    """Analyze style families based on first 3 digits of style numbers."""
    items = db.query(Item).all()
    
    families = defaultdict(lambda: {
        "styles": set(),
        "items": [],
        "divisions": defaultdict(int),
        "genders": defaultdict(int),
        "colors": set(),
        "placed_count": 0,
        "pending_count": 0
    })
    
    for item in items:
        style_str = str(item.style)
        if len(style_str) >= 3:
            family_prefix = style_str[:3]
            
            families[family_prefix]["styles"].add(item.style)
            families[family_prefix]["items"].append(item.id)
            families[family_prefix]["colors"].add(item.color)
            
            if item.division:
                families[family_prefix]["divisions"][item.division] += 1
            if item.gender:
                families[family_prefix]["genders"][item.gender] += 1
            
            if item.row_id is not None:
                families[family_prefix]["placed_count"] += 1
            if item.status == 'pending':
                families[family_prefix]["pending_count"] += 1
    
    family_data = []
    for prefix, data in sorted(families.items()):
        total_items = len(data["items"])
        family_data.append({
            "family_prefix": prefix,
            "unique_styles": len(data["styles"]),
            "total_items": total_items,
            "color_variants": len(data["colors"]),
            "divisions": dict(data["divisions"]),
            "genders": dict(data["genders"]),
            "placed_count": data["placed_count"],
            "pending_count": data["pending_count"],
            "placement_rate": round((data["placed_count"] / total_items * 100), 2) if total_items > 0 else 0,
            "top_division": max(data["divisions"].items(), key=lambda x: x[1])[0] if data["divisions"] else None
        })
    
    top_families = sorted(family_data, key=lambda x: x["total_items"], reverse=True)[:20]
    
    return {
        "total_families": len(family_data),
        "families": family_data,
        "top_families": top_families,
        "summary": {
            "total_unique_prefixes": len(families),
            "avg_items_per_family": round(sum(f["total_items"] for f in family_data) / len(family_data), 2) if family_data else 0,
            "avg_styles_per_family": round(sum(f["unique_styles"] for f in family_data) / len(family_data), 2) if family_data else 0
        }
    }
