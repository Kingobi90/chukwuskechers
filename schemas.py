"""Pydantic models for API request/response validation."""
from pydantic import BaseModel, Field, validator
from typing import List, Optional, Dict
from datetime import datetime


def parse_width(color: str) -> str:
    """
    Parse width information from color name.
    
    Args:
        color: Color string (e.g., "BBK", "BBK (w)", "BBK (ww)")
        
    Returns:
        Width type: "wide", "extra_wide", or "regular"
    """
    if "(ww)" in color.lower():
        return "extra_wide"
    elif "(w)" in color.lower():
        return "wide"
    return "regular"


class ColorVariant(BaseModel):
    """Color variant with image and width information."""
    color: str = Field(..., description="Color code with optional width suffix (e.g., 'BBK (w)')")
    image_url: Optional[str] = Field(None, description="Supabase public URL for product image")
    width: str = Field(..., description="Width type: regular, wide, or extra_wide")
    
    @validator('width', pre=True, always=True)
    def set_width(cls, v, values):
        """Auto-set width from color if not provided."""
        if v is None and 'color' in values:
            return parse_width(values['color'])
        return v
    
    class Config:
        json_schema_extra = {
            "example": {
                "color": "BBK (w)",
                "image_url": "https://xxx.supabase.co/storage/v1/object/public/product-images/images/104437/BBK%20(w).jpeg",
                "width": "wide"
            }
        }


class ItemResponse(BaseModel):
    """Single item response with all details."""
    id: str = Field(..., description="Composite ID: style_color")
    style: str = Field(..., description="5-6 digit style number")
    color: str = Field(..., description="Color code with width suffix if applicable")
    division: Optional[str]
    outsole: Optional[str]
    gender: Optional[str]
    image_url: Optional[str]
    source_files: List[str] = Field(..., description="Excel files containing this item")
    status: str = Field(default="pending", description="Item status")
    width: str = Field(..., description="Width type parsed from color")
    created_at: datetime
    updated_at: datetime
    
    @validator('width', pre=True, always=True)
    def set_width(cls, v, values):
        """Auto-set width from color if not provided."""
        if v is None and 'color' in values:
            return parse_width(values['color'])
        return v
    
    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "id": "104437_BBK (w)",
                "style": "104437",
                "color": "BBK (w)",
                "division": "SPORT ACTIVE",
                "outsole": "VIRTUE",
                "gender": "WOMENS",
                "image_url": "https://xxx.supabase.co/...",
                "source_files": ["wof_09_17_2025.xlsx", "wof_11_25_2025.xlsx"],
                "status": "pending",
                "width": "wide",
                "created_at": "2024-12-20T10:00:00Z",
                "updated_at": "2024-12-20T10:00:00Z"
            }
        }


class StyleResponse(BaseModel):
    """Style summary with all color variants."""
    style: str = Field(..., description="5-6 digit style number")
    colors: List[ColorVariant] = Field(..., description="All color and width combinations")
    division: Optional[str]
    outsole: Optional[str]
    gender: Optional[str]
    color_count: int = Field(..., description="Total number of color variants")
    source_files: List[str] = Field(..., description="All Excel files containing this style")
    files_count: int = Field(..., description="Number of source files")
    
    class Config:
        json_schema_extra = {
            "example": {
                "style": "104437",
                "colors": [
                    {"color": "BBK", "image_url": "https://...", "width": "regular"},
                    {"color": "BBK (w)", "image_url": "https://...", "width": "wide"}
                ],
                "division": "SPORT ACTIVE",
                "outsole": "VIRTUE",
                "gender": "WOMENS",
                "color_count": 2,
                "source_files": ["wof_09_17_2025.xlsx"],
                "files_count": 1
            }
        }


class ActionRequest(BaseModel):
    """Request to record an inventory action."""
    style: str = Field(..., description="5-6 digit style number")
    color: str = Field(..., description="Color code with width suffix if applicable")
    action: str = Field(..., description="Action type: placed, showroom, waitlist, or dropped")
    location: Optional[str] = Field(None, description="Physical location")
    notes: Optional[str] = Field(None, description="Additional notes")
    user: str = Field(..., description="User performing the action")
    source_file: Optional[str] = Field(None, description="Excel file this relates to")
    
    @validator('action')
    def validate_action(cls, v):
        """Validate action is one of allowed types."""
        allowed = ['placed', 'showroom', 'waitlist', 'dropped']
        if v.lower() not in allowed:
            raise ValueError(f"Action must be one of: {', '.join(allowed)}")
        return v.lower()
    
    class Config:
        json_schema_extra = {
            "example": {
                "style": "104437",
                "color": "BBK (w)",
                "action": "placed",
                "location": "Aisle 3, Shelf B",
                "notes": "Customer requested wide width",
                "user": "John",
                "source_file": "wof_09_17_2025.xlsx"
            }
        }


class ActionResponse(BaseModel):
    """Response after recording an action."""
    success: bool
    style: str
    color: str
    action: str
    source_file: Optional[str]
    timestamp: datetime
    
    class Config:
        json_schema_extra = {
            "example": {
                "success": True,
                "style": "104437",
                "color": "BBK (w)",
                "action": "placed",
                "source_file": "wof_09_17_2025.xlsx",
                "timestamp": "2024-12-20T14:30:00Z"
            }
        }


class ActionHistoryItem(BaseModel):
    """Single action history entry."""
    id: int
    style: str
    color: str
    action: str
    location: Optional[str]
    notes: Optional[str]
    user: str
    source_file: Optional[str]
    timestamp: datetime
    width: str
    
    @validator('width', pre=True, always=True)
    def set_width(cls, v, values):
        """Auto-set width from color if not provided."""
        if v is None and 'color' in values:
            return parse_width(values['color'])
        return v
    
    class Config:
        from_attributes = True


class UploadResponse(BaseModel):
    """Response after uploading an Excel file."""
    success: bool
    items_saved: int
    styles_processed: int
    images_uploaded: int
    source_file: str
    
    class Config:
        json_schema_extra = {
            "example": {
                "success": True,
                "items_saved": 4745,
                "styles_processed": 1250,
                "images_uploaded": 3641,
                "source_file": "wof_09_17_2025.xlsx"
            }
        }


class StatsResponse(BaseModel):
    """Inventory statistics."""
    total_styles: int
    total_items: int
    total_files_processed: int
    by_action: Dict[str, int] = Field(..., description="Count by action type")
    by_division: Dict[str, int] = Field(..., description="Count by division")
    by_gender: Dict[str, int] = Field(..., description="Count by gender")
    by_width: Dict[str, int] = Field(..., description="Count by width type")
    
    class Config:
        json_schema_extra = {
            "example": {
                "total_styles": 1250,
                "total_items": 4745,
                "total_files_processed": 3,
                "by_action": {
                    "placed": 1200,
                    "showroom": 300,
                    "waitlist": 50,
                    "dropped": 20,
                    "pending": 3175
                },
                "by_division": {"SPORT ACTIVE": 800, "CASUAL": 450},
                "by_gender": {"WOMENS": 2500, "MENS": 2245},
                "by_width": {"regular": 3000, "wide": 1200, "extra_wide": 545}
            }
        }


class FileInfo(BaseModel):
    """Information about an uploaded file."""
    filename: str
    styles_count: int
    items_count: int
    images_uploaded: int
    uploaded_at: datetime
    status: str
    
    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "filename": "wof_09_17_2025.xlsx",
                "styles_count": 1247,
                "items_count": 4745,
                "images_uploaded": 3641,
                "uploaded_at": "2024-12-20T10:00:00Z",
                "status": "completed"
            }
        }


class PaginatedResponse(BaseModel):
    """Generic paginated response."""
    items: List[ItemResponse]
    total: int
    limit: int
    offset: int
    
    class Config:
        json_schema_extra = {
            "example": {
                "items": [],
                "total": 4745,
                "limit": 50,
                "offset": 0
            }
        }


class HealthResponse(BaseModel):
    """Health check response."""
    status: str
    database: str
    
    class Config:
        json_schema_extra = {
            "example": {
                "status": "healthy",
                "database": "connected"
            }
        }


class MessageResponse(BaseModel):
    """Generic message response."""
    message: str
    status: str
    
    class Config:
        json_schema_extra = {
            "example": {
                "message": "Warehouse Management System API",
                "status": "running"
            }
        }
