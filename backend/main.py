"""FastAPI backend for Warehouse Management System."""
import os
import tempfile
from typing import List, Optional
from datetime import datetime
from dotenv import load_dotenv

load_dotenv()

from fastapi import FastAPI, UploadFile, File, HTTPException, Depends, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, StreamingResponse
from sqlalchemy.orm import Session
from sqlalchemy import func, or_
import asyncio
import json
from typing import Dict
from queue import Queue

from database import get_db, Item, StyleSummary, InventoryAction, FileUpload, Room, Shelf, Row
from schemas import (
    MessageResponse, HealthResponse, StyleResponse, ColorVariant,
    ActionRequest, ActionResponse, ActionHistoryItem, UploadResponse,
    StatsResponse, FileInfo, ItemResponse, PaginatedResponse, parse_width
)
from excel_parser import InventoryParser
from analytics_routes import router as analytics_router
from seasonal_drop import process_seasonal_drop, export_dropped_items_report
# from barcode_scanner import process_camera_frame, decode_barcode_from_image
from pydantic import BaseModel


# Initialize FastAPI app
app = FastAPI(
    title="Warehouse Management API",
    description="API for managing Skechers inventory with Excel upload and image processing",
    version="1.0.0"
)

app.include_router(analytics_router)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# No external storage - using local database only

# Global progress tracking
upload_progress: Dict[str, Dict] = {}


def get_image_url_for_item(style: str, color: str) -> Optional[str]:
    """Generate image URL based on style and color if image file exists."""
    # Image filenames now include width variants: stylenumber_color.jpg
    # e.g., "104437_BBK (w).jpg" for wide width
    image_filename = f"{style}_{color}.jpg"
    image_path = os.path.join("..", "static", "images", image_filename)

    # Check if image file exists
    if os.path.exists(image_path):
        return f"/static/images/{image_filename}"
    return None


@app.get("/ui")
async def serve_ui():
    """Serve the new SMAC web UI."""
    return FileResponse("../static/index.html")


@app.get("/")
async def root():
    """Serve the new SMAC warehouse management UI."""
    return FileResponse("../static/index.html")

@app.get("/warehouse")
async def serve_old_warehouse():
    """Serve the old warehouse management UI."""
    return FileResponse("../static/warehouse.html")


@app.get("/api", response_model=MessageResponse)
async def api_root():
    """API root endpoint."""
    return {
        "message": "Warehouse Management System API",
        "status": "running"
    }


@app.get("/health", response_model=HealthResponse)
async def health_check(db: Session = Depends(get_db)):
    """Health check endpoint."""
    try:
        # Test database connection
        from sqlalchemy import text
        db.execute(text("SELECT 1"))
        return {
            "status": "healthy",
            "database": "connected"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")


@app.get("/upload-progress/{upload_id}")
async def get_upload_progress(upload_id: str):
    """
    Server-Sent Events endpoint for real-time upload progress.
    
    Args:
        upload_id: Unique upload identifier
        
    Returns:
        SSE stream with progress updates
    """
    async def event_generator():
        try:
            while True:
                if upload_id in upload_progress:
                    progress_data = upload_progress[upload_id]
                    
                    # Send progress update
                    yield f"data: {json.dumps(progress_data)}\n\n"
                    
                    # If complete, send final message and stop
                    if progress_data.get('status') in ['completed', 'error']:
                        await asyncio.sleep(1)
                        break
                else:
                    # Send initial waiting message
                    yield f"data: {json.dumps({'status': 'waiting', 'message': 'Initializing...'})}\n\n"
                
                await asyncio.sleep(0.5)  # Update every 500ms
        except asyncio.CancelledError:
            pass
    
    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
        }
    )


@app.post("/upload-excel", response_model=UploadResponse)
async def upload_excel(
    file: UploadFile = File(...),
    upload_images: bool = Query(True, description="Whether to extract and upload images to Supabase"),
    db: Session = Depends(get_db)
):
    """
    Upload Excel file, parse data, optionally extract/upload images, and save to database.
    
    Args:
        file: Excel file to upload
        upload_images: Whether to extract and upload embedded images to Supabase
        db: Database session
        
    Returns:
        Upload ID for tracking progress
    """
    import uuid
    upload_id = str(uuid.uuid4())
    upload_progress[upload_id] = {'status': 'processing', 'message': 'Initializing...'}
    
    if not file.filename.endswith(('.xlsx', '.xls')):
        raise HTTPException(status_code=400, detail="Invalid file format. Only .xlsx and .xls files are supported.")
    
    temp_path = None
    try:
        # Save uploaded file temporarily
        with tempfile.NamedTemporaryFile(delete=False, suffix='.xlsx') as tmp:
            content = await file.read()
            tmp.write(content)
            temp_path = tmp.name
        
        # Track file upload - check if file already exists
        file_upload = db.query(FileUpload).filter_by(filename=file.filename).first()
        if file_upload:
            # Update existing record
            file_upload.status = 'processing'
            file_upload.uploaded_at = datetime.utcnow()
        else:
            # Create new record
            file_upload = FileUpload(
                filename=file.filename,
                status='processing'
            )
            db.add(file_upload)
        db.commit()
        
        # Progress callback function
        def update_progress(stage, current, total):
            upload_progress[upload_id] = {
                'status': 'processing',
                'stage': stage,
                'current': current,
                'total': total,
                'percentage': int((current / total * 100)) if total > 0 else 0,
                'message': f'{stage}: {current}/{total}'
            }
        
        # Parse Excel data
        upload_progress[upload_id] = {'status': 'processing', 'message': 'Parsing Excel file...', 'percentage': 0}
        parser = InventoryParser(temp_path)
        
        # Extract images from Excel file
        images_uploaded = 0
        if upload_images:
            upload_progress[upload_id] = {'status': 'processing', 'message': 'Extracting images...', 'percentage': 50}
            image_result = parser.extract_images_to_folder("static/images")
            images_uploaded = image_result.get('extracted', 0)
        
        # Save to database
        upload_progress[upload_id] = {'status': 'processing', 'message': 'Saving to database...', 'percentage': 90}
        result = parser.save_to_database(file.filename)
        
        # Update file upload record
        file_upload.status = 'completed'
        file_upload.styles_count = result['styles_processed']
        file_upload.items_count = result['items_saved']
        file_upload.images_uploaded = images_uploaded
        db.commit()
        
        # Mark as completed
        upload_progress[upload_id] = {
            'status': 'completed',
            'message': 'Upload complete!',
            'percentage': 100,
            'items_saved': result['items_saved'],
            'styles_processed': result['styles_processed'],
            'images_uploaded': images_uploaded
        }
        
        return {
            "success": True,
            "upload_id": upload_id,
            "items_saved": result['items_saved'],
            "styles_processed": result['styles_processed'],
            "images_uploaded": images_uploaded,
            "source_file": file.filename
        }
        
    except Exception as e:
        db.rollback()
        upload_progress[upload_id] = {
            'status': 'error',
            'message': f'Error: {str(e)}',
            'percentage': 0
        }
        try:
            if file_upload:
                file_upload.status = 'failed'
                db.commit()
        except:
            pass
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")
    
    finally:
        # Clean up temporary file
        if temp_path and os.path.exists(temp_path):
            os.unlink(temp_path)


@app.get("/scan/{style}", response_model=StyleResponse)
async def scan_style(
    style: str,
    user: str = Query("unknown", description="User performing the scan"),
    db: Session = Depends(get_db)
):
    """
    Lookup style by scanning barcode or entering style number.
    
    Args:
        style: 5-6 digit style number
        user: User performing the scan
        db: Database session
        
    Returns:
        Style details with all color variants, images, and source files
    """
    # Normalize style to 6 digits if it's 5 digits
    if len(style) == 5:
        style = style.zfill(6)
    
    # Query style summary
    style_summary = db.query(StyleSummary).filter_by(style=style).first()
    if not style_summary:
        raise HTTPException(status_code=404, detail=f"Style {style} not found")
    
    # Query all color variants
    items = db.query(Item).filter_by(style=style).all()
    
    # Build color variants list
    colors = []
    for item in items:
        colors.append(ColorVariant(
            color=item.color,
            image_url=item.image_url or get_image_url_for_item(item.style, item.color),
            width=parse_width(item.color)
        ))
    
    return StyleResponse(
        style=style_summary.style,
        colors=colors,
        division=style_summary.division,
        outsole=style_summary.outsole,
        gender=style_summary.gender,
        color_count=style_summary.color_count,
        source_files=style_summary.source_files,
        files_count=len(style_summary.source_files)
    )


@app.post("/action", response_model=ActionResponse)
async def record_action(
    action_request: ActionRequest,
    db: Session = Depends(get_db)
):
    """
    Record an inventory action (placed, showroom, waitlist, dropped).
    
    Args:
        action_request: Action details
        db: Database session
        
    Returns:
        Action confirmation with timestamp
    """
    # Normalize style
    style = action_request.style.zfill(6) if len(action_request.style) == 5 else action_request.style
    
    # Find the item
    item = db.query(Item).filter_by(
        style=style,
        color=action_request.color
    ).first()
    
    if not item:
        raise HTTPException(
            status_code=404,
            detail=f"Item not found: style={style}, color={action_request.color}"
        )
    
    # If source_file specified, verify it exists in item's source_files
    if action_request.source_file and action_request.source_file not in item.source_files:
        raise HTTPException(
            status_code=400,
            detail=f"Source file '{action_request.source_file}' not associated with this item"
        )
    
    # Create action record
    action = InventoryAction(
        item_id=item.id,
        style=style,
        color=action_request.color,
        action=action_request.action,
        location=action_request.location,
        notes=action_request.notes,
        user=action_request.user,
        source_file=action_request.source_file or item.source_files[0]
    )
    db.add(action)
    
    # Update item status
    item.status = action_request.action
    item.updated_at = datetime.utcnow()
    
    db.commit()
    db.refresh(action)
    
    return ActionResponse(
        success=True,
        style=style,
        color=action_request.color,
        action=action_request.action,
        source_file=action.source_file,
        timestamp=action.timestamp
    )


@app.get("/actions/{style}", response_model=List[ActionHistoryItem])
async def get_style_actions(
    style: str,
    db: Session = Depends(get_db)
):
    """
    Get action history for a specific style.
    
    Args:
        style: 5-6 digit style number
        db: Database session
        
    Returns:
        List of all actions taken on this style, sorted by most recent first
    """
    # Normalize style
    style = style.zfill(6) if len(style) == 5 else style
    
    actions = db.query(InventoryAction).filter_by(style=style).order_by(
        InventoryAction.timestamp.desc()
    ).all()
    
    return [
        ActionHistoryItem(
            id=action.id,
            style=action.style,
            color=action.color,
            action=action.action,
            location=action.location,
            notes=action.notes,
            user=action.user,
            source_file=action.source_file,
            timestamp=action.timestamp,
            width=parse_width(action.color)
        )
        for action in actions
    ]


@app.get("/actions/{style}/{color}", response_model=List[ActionHistoryItem])
async def get_color_actions(
    style: str,
    color: str,
    db: Session = Depends(get_db)
):
    """
    Get action history for a specific style and color combination.
    
    Args:
        style: 5-6 digit style number
        color: Color code (with width suffix if applicable)
        db: Database session
        
    Returns:
        List of actions for this specific color variant
    """
    # Normalize style
    style = style.zfill(6) if len(style) == 5 else style
    
    actions = db.query(InventoryAction).filter_by(
        style=style,
        color=color
    ).order_by(InventoryAction.timestamp.desc()).all()
    
    return [
        ActionHistoryItem(
            id=action.id,
            style=action.style,
            color=action.color,
            action=action.action,
            location=action.location,
            notes=action.notes,
            user=action.user,
            source_file=action.source_file,
            timestamp=action.timestamp,
            width=parse_width(action.color)
        )
        for action in actions
    ]


@app.get("/inventory/pending", response_model=PaginatedResponse)
async def get_pending_items(
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db)
):
    """
    Get all items with no action taken (status = pending).
    
    Args:
        limit: Maximum number of items to return
        offset: Number of items to skip
        db: Database session
        
    Returns:
        Paginated list of pending items
    """
    query = db.query(Item).filter_by(status='pending')
    total = query.count()
    items = query.offset(offset).limit(limit).all()
    
    return PaginatedResponse(
        items=[
            ItemResponse(
                id=item.id,
                style=item.style,
                color=item.color,
                division=item.division,
                outsole=item.outsole,
                gender=item.gender,
                image_url=item.image_url or get_image_url_for_item(item.style, item.color),
                source_files=item.source_files,
                status=item.status,
                width=parse_width(item.color),
                created_at=item.created_at,
                updated_at=item.updated_at
            )
            for item in items
        ],
        total=total,
        limit=limit,
        offset=offset
    )


@app.get("/inventory/by-action/{action}", response_model=PaginatedResponse)
async def get_items_by_action(
    action: str,
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db)
):
    """
    Get all items with a specific action status.
    
    Args:
        action: Action type (placed, showroom, waitlist, dropped)
        limit: Maximum number of items to return
        offset: Number of items to skip
        db: Database session
        
    Returns:
        Paginated list of items with the specified action
    """
    allowed_actions = ['placed', 'showroom', 'waitlist', 'dropped']
    if action.lower() not in allowed_actions:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid action. Must be one of: {', '.join(allowed_actions)}"
        )
    
    query = db.query(Item).filter_by(status=action.lower())
    total = query.count()
    items = query.offset(offset).limit(limit).all()
    
    return PaginatedResponse(
        items=[
            ItemResponse(
                id=item.id,
                style=item.style,
                color=item.color,
                division=item.division,
                outsole=item.outsole,
                gender=item.gender,
                image_url=item.image_url or get_image_url_for_item(item.style, item.color),
                source_files=item.source_files,
                status=item.status,
                width=parse_width(item.color),
                created_at=item.created_at,
                updated_at=item.updated_at
            )
            for item in items
        ],
        total=total,
        limit=limit,
        offset=offset
    )


@app.get("/inventory/stats", response_model=StatsResponse)
async def get_inventory_stats(db: Session = Depends(get_db)):
    """
    Get comprehensive inventory statistics.
    
    Args:
        db: Database session
        
    Returns:
        Statistics including counts by action, division, gender, and width
    """
    # Total counts
    total_styles = db.query(StyleSummary).count()
    total_items = db.query(Item).count()
    total_files = db.query(FileUpload).filter_by(status='completed').count()
    
    # By action
    by_action = {}
    for action in ['pending', 'placed', 'showroom', 'waitlist', 'dropped']:
        count = db.query(Item).filter_by(status=action).count()
        by_action[action] = count
    
    # By division
    by_division = {}
    divisions = db.query(Item.division, func.count(Item.id)).group_by(Item.division).all()
    for division, count in divisions:
        if division:
            by_division[division] = count
    
    # By gender
    by_gender = {}
    genders = db.query(Item.gender, func.count(Item.id)).group_by(Item.gender).all()
    for gender, count in genders:
        if gender:
            by_gender[gender] = count
    
    # By width
    all_items = db.query(Item.color).all()
    by_width = {"regular": 0, "wide": 0, "extra_wide": 0}
    for (color,) in all_items:
        width = parse_width(color)
        by_width[width] += 1
    
    return StatsResponse(
        total_styles=total_styles,
        total_items=total_items,
        total_files_processed=total_files,
        by_action=by_action,
        by_division=by_division,
        by_gender=by_gender,
        by_width=by_width
    )


@app.get("/inventory/search", response_model=PaginatedResponse)
async def search_inventory(
    division: Optional[str] = Query(None),
    gender: Optional[str] = Query(None),
    color: Optional[str] = Query(None),
    width: Optional[str] = Query(None, description="regular, wide, or extra_wide"),
    source_file: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=5000),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db)
):
    """
    Search inventory with filters.
    
    Args:
        division: Filter by division (partial match)
        gender: Filter by gender (partial match)
        color: Filter by color (partial match)
        width: Filter by width type (regular, wide, extra_wide)
        source_file: Filter by source file
        limit: Maximum number of items to return
        offset: Number of items to skip
        db: Database session
        
    Returns:
        Paginated filtered items
    """
    query = db.query(Item)
    
    if division:
        query = query.filter(Item.division.ilike(f"%{division}%"))
    
    if gender:
        query = query.filter(Item.gender.ilike(f"%{gender}%"))
    
    if color:
        query = query.filter(Item.color.ilike(f"%{color}%"))
    
    if width:
        if width == "wide":
            query = query.filter(Item.color.like("%(w)%"), ~Item.color.like("%(ww)%"))
        elif width == "extra_wide":
            query = query.filter(Item.color.like("%(ww)%"))
        elif width == "regular":
            query = query.filter(~Item.color.like("%(w)%"))
    
    # Note: source_file filter would require JSON query capabilities
    # For SQLite, we'll skip this filter. For PostgreSQL, use JSON operators
    
    total = query.count()
    items = query.offset(offset).limit(limit).all()
    
    return PaginatedResponse(
        items=[
            ItemResponse(
                id=item.id,
                style=item.style,
                color=item.color,
                division=item.division,
                outsole=item.outsole,
                gender=item.gender,
                image_url=item.image_url or get_image_url_for_item(item.style, item.color),
                source_files=item.source_files,
                status=item.status,
                width=parse_width(item.color),
                created_at=item.created_at,
                updated_at=item.updated_at
            )
            for item in items
        ],
        total=total,
        limit=limit,
        offset=offset
    )


@app.get("/inventory/files", response_model=List[FileInfo])
async def get_uploaded_files(db: Session = Depends(get_db)):
    """
    Get list of all uploaded Excel files with statistics.
    
    Args:
        db: Database session
        
    Returns:
        List of uploaded files with counts and status
    """
    files = db.query(FileUpload).order_by(FileUpload.uploaded_at.desc()).all()
    
    return [
        FileInfo(
            filename=f.filename,
            styles_count=f.styles_count,
            items_count=f.items_count,
            images_uploaded=f.images_uploaded,
            uploaded_at=f.uploaded_at,
            status=f.status
        )
        for f in files
    ]


@app.get("/inventory/file/{filename}", response_model=PaginatedResponse)
async def get_file_items(
    filename: str,
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db)
):
    """
    Get all items from a specific Excel file.
    
    Args:
        filename: Excel filename
        limit: Maximum number of items to return
        offset: Number of items to skip
        db: Database session
        
    Returns:
        Paginated list of items from the specified file
    """
    # For SQLite, we need to query all items and filter in Python
    # For PostgreSQL, use JSON operators for better performance
    all_items = db.query(Item).all()
    
    # Filter items that have this filename in their source_files
    filtered_items = [item for item in all_items if filename in item.source_files]
    
    total = len(filtered_items)
    paginated_items = filtered_items[offset:offset + limit]
    
    return PaginatedResponse(
        items=[
            ItemResponse(
                id=item.id,
                style=item.style,
                color=item.color,
                division=item.division,
                outsole=item.outsole,
                gender=item.gender,
                image_url=item.image_url or get_image_url_for_item(item.style, item.color),
                source_files=item.source_files,
                status=item.status,
                width=parse_width(item.color),
                created_at=item.created_at,
                updated_at=item.updated_at
            )
            for item in paginated_items
        ],
        total=total,
        limit=limit,
        offset=offset
    )


@app.delete("/inventory/file/{filename}")
async def delete_file(
    filename: str,
    db: Session = Depends(get_db)
):
    """
    Delete a file and all associated data from the database.
    
    Args:
        filename: Name of the file to delete
        db: Database session
        
    Returns:
        Deletion statistics
    """
    # Check if file exists
    file_upload = db.query(FileUpload).filter_by(filename=filename).first()
    if not file_upload:
        raise HTTPException(status_code=404, detail=f"File '{filename}' not found")
    
    try:
        # Find all items that have this file as their ONLY source
        items_to_delete = []
        items_to_update = []
        
        all_items = db.query(Item).all()
        for item in all_items:
            if filename in item.source_files:
                if len(item.source_files) == 1:
                    # This is the only source, delete the item
                    items_to_delete.append(item)
                else:
                    # Multiple sources, just remove this file from the list
                    items_to_update.append(item)
        
        # Update items with multiple sources
        for item in items_to_update:
            item.source_files = [f for f in item.source_files if f != filename]
        
        # Delete items with only this source
        items_deleted = len(items_to_delete)
        for item in items_to_delete:
            db.delete(item)
        
        # Update or delete style summaries
        styles_deleted = 0
        styles_updated = 0
        all_styles = db.query(StyleSummary).all()
        
        for style_summary in all_styles:
            if filename in style_summary.source_files:
                # Check if this style still has items after deletion
                remaining_items = db.query(Item).filter_by(style=style_summary.style).count()
                
                if remaining_items == 0 or len(style_summary.source_files) == 1:
                    # No items left or this was the only source, delete the style
                    db.delete(style_summary)
                    styles_deleted += 1
                else:
                    # Update the style summary
                    style_summary.source_files = [f for f in style_summary.source_files if f != filename]
                    
                    # Recalculate color count
                    items = db.query(Item).filter_by(style=style_summary.style).all()
                    style_summary.all_colors = [item.color for item in items]
                    style_summary.color_count = len(style_summary.all_colors)
                    styles_updated += 1
        
        # Delete all actions associated with this file
        actions_deleted = db.query(InventoryAction).filter_by(source_file=filename).delete()
        
        # Delete the file upload record
        db.delete(file_upload)
        
        # Commit all changes
        db.commit()
        
        return {
            "success": True,
            "filename": filename,
            "items_deleted": items_deleted,
            "items_updated": len(items_to_update),
            "styles_deleted": styles_deleted,
            "styles_updated": styles_updated,
            "actions_deleted": actions_deleted
        }
        
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to delete file: {str(e)}")


# ===== LOCATION MANAGEMENT ENDPOINTS =====

class RoomCreate(BaseModel):
    name: str
    description: Optional[str] = None

class ShelfCreate(BaseModel):
    room_id: int
    name: str
    description: Optional[str] = None

class RowCreate(BaseModel):
    shelf_id: int
    name: str
    description: Optional[str] = None


@app.post("/locations/rooms")
async def create_room(room: RoomCreate, db: Session = Depends(get_db)):
    """Create a new room."""
    existing = db.query(Room).filter_by(name=room.name).first()
    if existing:
        raise HTTPException(status_code=400, detail=f"Room '{room.name}' already exists")
    new_room = Room(name=room.name, description=room.description)
    db.add(new_room)
    db.commit()
    db.refresh(new_room)
    return {"id": new_room.id, "name": new_room.name, "description": new_room.description, "shelf_count": 0}


@app.get("/locations/rooms")
async def get_rooms(db: Session = Depends(get_db)):
    """Get all rooms."""
    rooms = db.query(Room).all()
    return [{"id": r.id, "name": r.name, "description": r.description, "shelf_count": len(r.shelves)} for r in rooms]


@app.delete("/locations/rooms/{room_id}")
async def delete_room(room_id: int, db: Session = Depends(get_db)):
    """Delete a room and all its shelves/rows."""
    room = db.query(Room).filter_by(id=room_id).first()
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    db.delete(room)
    db.commit()
    return {"success": True, "message": f"Room '{room.name}' deleted"}


@app.post("/locations/shelves")
async def create_shelf(shelf: ShelfCreate, db: Session = Depends(get_db)):
    """Create a new shelf."""
    room = db.query(Room).filter_by(id=shelf.room_id).first()
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    new_shelf = Shelf(room_id=shelf.room_id, name=shelf.name, description=shelf.description)
    db.add(new_shelf)
    db.commit()
    db.refresh(new_shelf)
    return {"id": new_shelf.id, "room_id": shelf.room_id, "room_name": room.name, "name": shelf.name, "description": shelf.description, "row_count": 0}


@app.get("/locations/shelves")
async def get_shelves(room_id: Optional[int] = Query(None), db: Session = Depends(get_db)):
    """Get all shelves, optionally filtered by room."""
    query = db.query(Shelf)
    if room_id:
        query = query.filter_by(room_id=room_id)
    shelves = query.all()
    return [{"id": s.id, "room_id": s.room_id, "room_name": s.room.name, "name": s.name, "description": s.description, "row_count": len(s.rows)} for s in shelves]


@app.delete("/locations/shelves/{shelf_id}")
async def delete_shelf(shelf_id: int, db: Session = Depends(get_db)):
    """Delete a shelf and all its rows."""
    shelf = db.query(Shelf).filter_by(id=shelf_id).first()
    if not shelf:
        raise HTTPException(status_code=404, detail="Shelf not found")
    db.delete(shelf)
    db.commit()
    return {"success": True, "message": f"Shelf '{shelf.name}' deleted"}


@app.post("/locations/rows")
async def create_row(row: RowCreate, db: Session = Depends(get_db)):
    """Create a new row."""
    shelf = db.query(Shelf).filter_by(id=row.shelf_id).first()
    if not shelf:
        raise HTTPException(status_code=404, detail="Shelf not found")
    new_row = Row(shelf_id=row.shelf_id, name=row.name, description=row.description)
    db.add(new_row)
    db.commit()
    db.refresh(new_row)
    return {"id": new_row.id, "shelf_id": row.shelf_id, "shelf_name": shelf.name, "room_name": shelf.room.name, "name": row.name, "description": row.description, "item_count": 0}


@app.get("/locations/rows")
async def get_rows(shelf_id: Optional[int] = Query(None), db: Session = Depends(get_db)):
    """Get all rows, optionally filtered by shelf."""
    query = db.query(Row)
    if shelf_id:
        query = query.filter_by(shelf_id=shelf_id)
    rows = query.all()
    return [{"id": r.id, "shelf_id": r.shelf_id, "shelf_name": r.shelf.name, "room_name": r.shelf.room.name, "name": r.name, "description": r.description, "item_count": len(r.items)} for r in rows]


@app.delete("/locations/rows/{row_id}")
async def delete_row(row_id: int, db: Session = Depends(get_db)):
    """Delete a row. Items will be unassigned."""
    row = db.query(Row).filter_by(id=row_id).first()
    if not row:
        raise HTTPException(status_code=404, detail="Row not found")
    # Unassign items from this row
    db.query(Item).filter_by(row_id=row_id).update({"row_id": None})
    db.delete(row)
    db.commit()
    return {"success": True, "message": f"Row '{row.name}' deleted"}


@app.get("/locations/rows/{row_id}/items")
async def get_row_items(row_id: int, db: Session = Depends(get_db)):
    """Get all items in a specific row."""
    row = db.query(Row).filter_by(id=row_id).first()
    if not row:
        raise HTTPException(status_code=404, detail="Row not found")
    items = db.query(Item).filter_by(row_id=row_id).all()
    return {
        "row": {"id": row.id, "name": row.name, "shelf_name": row.shelf.name, "room_name": row.shelf.room.name},
        "items": [{"id": i.id, "style": i.style, "color": i.color, "division": i.division, "gender": i.gender, "status": i.status, "unverified": bool(i.unverified)} for i in items],
        "total": len(items)
    }


@app.get("/warehouse/visual-layout")
async def get_visual_warehouse_layout(db: Session = Depends(get_db)):
    """Get complete warehouse layout with all items for visual shelf display."""
    rooms = db.query(Room).all()
    
    layout = []
    for room in rooms:
        room_data = {
            "id": room.id,
            "name": room.name,
            "description": room.description,
            "shelves": []
        }
        
        for shelf in room.shelves:
            shelf_data = {
                "id": shelf.id,
                "name": shelf.name,
                "description": shelf.description,
                "rows": []
            }
            
            for row in shelf.rows:
                items_data = []
                for item in row.items:
                    image_url = get_image_url_for_item(item.style, item.color)
                    items_data.append({
                        "id": item.id,
                        "style": item.style,
                        "color": item.color,
                        "division": item.division,
                        "outsole": item.outsole,
                        "gender": item.gender,
                        "image_url": image_url,
                        "status": item.status,
                        "unverified": bool(item.unverified)
                    })
                
                shelf_data["rows"].append({
                    "id": row.id,
                    "name": row.name,
                    "description": row.description,
                    "items": items_data,
                    "item_count": len(items_data)
                })
            
            room_data["shelves"].append(shelf_data)
        
        layout.append(room_data)
    
    return {"warehouse_layout": layout}


@app.get("/items/{item_id}/profile")
async def get_item_profile(item_id: str, db: Session = Depends(get_db)):
    """Get complete profile information for a specific item."""
    item = db.query(Item).filter_by(id=item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    
    image_url = get_image_url_for_item(item.style, item.color)
    
    return {
        "id": item.id,
        "style": item.style,
        "color": item.color,
        "division": item.division,
        "outsole": item.outsole,
        "gender": item.gender,
        "image_url": image_url,
        "status": item.status,
        "unverified": bool(item.unverified),
        "source_files": item.source_files,
        "created_at": item.created_at.isoformat() if item.created_at else None,
        "updated_at": item.updated_at.isoformat() if item.updated_at else None,
        "location": {
            "room": item.row.shelf.room.name,
            "shelf": item.row.shelf.name,
            "row": item.row.name,
            "row_id": item.row_id
        } if item.row else None
    }


class ItemLocationUpdate(BaseModel):
    row_id: Optional[int] = None

class ItemStatusUpdate(BaseModel):
    status: str

class BulkStatusUpdate(BaseModel):
    from_status: str
    to_status: str


@app.put("/items/{item_id}/location")
async def update_item_location(item_id: str, location_update: ItemLocationUpdate, db: Session = Depends(get_db)):
    """Assign or unassign an item to/from a warehouse location."""
    item = db.query(Item).filter_by(id=item_id).first()
    
    if not item:
        parts = item_id.split('_', 1)
        if len(parts) == 2:
            style, color = parts
            item = Item(
                id=item_id,
                style=style,
                color=color,
                division=None,
                outsole=None,
                gender=None,
                source_files=["scanned"],
                status="pending",
                unverified=1
            )
            db.add(item)
            db.commit()
            db.refresh(item)
        else:
            raise HTTPException(status_code=404, detail="Item not found")
    
    if location_update.row_id is not None:
        row = db.query(Row).filter_by(id=location_update.row_id).first()
        if not row:
            raise HTTPException(status_code=404, detail="Row not found")
        item.row_id = location_update.row_id
        item.status = "placed"
        location_info = {"room": row.shelf.room.name, "shelf": row.shelf.name, "row": row.name}
    else:
        item.row_id = None
        item.status = "pending"
        location_info = None
    
    db.commit()
    db.refresh(item)
    
    return {
        "success": True,
        "item_id": item.id,
        "style": item.style,
        "color": item.color,
        "status": item.status,
        "location": location_info,
        "unverified": bool(item.unverified)
    }


# Barcode scanner endpoint disabled - requires zbar system library
# @app.post("/scan-barcode")
# async def scan_barcode(file: UploadFile = File(...)):
#     """
#     Scan barcode/QR code from uploaded image and extract style number.
#     Returns decoded barcode data and automatically searches for matching items.
#     """
#     try:
#         # Read image data
#         image_data = await file.read()
#         
#         # Process barcode
#         result = process_camera_frame(image_data)
#         
#         if not result['success']:
#             return {
#                 "success": False,
#                 "message": result['message'],
#                 "barcodes": []
#             }
#         
#         # Return barcode results
#         return {
#             "success": True,
#             "message": result['message'],
#             "barcodes": result['barcodes']
#         }
#         
#     except Exception as e:
#         raise HTTPException(status_code=500, detail=f"Barcode scanning failed: {str(e)}")


@app.post("/scan-tag")
async def scan_tag(file: UploadFile = File(...)):
    """
    Scan Skechers tag using OCR to extract style number and color code.
    Returns style number, color code, and color name.
    """
    try:
        # Read image data
        image_data = await file.read()
        
        # Scan tag using OCR
        result = scan_skechers_tag(image_data)
        
        return result
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Tag scanning failed: {str(e)}")


@app.get("/items/search")
async def search_items(
    style: Optional[str] = Query(None),
    color: Optional[str] = Query(None),
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db)
):
    """Search for items by style or color."""
    query = db.query(Item)

    if style:
        query = query.filter(Item.style.like(f"%{style}%"))

    if color:
        query = query.filter(Item.color.ilike(f"%{color}%"))

    items = query.limit(limit).all()

    return [
        {
            "id": item.id,
            "style": item.style,
            "color": item.color,
            "division": item.division,
            "outsole": item.outsole,
            "gender": item.gender,
            "status": item.status,
            "unverified": bool(item.unverified),
            "image_url": item.image_url or get_image_url_for_item(item.style, item.color),
            "location": {
                "room": item.row.shelf.room.name if item.row else None,
                "shelf": item.row.shelf.name if item.row else None,
                "row": item.row.name if item.row else None
            } if item.row else None
        }
        for item in items
    ]


@app.post("/seasonal-drop")
async def seasonal_drop_upload(
    file: UploadFile = File(...),
    season_name: str = Query(..., description="Name of the season (e.g., 'Spring 2025')"),
    db: Session = Depends(get_db)
):
    """
    Upload seasonal Excel file and automatically mark all styles NOT in the file as 'dropped'.
    Returns organized report of dropped items with their warehouse locations.
    """
    if not file.filename.endswith(('.xlsx', '.xls')):
        raise HTTPException(status_code=400, detail="Invalid file format. Only .xlsx and .xls files are supported.")
    
    temp_path = None
    try:
        # Save uploaded file temporarily
        with tempfile.NamedTemporaryFile(delete=False, suffix='.xlsx') as tmp:
            content = await file.read()
            tmp.write(content)
            temp_path = tmp.name
        
        # Process seasonal drop
        result = process_seasonal_drop(temp_path, season_name)
        
        return {
            "success": True,
            "season_name": result['season_name'],
            "active_styles_count": result['active_styles_count'],
            "dropped_count": result['dropped_count'],
            "dropped_with_location": result['dropped_with_location'],
            "dropped_without_location": result['dropped_without_location'],
            "items_by_location": result['items_by_location'],
            "items_without_location": result['items_without_location']
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Seasonal drop failed: {str(e)}")
    
    finally:
        # Clean up temporary file
        if temp_path and os.path.exists(temp_path):
            os.unlink(temp_path)


@app.get("/dropped-items/report")
async def get_dropped_items_report(db: Session = Depends(get_db)):
    """
    Get a formatted report of all dropped items organized by warehouse location.
    """
    try:
        # Get all dropped items
        dropped_items = db.query(Item).filter_by(status='dropped').all()
        
        items_with_location = []
        items_without_location = []
        
        for item in dropped_items:
            item_data = {
                'id': item.id,
                'style': item.style,
                'color': item.color,
                'division': item.division,
                'gender': item.gender,
                'location': None if not item.row_id else {
                    'room': item.row.shelf.room.name,
                    'shelf': item.row.shelf.name,
                    'row': item.row.name
                }
            }
            
            if item.row_id:
                items_with_location.append(item_data)
            else:
                items_without_location.append(item_data)
        
        # Group by location
        by_location = {}
        for item in items_with_location:
            loc_key = f"{item['location']['room']} > {item['location']['shelf']} > {item['location']['row']}"
            if loc_key not in by_location:
                by_location[loc_key] = []
            by_location[loc_key].append(item)
        
        return {
            "total_dropped": len(dropped_items),
            "with_location": len(items_with_location),
            "without_location": len(items_without_location),
            "items_by_location": by_location,
            "items_without_location": items_without_location
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate report: {str(e)}")


@app.put("/inventory/items/{item_id}/status")
async def update_item_status(item_id: str, status_update: ItemStatusUpdate, db: Session = Depends(get_db)):
    """
    Update the status of a single item.
    """
    try:
        item = db.query(Item).filter_by(id=item_id).first()
        if not item:
            raise HTTPException(status_code=404, detail="Item not found")
        
        # Validate status
        valid_statuses = ['pending', 'placed', 'showroom', 'waitlist', 'dropped']
        if status_update.status not in valid_statuses:
            raise HTTPException(status_code=400, detail=f"Invalid status. Must be one of: {', '.join(valid_statuses)}")
        
        old_status = item.status
        item.status = status_update.status
        db.commit()
        
        return {
            "success": True,
            "item_id": item_id,
            "old_status": old_status,
            "new_status": status_update.status
        }
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to update item status: {str(e)}")


@app.put("/inventory/items/bulk-status")
async def bulk_update_status(bulk_update: BulkStatusUpdate, db: Session = Depends(get_db)):
    """
    Bulk update items from one status to another.
    """
    try:
        # Validate statuses
        valid_statuses = ['pending', 'placed', 'showroom', 'waitlist', 'dropped']
        if bulk_update.from_status not in valid_statuses or bulk_update.to_status not in valid_statuses:
            raise HTTPException(status_code=400, detail=f"Invalid status. Must be one of: {', '.join(valid_statuses)}")
        
        # Update all items with matching status
        items = db.query(Item).filter_by(status=bulk_update.from_status).all()
        updated_count = len(items)
        
        for item in items:
            item.status = bulk_update.to_status
        
        db.commit()
        
        return {
            "success": True,
            "updated_count": updated_count,
            "from_status": bulk_update.from_status,
            "to_status": bulk_update.to_status
        }
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to bulk update status: {str(e)}")


@app.get("/dropped-items/export")
async def export_dropped_items(db: Session = Depends(get_db)):
    """
    Export dropped items report as downloadable text file.
    """
    try:
        # Get dropped items data
        dropped_items = db.query(Item).filter_by(status='dropped').all()
        
        items_with_location = []
        items_without_location = []
        
        for item in dropped_items:
            item_data = {
                'style': item.style,
                'color': item.color,
                'division': item.division,
                'gender': item.gender,
                'location': None if not item.row_id else {
                    'room': item.row.shelf.room.name,
                    'shelf': item.row.shelf.name,
                    'row': item.row.name
                }
            }
            
            if item.row_id:
                items_with_location.append(item_data)
            else:
                items_without_location.append(item_data)
        
        # Group by location
        by_location = {}
        for item in items_with_location:
            loc_key = f"{item['location']['room']} > {item['location']['shelf']} > {item['location']['row']}"
            if loc_key not in by_location:
                by_location[loc_key] = []
            by_location[loc_key].append(item)
        
        # Generate report
        lines = []
        lines.append("=" * 80)
        lines.append("DROPPED ITEMS REPORT")
        lines.append("=" * 80)
        lines.append(f"Generated: {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}")
        lines.append(f"Total Dropped Items: {len(dropped_items)}")
        lines.append(f"  - With Location: {len(items_with_location)}")
        lines.append(f"  - Without Location: {len(items_without_location)}")
        lines.append("")
        lines.append("=" * 80)
        lines.append("DROPPED ITEMS BY WAREHOUSE LOCATION")
        lines.append("=" * 80)
        
        for location, items in sorted(by_location.items()):
            lines.append(f"\n📍 {location}")
            lines.append("-" * 80)
            for item in sorted(items, key=lambda x: (x['style'], x['color'])):
                lines.append(f"  • {item['style']} - {item['color']} ({item['division']}, {item['gender']})")
            lines.append(f"  Total: {len(items)} items")
        
        if items_without_location:
            lines.append("\n" + "=" * 80)
            lines.append("DROPPED ITEMS - NO LOCATION ASSIGNED")
            lines.append("=" * 80)
            for item in sorted(items_without_location, key=lambda x: (x['style'], x['color'])):
                lines.append(f"  • {item['style']} - {item['color']} ({item['division']}, {item['gender']})")
            lines.append(f"\nTotal: {len(items_without_location)} items")
        
        lines.append("\n" + "=" * 80)
        lines.append("END OF REPORT")
        lines.append("=" * 80)
        
        report_content = "\n".join(lines)
        
        # Return as downloadable file
        from io import BytesIO
        buffer = BytesIO(report_content.encode('utf-8'))
        
        return StreamingResponse(
            buffer,
            media_type="text/plain",
            headers={
                "Content-Disposition": f"attachment; filename=dropped_items_report_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}.txt"
            }
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to export report: {str(e)}")


# Mount static files at the end (after all routes are defined)
app.mount("/static", StaticFiles(directory="../static"), name="static")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
