#!/usr/bin/env python3
"""
Quick script to extract images from Excel file and fix the mismatch.
Usage: python run_image_extraction.py <excel_file_path>
"""
import sys
import os
from excel_parser import InventoryParser

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("\n" + "=" * 70)
        print("  IMAGE EXTRACTION TOOL")
        print("=" * 70)
        print("\nUsage: python run_image_extraction.py <excel_file_path>")
        print("\nExample:")
        print("  python run_image_extraction.py inventory.xlsx")
        print("\nThis will:")
        print("  1. Backup existing images to static/images_backup_TIMESTAMP")
        print("  2. Extract images from Excel with correct style_color naming")
        print("  3. Save to static/images/")
        sys.exit(1)

    excel_file = sys.argv[1]

    if not os.path.exists(excel_file):
        print(f"Error: File not found: {excel_file}")
        sys.exit(1)

    print("\n" + "=" * 70)
    print("  EXTRACTING IMAGES FROM EXCEL")
    print("=" * 70)
    print(f"\nFile: {excel_file}\n")

    # Parse Excel
    try:
        parser = InventoryParser(excel_file)
        print(f"Loaded {parser.get_style_count()} unique styles\n")
    except Exception as e:
        print(f"Error loading Excel: {str(e)}")
        sys.exit(1)

    # Backup existing images
    import shutil
    from datetime import datetime
    backup_dir = f"static/images_backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    if os.path.exists("static/images"):
        print(f"Backing up existing images to {backup_dir}...")
        shutil.copytree("static/images", backup_dir)
        print("Backup complete\n")

    # Extract images
    print("Extracting images...")
    print("-" * 70)
    result = parser.extract_images_to_folder("static/images")
    print("-" * 70)

    if 'error' in result:
        print(f"\nExtraction failed: {result['error']}")
        sys.exit(1)
    else:
        print(f"\nEXTRACTION COMPLETE!")
        print(f"   Extracted: {result['extracted']} images")
        print(f"   Skipped: {result['skipped']} images")
        print(f"   Saved to: {result['output_dir']}")
        print(f"   Backup: {backup_dir}")
        print("\n" + "=" * 70)
        print("Images are now correctly matched to their style/color!")
        print("Refresh your warehouse page to see the corrected images.")
        print("=" * 70)
