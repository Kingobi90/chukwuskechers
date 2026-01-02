"""Skechers tag scanner using OCR to extract style numbers and color codes."""
import cv2
import numpy as np
from PIL import Image
import pytesseract
import io
import re
from typing import Dict, Optional, List

# Skechers color code mapping
BASE_COLOR_CODES = {
    "BLK": "Black",
    "BBK": "Black",
    "BKMT": "Black/Multi",
    "BKCC": "Black/Charcoal",
    "BKBL": "Black/Blue",
    "BKGD": "Black/Gold",
    "BKGY": "Black/Gray",
    "BKGN": "Black/Green",
    "BKOR": "Black/Orange",
    "BKPK": "Black/Pink",
    "BKPR": "Black/Purple",
    "BKRD": "Black/Red",
    "BKSL": "Black/Silver",
    "BKWT": "Black/White",
    "BKW": "Black/White",
    "WHT": "White",
    "OFWT": "Off White",
    "WBK": "White/Black",
    "WBL": "White/Blue",
    "WCC": "White/Charcoal",
    "WGD": "White/Gold",
    "WGN": "White/Green",
    "WGY": "White/Gray",
    "WMT": "White/Multi",
    "WMLT": "White/Multi",
    "WNV": "White/Navy",
    "WOR": "White/Orange",
    "WPK": "White/Pink",
    "WPR": "White/Purple",
    "WRD": "White/Red",
    "WSL": "White/Silver",
    "WTP": "White/Taupe",
    "WBUG": "White/Burgundy",
    "NVY": "Navy",
    "NVBL": "Navy/Blue",
    "NVBK": "Navy/Black",
    "NVCC": "Navy/Charcoal",
    "NVGY": "Navy/Gray",
    "NVGN": "Navy/Green",
    "NVMT": "Navy/Multi",
    "NVOR": "Navy/Orange",
    "NVPK": "Navy/Pink",
    "NVRD": "Navy/Red",
    "NVWT": "Navy/White",
    "GRY": "Gray",
    "GRAY": "Gray",
    "GYBL": "Gray/Blue",
    "GYBK": "Gray/Black",
    "GYMT": "Gray/Multi",
    "GYOR": "Gray/Orange",
    "GYPK": "Gray/Pink",
    "GYRD": "Gray/Red",
    "GYWT": "Gray/White",
    "CHAR": "Charcoal",
    "CC": "Charcoal",
    "CCBK": "Charcoal/Black",
    "CCBL": "Charcoal/Blue",
    "CCLV": "Charcoal/Lavender",
    "CCOR": "Charcoal/Orange",
    "CCPK": "Charcoal/Pink",
    "BLU": "Blue",
    "LTBL": "Light Blue",
    "DKBL": "Dark Blue",
    "BLMT": "Blue/Multi",
    "BLPK": "Blue/Pink",
    "BLRD": "Blue/Red",
    "BLWT": "Blue/White",
    "BLGY": "Blue/Gray",
    "BLOR": "Blue/Orange",
    "RED": "Red",
    "RDBK": "Red/Black",
    "RDBR": "Red/Brown",
    "RDGY": "Red/Gray",
    "RDMT": "Red/Multi",
    "RDPK": "Red/Pink",
    "RDWT": "Red/White",
    "PINK": "Pink",
    "PNK": "Pink",
    "LTPK": "Light Pink",
    "PKMT": "Pink/Multi",
    "PKWT": "Pink/White",
    "PKBL": "Pink/Blue",
    "PKPR": "Pink/Purple",
    "PRPL": "Purple",
    "PRP": "Purple",
    "PRCL": "Purple/Coral",
    "PRMT": "Purple/Multi",
    "PRPK": "Purple/Pink",
    "PRWT": "Purple/White",
    "GRN": "Green",
    "LTGN": "Light Green",
    "DKGN": "Dark Green",
    "GNMT": "Green/Multi",
    "GNWT": "Green/White",
    "GNBL": "Green/Blue",
    "OLV": "Olive",
    "OLVG": "Olive Green",
    "BRN": "Brown",
    "DKBR": "Dark Brown",
    "LTBR": "Light Brown",
    "CDB": "Brown",
    "BRMT": "Brown/Multi",
    "BRWT": "Brown/White",
    "BGE": "Beige",
    "TAN": "Tan",
    "TPE": "Taupe",
    "TAUP": "Taupe",
    "DKTP": "Dark Taupe",
    "LTTN": "Light Tan",
    "SAND": "Sand",
    "KHAK": "Khaki",
    "KHK": "Khaki",
    "NAT": "Natural",
    "NTMT": "Natural/Multi",
    "NTTN": "Natural/Tan",
    "ORG": "Orange",
    "ORNG": "Orange",
    "ORMT": "Orange/Multi",
    "ORWT": "Orange/White",
    "ORBL": "Orange/Blue",
    "CRL": "Coral",
    "YLW": "Yellow",
    "YLLW": "Yellow",
    "YLMT": "Yellow/Multi",
    "YLWT": "Yellow/White",
    "MULT": "Multi",
    "MLTI": "Multi",
    "CAMO": "Camouflage",
    "PRNT": "Print",
    "FLRL": "Floral",
    "SLV": "Silver",
    "SLVR": "Silver",
    "GLD": "Gold",
    "GOLD": "Gold",
    "RSGD": "Rose Gold",
    "BRNZ": "Bronze",
    "STN": "Stone",
    "SLTP": "Slate/Pink",
    "SLAT": "Slate",
    "MVE": "Mauve",
    "MAUV": "Mauve",
    "LAV": "Lavender",
    "LVND": "Lavender",
    "MINT": "Mint",
    "TEAL": "Teal",
    "TRQ": "Turquoise",
    "COC": "Cocoa",
    "COCO": "Cocoa",
    "WINE": "Wine",
    "BUG": "Burgundy",
    "BURG": "Burgundy",
    "PLUM": "Plum",
    "PEACH": "Peach",
    "LMGN": "Lime Green",
    "LIME": "Lime"
}


def preprocess_tag_image(image_data: bytes) -> np.ndarray:
    """
    Preprocess tag image for better OCR results.
    
    Args:
        image_data: Image bytes
        
    Returns:
        Preprocessed image as numpy array
    """
    # Convert bytes to PIL Image
    image = Image.open(io.BytesIO(image_data))
    
    # Convert to numpy array
    img_array = np.array(image)
    
    # Convert to grayscale
    if len(img_array.shape) == 3:
        gray = cv2.cvtColor(img_array, cv2.COLOR_RGB2GRAY)
    else:
        gray = img_array
    
    # Apply thresholding to get better contrast
    _, thresh = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    
    # Denoise
    denoised = cv2.fastNlMeansDenoising(thresh, None, 10, 7, 21)
    
    return denoised


def extract_text_from_tag(image_data: bytes) -> str:
    """
    Extract all text from tag using OCR.
    Tries multiple preprocessing methods for best results.
    
    Args:
        image_data: Image bytes
        
    Returns:
        Extracted text
    """
    try:
        # Get multiple preprocessed versions
        processed_images = preprocess_tag_image(image_data)
        
        all_text = []
        
        # Try OCR on each preprocessed version
        for img in processed_images:
            # Try different PSM modes
            for psm in [6, 3, 11]:  # 6=uniform block, 3=auto, 11=sparse text
                try:
                    text = pytesseract.image_to_string(img, config=f'--psm {psm}')
                    if text.strip():
                        all_text.append(text)
                except:
                    continue
        
        # Combine all extracted text
        combined_text = '\n'.join(all_text)
        return combined_text if combined_text else ''
        
    except Exception as e:
        raise Exception(f"OCR failed: {str(e)}")


def parse_style_number(text: str) -> Optional[str]:
    """
    Extract style number from OCR text.
    Looks for patterns like: SN144844, 141495, SN190099
    
    Args:
        text: OCR extracted text
        
    Returns:
        Style number or None
    """
    # Pattern 1: SN followed by 6 digits
    match = re.search(r'SN\s*(\d{6})', text, re.IGNORECASE)
    if match:
        return match.group(1)
    
    # Pattern 2: Standalone 6-digit number
    match = re.search(r'\b(\d{6})\b', text)
    if match:
        return match.group(1)
    
    # Pattern 3: Any sequence of 5-7 digits (fallback)
    match = re.search(r'\b(\d{5,7})\b', text)
    if match:
        digits = match.group(1)
        # Pad or trim to 6 digits
        if len(digits) < 6:
            return digits.zfill(6)
        elif len(digits) > 6:
            return digits[:6]
        return digits
    
    return None


def parse_color_code(text: str) -> List[Dict[str, str]]:
    """
    Extract all possible color codes from OCR text.
    Finds exact sequential matches only - no guessing.
    
    Args:
        text: OCR extracted text
        
    Returns:
        List of dictionaries with color_code and color_name, ordered by confidence
    """
    text_upper = text.upper()
    found_colors = []
    
    # Priority 1: Look for color codes after "COLOR" or "CLR CODE" labels
    for pattern in [r'COLOR[:\s]+([A-Z]{2,6})', r'CLR\s*CODE[:\s]+([A-Z]{2,6})', r'CLR[:\s]+([A-Z]{2,6})']:
        match = re.search(pattern, text_upper)
        if match:
            color_code = match.group(1)
            if color_code in BASE_COLOR_CODES:
                found_colors.append({
                    'color_code': color_code,
                    'color_name': BASE_COLOR_CODES[color_code],
                    'confidence': 'high',
                    'source': 'labeled'
                })
    
    # Priority 2: Find all exact matches of known color codes with word boundaries
    # Sort by length (longest first) to avoid matching substrings
    for color_code in sorted(BASE_COLOR_CODES.keys(), key=len, reverse=True):
        pattern = r'\b' + re.escape(color_code) + r'\b'
        matches = re.finditer(pattern, text_upper)
        for match in matches:
            color_dict = {
                'color_code': color_code,
                'color_name': BASE_COLOR_CODES[color_code],
                'confidence': 'medium',
                'source': 'exact_match',
                'position': match.start()
            }
            # Avoid duplicates
            if not any(c['color_code'] == color_code for c in found_colors):
                found_colors.append(color_dict)
    
    # Sort by confidence (high first) then by position in text
    found_colors.sort(key=lambda x: (0 if x['confidence'] == 'high' else 1, x.get('position', 999)))
    
    return found_colors


def scan_skechers_tag(image_data: bytes) -> Dict:
    """
    Scan Skechers tag and extract style number and color code.
    
    Args:
        image_data: Tag image bytes
        
    Returns:
        Dictionary with scan results including all detected colors
    """
    try:
        # Extract text from tag
        text = extract_text_from_tag(image_data)
        
        # Parse style number
        style_number = parse_style_number(text)
        
        # Parse all possible color codes
        color_matches = parse_color_code(text)
        
        if not style_number and not color_matches:
            return {
                'success': False,
                'message': 'Could not detect style number or color code',
                'raw_text': text
            }
        
        # Primary color is the first (highest confidence) match
        primary_color = color_matches[0] if color_matches else None
        
        result = {
            'success': True,
            'message': 'Tag scanned successfully',
            'style_number': style_number,
            'color_code': primary_color['color_code'] if primary_color else None,
            'color_name': primary_color['color_name'] if primary_color else None,
            'all_colors': color_matches,
            'multiple_colors_detected': len(color_matches) > 1,
            'raw_text': text
        }
        
        return result
        
    except Exception as e:
        return {
            'success': False,
            'message': f'Tag scanning failed: {str(e)}',
            'raw_text': ''
        }
