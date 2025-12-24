"""Manual script to extract images from uploaded Excel files."""
import os
import sys
from excel_parser import InventoryParser

def main():
    # Check if file path provided
    if len(sys.argv) < 2:
        print("Usage: python extract_images_manual.py <path_to_excel_file>")
        print("\nThis will extract images to static/images/ folder")
        sys.exit(1)
    
    excel_file = sys.argv[1]
    
    if not os.path.exists(excel_file):
        print(f"Error: File not found: {excel_file}")
        sys.exit(1)
    
    print(f"Loading Excel file: {excel_file}")
    parser = InventoryParser(excel_file)
    
    print(f"Found {parser.get_style_count()} styles")
    print("\nExtracting images...")
    
    result = parser.extract_images_to_folder("static/images")
    
    if 'error' in result:
        print(f"\nError: {result['error']}")
    else:
        print(f"\nExtraction complete!")
        print(f"   Extracted: {result['extracted']} images")
        print(f"   Skipped: {result['skipped']} images")
        print(f"   Output: {result['output_dir']}")

if __name__ == "__main__":
    main()
