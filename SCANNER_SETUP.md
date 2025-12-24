# Barcode Scanner Setup Instructions

## Overview
The barcode scanner feature allows you to quickly search for items by scanning barcodes or QR codes using your device camera or uploaded images.

## Dependencies Installed
- `opencv-python` - Computer vision library
- `pyzbar` - Barcode/QR code decoding
- `pillow` - Image processing
- `zbar` (system library) - Barcode scanning engine

## System Requirements

### macOS
The `zbar` system library was installed via Homebrew:
```bash
brew install zbar
```

### Running the Server
To ensure the scanner works, start the server with the library path set:
```bash
export DYLD_LIBRARY_PATH=/opt/homebrew/lib:$DYLD_LIBRARY_PATH
python main.py
```

Or create a startup script `start_server.sh`:
```bash
#!/bin/bash
export DYLD_LIBRARY_PATH=/opt/homebrew/lib:$DYLD_LIBRARY_PATH
python main.py
```

Make it executable:
```bash
chmod +x start_server.sh
./start_server.sh
```

## How to Use

### In the Web Interface
1. Go to the **"Search & Place Items"** tab
2. Find the **"Barcode Scanner"** section
3. Click "Choose File" to select a barcode image
   - You can use your phone camera to take a photo of a barcode
   - Or upload an existing barcode image
4. Click **"Scan Barcode"**
5. The system will:
   - Decode the barcode
   - Extract the style number
   - Display the results
   - Provide a button to automatically search for that style

### Supported Barcode Types
- QR Code
- Code 128
- Code 39
- EAN-13
- UPC-A
- And many more standard barcode formats

### Mobile Usage
On mobile devices, the file input has `capture="environment"` which allows you to:
- Take a photo directly with your camera
- Scan barcodes in real-time

## API Endpoint

### POST `/scan-barcode`
Upload an image containing a barcode to decode it.

**Request:**
- Method: POST
- Content-Type: multipart/form-data
- Body: Image file

**Response:**
```json
{
  "success": true,
  "message": "Detected 1 barcode(s)",
  "barcodes": [
    {
      "raw_data": "100702",
      "type": "CODE128",
      "style_number": "100702",
      "bbox": {
        "x": 50,
        "y": 100,
        "width": 200,
        "height": 80
      }
    }
  ]
}
```

## Troubleshooting

### "Unable to find zbar shared library" Error
If you see this error, make sure:
1. zbar is installed: `brew install zbar`
2. Library path is set when running the server
3. Restart the server after installing zbar

### Barcode Not Detected
- Ensure the barcode image is clear and well-lit
- Try different angles or distances
- Make sure the barcode is not blurry or damaged
- The barcode should be the main focus of the image

### Style Number Extraction
The scanner automatically extracts 6-digit style numbers from barcode data. If your barcodes have a different format, you may need to adjust the `extract_style_number()` function in `barcode_scanner.py`.

## Files Added
- `barcode_scanner.py` - Scanner utility module
- `requirements.txt` - Updated with scanner dependencies
- `SCANNER_SETUP.md` - This setup guide
