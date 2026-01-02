"""Barcode and QR code scanner utility using OpenCV and pyzbar."""
import cv2
import numpy as np
from pyzbar import pyzbar
from PIL import Image
import io
from typing import List, Dict, Optional


def decode_barcode_from_image(image_data: bytes) -> List[Dict]:
    """
    Decode barcodes/QR codes from image data.
    
    Args:
        image_data: Image bytes (from uploaded file or camera capture)
        
    Returns:
        List of decoded barcode information
    """
    try:
        # Convert bytes to PIL Image
        image = Image.open(io.BytesIO(image_data))
        
        # Convert to numpy array for OpenCV
        img_array = np.array(image)
        
        # Convert RGB to BGR for OpenCV
        if len(img_array.shape) == 3 and img_array.shape[2] == 3:
            img_array = cv2.cvtColor(img_array, cv2.COLOR_RGB2BGR)
        
        # Decode barcodes
        barcodes = pyzbar.decode(img_array)
        
        results = []
        for barcode in barcodes:
            # Extract barcode data
            barcode_data = barcode.data.decode('utf-8')
            barcode_type = barcode.type
            
            # Get bounding box coordinates
            x, y, w, h = barcode.rect
            
            results.append({
                'data': barcode_data,
                'type': barcode_type,
                'bbox': {'x': x, 'y': y, 'width': w, 'height': h}
            })
        
        return results
        
    except Exception as e:
        raise Exception(f"Barcode decoding failed: {str(e)}")


def extract_style_number(barcode_data: str) -> Optional[str]:
    """
    Extract style number from barcode data.
    Assumes barcode contains style number (6 digits).
    
    Args:
        barcode_data: Decoded barcode string
        
    Returns:
        Extracted style number or None
    """
    # Remove any non-numeric characters
    import re
    
    # Try to find 6-digit style number
    match = re.search(r'\d{6}', barcode_data)
    if match:
        return match.group(0)
    
    # Try to find any sequence of digits
    match = re.search(r'\d+', barcode_data)
    if match:
        return match.group(0).zfill(6)  # Pad to 6 digits
    
    # Return the whole data if no digits found
    return barcode_data if barcode_data else None


def process_camera_frame(frame_data: bytes) -> Dict:
    """
    Process a single camera frame for barcode detection.
    
    Args:
        frame_data: Camera frame as bytes
        
    Returns:
        Dictionary with scan results and extracted style number
    """
    barcodes = decode_barcode_from_image(frame_data)
    
    if not barcodes:
        return {
            'success': False,
            'message': 'No barcode detected',
            'barcodes': []
        }
    
    # Extract style numbers from all detected barcodes
    results = []
    for barcode in barcodes:
        style_number = extract_style_number(barcode['data'])
        results.append({
            'raw_data': barcode['data'],
            'type': barcode['type'],
            'style_number': style_number,
            'bbox': barcode['bbox']
        })
    
    return {
        'success': True,
        'message': f'Detected {len(barcodes)} barcode(s)',
        'barcodes': results
    }
