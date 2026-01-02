from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func, and_, or_
from backend.database import get_db, Item, StyleSummary, FileUpload, InventoryAction
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
    """Compare all uploaded files with detailed analytics."""
    files = db.query(FileUpload).order_by(FileUpload.uploaded_at).all()
    
    if not files:
        return {"files": [], "total_files": 0}
    
    comparisons = []
    
    for file in files:
        file_date = parse_date_from_filename(file.filename)
        
        items_in_file = db.query(Item).filter(
            Item.source_files.contains(file.filename)
        ).all()
        
        unique_to_file = []
        shared_items = []
        
        for item in items_in_file:
            if len(item.source_files) == 1:
                unique_to_file.append(item)
            else:
                shared_items.append(item)
        
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
        
        unique_styles = db.query(func.count(func.distinct(Item.style))).filter(
            Item.source_files.contains(file.filename)
        ).scalar()
        
        comparisons.append({
            "filename": file.filename,
            "file_date": file_date.isoformat() if file_date else None,
            "uploaded_at": file.uploaded_at.isoformat(),
            "total_items": len(items_in_file),
            "unique_items": len(unique_to_file),
            "shared_items": len(shared_items),
            "unique_styles": unique_styles,
            "divisions": dict(divisions),
            "genders": dict(genders),
            "statuses": dict(statuses),
            "widths": dict(widths),
            "status": file.status
        })
    
    return {
        "files": comparisons,
        "total_files": len(files)
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
    """Analyze trends across files ordered by date."""
    files = db.query(FileUpload).order_by(FileUpload.uploaded_at).all()
    
    timeline = []
    cumulative_styles = set()
    cumulative_items = set()
    
    for file in files:
        file_date = parse_date_from_filename(file.filename)
        
        items = db.query(Item).filter(
            Item.source_files.contains(file.filename)
        ).all()
        
        new_styles = set()
        new_items = set()
        
        for item in items:
            item_key = f"{item.style}_{item.color}"
            new_items.add(item_key)
            new_styles.add(item.style)
        
        truly_new_styles = new_styles - cumulative_styles
        truly_new_items = new_items - cumulative_items
        
        cumulative_styles.update(new_styles)
        cumulative_items.update(new_items)
        
        timeline.append({
            "filename": file.filename,
            "file_date": file_date.isoformat() if file_date else None,
            "uploaded_at": file.uploaded_at.isoformat(),
            "items_in_file": len(items),
            "styles_in_file": len(new_styles),
            "new_styles": len(truly_new_styles),
            "new_items": len(truly_new_items),
            "cumulative_styles": len(cumulative_styles),
            "cumulative_items": len(cumulative_items)
        })
    
    return {
        "timeline": timeline,
        "total_files": len(files),
        "final_unique_styles": len(cumulative_styles),
        "final_unique_items": len(cumulative_items)
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
    """Analyze division trends across files."""
    files = db.query(FileUpload).order_by(FileUpload.uploaded_at).all()
    
    trends = []
    
    for file in files:
        file_date = parse_date_from_filename(file.filename)
        
        items = db.query(Item).filter(
            Item.source_files.contains(file.filename)
        ).all()
        
        divisions = defaultdict(int)
        for item in items:
            if item.division:
                divisions[item.division] += 1
        
        trends.append({
            "filename": file.filename,
            "file_date": file_date.isoformat() if file_date else None,
            "divisions": dict(divisions),
            "total_items": len(items)
        })
    
    all_divisions = set()
    for trend in trends:
        all_divisions.update(trend["divisions"].keys())
    
    return {
        "trends": trends,
        "all_divisions": sorted(list(all_divisions))
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
