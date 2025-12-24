# Chukwu - Skechers Inventory Management System

Excel parser and inventory management system for Skechers product data with embedded image extraction and Supabase storage.

## Features

- Parse Excel files with Skechers inventory data
- Group style variants (w/ww suffixes) under base style numbers
- Extract embedded images from Excel files
- Upload images directly to Supabase storage (no local disk writes)
- SQLite/PostgreSQL database with full tracking
- Track which source files contain each style+color
- Interactive terminal interface
- Database viewer

## Installation

```bash
cd /Users/obinna.c/CascadeProjects/chukwu
pip install -r requirements.txt
```

## Setup

### 1. Initialize Database

```bash
python database.py
```

### 2. Configure Supabase (for image uploads)

Set environment variables:

```bash
export SUPABASE_URL='https://your-project.supabase.co'
export SUPABASE_KEY='your-service-role-key'
```

Or create a `.env` file:

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-service-role-key
```

## Usage

### Option 1: Parse Excel Only (No Images)

```bash
python excel_parser.py
```

Interactive menu:
- [1] Lookup style
- [2] List all styles
- [3] Save to database
- [4] Exit

### Option 2: Process Excel with Image Upload

```bash
python process_with_images.py
```

This will:
1. Parse Excel data
2. Extract embedded images
3. Upload images to Supabase
4. Save everything to database with image URLs

### Option 3: Extract Images Only

```bash
python image_processor.py /path/to/excel/file.xlsx
```

### View Database

```bash
python view_database.py
```

Interactive viewer:
- [1] View all styles (summary)
- [2] View items for a specific style
- [3] View recent items
- [4] View all source files
- [5] Search styles by division
- [6] Exit

## Database Schema

### `items` Table
Stores individual color variants with detailed information.

| Column | Type | Description |
|--------|------|-------------|
| id | Integer | Primary key |
| style | String(6) | 6-digit style number (e.g., "104437") |
| color | String(100) | Color code with variant suffix (e.g., "BBK (w)") |
| division | String(100) | Product division |
| outsole | String(100) | Outsole type |
| gender | String(50) | Gender category |
| image_url | String(500) | Supabase public URL |
| source_files | JSON | Array of Excel files containing this item |
| created_at | DateTime | Creation timestamp |
| updated_at | DateTime | Last update timestamp |

**Unique Constraint:** `(style, color)` - One row per style+color combination

### `style_summary` Table
Aggregated view with one row per style number.

| Column | Type | Description |
|--------|------|-------------|
| style | String(6) | Primary key - 6-digit style number |
| all_colors | JSON | Array of all color variants |
| division | String(100) | Product division |
| outsole | String(100) | Outsole type |
| gender | String(50) | Gender category |
| source_files | JSON | Array of Excel files containing this style |
| color_count | Integer | Number of color variants |
| created_at | DateTime | Creation timestamp |
| updated_at | DateTime | Last update timestamp |

## How It Works

### Style Variant Grouping

Styles with width suffixes (w/ww) are grouped under the base style:
- `104437`, `104437w`, `104437ww` → All grouped under `104437`
- Colors are annotated: `BBK`, `BBK (w)`, `BBK (ww)`

### Multi-File Tracking

When the same style+color appears in multiple Excel files:
- Single database row for that combination
- `source_files` array contains all file names
- Example: `["wof 09.03.2025.xlsx", "wof 11.25.2025.xlsx"]`

### Image Processing

1. **Extract:** Read embedded images from Excel using openpyxl
2. **Match:** Determine style+color from image position in spreadsheet
3. **Upload:** Send directly to Supabase storage (in-memory, no disk writes)
4. **Store:** Save public URL in database

**Performance:**
- Batch uploads: 100 images at a time
- Parallel processing: 10 concurrent uploads
- Retry logic: 3 attempts with exponential backoff
- ~4,700 images uploaded in minutes

## File Structure

```
chukwu/
├── database.py              # SQLAlchemy models and database setup
├── excel_parser.py          # Excel parsing and terminal interface
├── image_processor.py       # Image extraction and Supabase upload
├── process_with_images.py   # Complete workflow integration
├── view_database.py         # Database viewer
├── requirements.txt         # Python dependencies
├── README.md               # This file
└── chukwu_inventory.db     # SQLite database (auto-created)
```

## Example Workflow

```bash
# 1. Initialize database
python database.py

# 2. Set Supabase credentials
export SUPABASE_URL='https://xxx.supabase.co'
export SUPABASE_KEY='your-key'

# 3. Process Excel files with images
python process_with_images.py

# 4. View results
python view_database.py
```

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `SUPABASE_URL` | Supabase project URL | For image uploads |
| `SUPABASE_KEY` | Supabase service role key | For image uploads |
| `DATABASE_URL` | PostgreSQL connection string | Optional (defaults to SQLite) |

## Database Configuration

**Default:** SQLite at `chukwu_inventory.db`

**PostgreSQL:** Set `DATABASE_URL` environment variable:
```bash
export DATABASE_URL='postgresql://user:pass@host:5432/dbname'
```

## Notes

- Excel files must have `style` and `color` columns (case-insensitive)
- Optional columns: `division`, `outsole`, `gender` (default to "N/A" if missing)
- Images are embedded in Excel files, not URLs in cells
- Supabase bucket `product-images` is created automatically
- All images stored at path: `images/{style}/{color}.{format}`

## Troubleshooting

**No images uploaded?**
- Check if Excel file has embedded images (not just empty image column)
- Verify Supabase credentials are correct
- Check Supabase storage bucket permissions

**Database errors?**
- Delete `chukwu_inventory.db` and run `python database.py` to recreate
- Check PostgreSQL connection if using DATABASE_URL

**Import errors?**
- Run `pip install -r requirements.txt` to install dependencies
- Ensure Python 3.8+ is installed
