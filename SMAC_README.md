# SMAC Warehouse Management System

A modern, state-of-the-art warehouse management system with a beautiful UI inspired by the SMAC Agence brand.

## 🎨 Design

The new UI features:
- **Green & Black Color Scheme** - Inspired by the SMAC Agence logo (#4CAF50 green with black accents)
- **Modern Sidebar Navigation** - Sleek, responsive sidebar with smooth transitions
- **Card-Based Layout** - Clean, organized content cards with hover effects
- **Responsive Design** - Fully optimized for desktop, tablet, and mobile devices
- **Smooth Animations** - Professional fade-in and slide-up animations
- **Touch-Friendly** - Optimized for touch devices with proper target sizes

## 🚀 Quick Start

### Start the Server

```bash
python3 run.py
```

Or manually:

```bash
uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000
```

### Access the Application

- **New SMAC UI**: http://localhost:8000
- **Old Warehouse UI**: http://localhost:8000/warehouse
- **API Documentation**: http://localhost:8000/docs

## 📁 Project Structure

```
chukwu/
├── backend/                    # All Python backend files
│   ├── __init__.py
│   ├── main.py                # FastAPI application
│   ├── database.py            # Database models and connection
│   ├── schemas.py             # Pydantic schemas
│   ├── excel_parser.py        # Excel file processing
│   ├── analytics_routes.py    # Analytics endpoints
│   ├── seasonal_drop.py       # Seasonal drop management
│   ├── barcode_scanner.py     # Barcode scanning
│   └── tag_scanner.py         # OCR tag scanning
├── static/                     # Frontend files
│   ├── index.html             # New SMAC UI (main)
│   ├── warehouse.html         # Old UI (backup)
│   ├── styles.css             # SMAC UI styles
│   ├── app.js                 # JavaScript functionality
│   └── images/                # Product images
├── run.py                      # Startup script
├── requirements.txt            # Python dependencies
└── chukwu_inventory.db        # SQLite database

```

## ✨ Features

### 📤 Upload Excel
- Upload and parse Excel inventory files
- Automatic image extraction from Excel
- Real-time upload progress
- File management (view, delete)

### 🍂 Seasonal Drop
- Process seasonal inventory updates
- Automatically mark dropped items
- Generate location-based reports
- Export dropped items list

### 📦 Visual Shelves
- Interactive warehouse visualization
- View items by room, shelf, and row
- Click items for detailed profiles
- Real-time inventory display

### 📍 Manage Locations
- Create rooms, shelves, and rows
- Hierarchical warehouse structure
- Visual location tree
- Easy location management

### 🔍 Search & Place Items
- Search by style number and color
- Barcode scanner support
- OCR tag scanner with live camera
- Assign items to locations
- Remove item locations

### 📋 View Inventory
- Filter by status (pending, placed, showroom, waitlist, dropped)
- Grid view with images
- Item details on click
- Status badges

### 📊 Statistics
- Total items and styles count
- Placement statistics
- Status breakdown
- Real-time updates

### 📈 Analytics Dashboard
- File comparison and trends
- Timeline analysis
- Division trends
- Style family analysis
- Overlap analysis
- Placement analytics

## 🎯 Key Improvements

### UI/UX
- Modern gradient backgrounds
- Smooth hover effects and transitions
- Professional color scheme
- Intuitive navigation
- Mobile-first responsive design

### Performance
- Optimized API calls
- Efficient data loading
- Smooth animations
- Fast page transitions

### Accessibility
- Touch-friendly buttons (44px minimum)
- High contrast text
- Clear visual hierarchy
- Keyboard navigation support

## 🛠️ Technology Stack

**Backend:**
- FastAPI - Modern Python web framework
- SQLAlchemy - Database ORM
- Pandas - Excel processing
- OpenCV - Image processing
- Pillow - Image manipulation

**Frontend:**
- Vanilla JavaScript - No framework overhead
- CSS3 - Modern styling with gradients and animations
- Chart.js - Data visualization
- Inter Font - Professional typography

**Database:**
- SQLite - Lightweight, file-based database

## 📱 Mobile Optimization

The new SMAC UI is fully optimized for mobile devices:
- Responsive breakpoints at 768px and 480px
- Collapsible sidebar navigation
- Stacked layouts on small screens
- Touch-optimized controls
- Optimized image sizes
- Landscape mode support

## 🎨 Color Palette

- **Primary Green**: #4CAF50
- **Dark Green**: #388E3C
- **Light Green**: #81C784
- **Black**: #1a1a1a
- **Dark Gray**: #2c2c2c
- **Medium Gray**: #424242
- **Light Gray**: #f5f5f5
- **White**: #ffffff

## 🔧 Configuration

The system uses environment variables for configuration. Create a `.env` file:

```env
DATABASE_URL=sqlite:///./chukwu_inventory.db
```

## 📝 API Endpoints

All existing API endpoints remain unchanged:
- `/upload-excel` - Upload Excel files
- `/inventory/*` - Inventory management
- `/locations/*` - Location management
- `/analytics/*` - Analytics data
- `/seasonal-drop/*` - Seasonal operations
- `/scan-barcode` - Barcode scanning
- `/scan-tag` - Tag OCR scanning

## 🎉 What's New

1. **Brand New UI** - Modern design inspired by SMAC Agence logo
2. **Improved Navigation** - Sleek sidebar with icons
3. **Better Mobile Support** - Fully responsive across all devices
4. **Enhanced Visuals** - Gradients, shadows, and smooth animations
5. **Professional Look** - State-of-the-art design patterns
6. **Organized Backend** - All Python files in dedicated backend folder
7. **Easy Startup** - Simple run.py script to launch everything

## 🔄 Migration Notes

- Old UI still accessible at `/warehouse`
- All API endpoints unchanged
- Database structure unchanged
- All existing functionality preserved
- No data migration needed

## 📞 Support

For issues or questions, refer to the original README.md or contact the development team.

---

**Built with ❤️ for SMAC Agence**
