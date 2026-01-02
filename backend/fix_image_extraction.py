"""
Properly extract images from Excel file and match them to style/color combinations.
This fixes the image mismatch issue by ensuring each image is correctly named.
"""
import pandas as pd
import openpyxl
from PIL import Image
import io
import os
import re
from pathlib import Path


def extract_images_correctly(excel_path: str, output_dir: str = "static/images_fixed"):
    """
    Extract images from Excel and match them to the correct style/color from the same row.

    Args:
        excel_path: Path to the Excel file
        output_dir: Directory to save corrected images
    """
    print("=" * 70)
    print("  FIXING IMAGE EXTRACTION")
    print("=" * 70)
    print(f"\nReading Excel file: {excel_path}")

    # Create output directory
    Path(output_dir).mkdir(parents=True, exist_ok=True)

    # Read the Excel data
    df = pd.read_excel(excel_path)
    df.columns = df.columns.str.strip().str.lower()

    print(f"Found {len(df)} rows in Excel")
    print(f"Columns: {list(df.columns)}")

    # Load workbook to extract images
    wb = openpyxl.load_workbook(excel_path)
    sheet = wb.active

    # Get all images and their positions
    images_by_row = {}
    for img in sheet._images:
        # Get the row where this image is anchored
        # Images are anchored to cells, we need to find which row
        if hasattr(img, 'anchor') and hasattr(img.anchor, '_from'):
            row_idx = img.anchor._from.row  # 0-based row in openpyxl
            if row_idx not in images_by_row:
                images_by_row[row_idx] = []
            images_by_row[row_idx].append(img)

    print(f"Found {len(images_by_row)} rows with images")

    # Process each row and extract the image
    extracted_count = 0
    skipped_count = 0

    for excel_row_idx, images in sorted(images_by_row.items()):
        # Excel rows are 1-indexed and first row is header (row 1)
        # So data starts at row 2 (index 1), which corresponds to df row 0
        df_row_idx = excel_row_idx - 1  # Adjust for header row

        if df_row_idx < 0 or df_row_idx >= len(df):
            print(f"Skipping row {excel_row_idx} - out of data range")
            skipped_count += 1
            continue

        # Get the data for this row
        row_data = df.iloc[df_row_idx]

        # Extract style and color
        style_raw = str(row_data.get('style', '')).strip()
        color_raw = str(row_data.get('color', '')).strip()

        if not style_raw or not color_raw or style_raw == 'nan' or color_raw == 'nan':
            print(f"Skipping row {excel_row_idx} - missing style or color")
            skipped_count += 1
            continue

        # Clean up style (extract base digits, pad to 6)
        style_match = re.match(r'^(\d+)', style_raw)
        if style_match:
            style_clean = style_match.group(1).zfill(6)
        else:
            print(f"Skipping row {excel_row_idx} - invalid style: {style_raw}")
            skipped_count += 1
            continue

        # Clean up color (remove spaces before width indicators)
        color_clean = color_raw.replace(' (w)', '').replace(' (ww)', '').replace('(w)', '').replace('(ww)', '').strip()

        # Process the first image in this row
        if images:
            img_obj = images[0]

            try:
                # Get image data
                image_data = img_obj._data()
                pil_image = Image.open(io.BytesIO(image_data))

                # Save with correct filename
                filename = f"{style_clean}_{color_clean}.jpg"
                filepath = os.path.join(output_dir, filename)

                # Convert to RGB if necessary
                if pil_image.mode != 'RGB':
                    pil_image = pil_image.convert('RGB')

                pil_image.save(filepath, 'JPEG', quality=95)

                print(f"Row {excel_row_idx:4d} -> {filename:30s} (Style: {style_raw}, Color: {color_raw})")
                extracted_count += 1

            except Exception as e:
                print(f"✗ Row {excel_row_idx} - Error saving image: {e}")
                skipped_count += 1

    wb.close()

    print("\n" + "=" * 70)
    print("  EXTRACTION COMPLETE")
    print("=" * 70)
    print(f"Successfully extracted: {extracted_count} images")
    print(f"Skipped: {skipped_count} images")
    print(f"Saved to: {output_dir}")
    print("\nNext steps:")
    print("1. Review the images in the output directory")
    print("2. If they look correct, backup your current images:")
    print(f"   mv static/images static/images_backup_{pd.Timestamp.now().strftime('%Y%m%d_%H%M%S')}")
    print("3. Replace with the corrected images:")
    print(f"   mv {output_dir} static/images")


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("\nUsage: python fix_image_extraction.py <excel_file_path>")
        print("\nExample:")
        print("  python fix_image_extraction.py inventory_data.xlsx")
        sys.exit(1)

    excel_file = sys.argv[1]

    if not os.path.exists(excel_file):
        print(f"Error: File not found: {excel_file}")
        sys.exit(1)

    extract_images_correctly(excel_file)
