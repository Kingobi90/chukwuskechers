# Warehouse Management System - UI Guide

## Quick Start

1. **Start the API server:**
   ```bash
   cd /Users/obinna.c/CascadeProjects/chukwu
   python main.py
   ```

2. **Open the UI in your browser:**
   - Direct link: http://localhost:8001/ui
   - Or visit: http://localhost:8001/docs for API documentation

## Features

### Upload Excel Tab
Upload Excel files with embedded product images.

**How to use:**
1. Click "Choose File" and select your Excel file (.xlsx)
2. Check/uncheck "Extract and upload images to Supabase"
3. Click "Upload & Process"
4. Wait for processing (may take several minutes for files with thousands of images)

**What it does:**
- Parses Excel data (styles, colors, divisions, etc.)
- Extracts embedded images from Excel
- Uploads images to Supabase storage
- Saves everything to database
- Tracks source file for each item

### Scan Style Tab
Look up product information by style number.

**How to use:**
1. Enter a 5 or 6 digit style number (e.g., 104437)
2. Optionally enter your name
3. Click "Scan"

**What you'll see:**
- Style details (division, gender, outsole)
- All color variants with images
- Width information (regular, wide, extra wide)
- Which Excel files contain this style
- Total color count

### Record Action Tab
Record inventory actions for specific items.

**How to use:**
1. Enter style number
2. Enter color (including width suffix like "BBK (w)")
3. Select action type:
   - **Placed**: Item has been placed in warehouse
   - **Showroom**: Item moved to showroom
   - **Waitlist**: Item on waitlist
   - **Dropped**: Item dropped/removed
4. Optionally add location and notes
5. Enter your name
6. Click "Record Action"

**What it does:**
- Creates action record with timestamp
- Updates item status in database
- Tracks who performed the action
- Associates action with source file

### View Inventory Tab
Browse inventory by status.

**How to use:**
1. Select filter (Pending, Placed, Showroom, Waitlist, Dropped)
2. Set limit (how many items to show)
3. Click "Load Items" to view inventory
4. Click "View Files" to see all uploaded Excel files

**What you'll see:**
- List of items matching the filter
- Item details (style, color, division, gender, width)
- Product images
- Source files for each item
- Total count

### Statistics Tab
View comprehensive inventory statistics.

**How to use:**
1. Click "Refresh Stats"

**What you'll see:**
- Total styles, items, and files processed
- Breakdown by action (pending, placed, showroom, etc.)
- Breakdown by width (regular, wide, extra wide)
- Breakdown by division
- Breakdown by gender

## Tips

### Style Numbers
- System accepts both 5 and 6 digit style numbers
- 5 digit numbers are automatically padded to 6 digits
- Examples: 04437 → 104437

### Color Codes
- Regular width: BBK, NVY, etc.
- Wide width: BBK (w), NVY (w)
- Extra wide: BBK (ww), NVY (ww)
- Always include the width suffix when recording actions

### File Tracking
- System tracks which Excel files contain each item
- Items appearing in multiple files show all source files
- Useful for tracking inventory updates over time

### Image Upload
- First upload may take 5-10 minutes for ~4,700 images
- Subsequent uploads are faster (skips duplicates)
- Images stored permanently in Supabase
- Each image URL is saved in database

## Troubleshooting

### UI won't load
- Make sure API server is running: `python main.py`
- Check that port 8001 is not blocked
- Try http://localhost:8001/health to test API

### Upload fails
- Ensure Excel file is .xlsx format
- Check file has required columns: style, color
- Verify Supabase credentials are set

### Images not showing
- Check that upload_images was enabled during upload
- Verify Supabase credentials are correct
- Some Excel files may not have embedded images

### Style not found
- Verify style number exists in database
- Try uploading the Excel file first
- Check if style number is correct (5-6 digits)

## API Endpoints

All endpoints are documented at: http://localhost:8001/docs

Key endpoints:
- `POST /upload-excel` - Upload Excel file
- `GET /scan/{style}` - Lookup style
- `POST /action` - Record action
- `GET /inventory/pending` - View pending items
- `GET /inventory/stats` - Get statistics
- `GET /inventory/files` - List uploaded files

## Database

Database file: `chukwu_inventory.db`

Tables:
- **items** - Individual color variants
- **style_summary** - Aggregated style data
- **inventory_actions** - Action history
- **file_uploads** - Uploaded file tracking

## Support

For issues or questions, check:
1. API logs in terminal
2. Browser console (F12)
3. Database file exists and is not corrupted
4. Supabase credentials are valid
