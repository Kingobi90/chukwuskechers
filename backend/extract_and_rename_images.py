"""
Extract images from Excel file and save them with correct style_color naming.
This script will properly extract and name images from embedded Excel images.
"""
import openpyxl
from openpyxl_image_loader import SheetImageLoader
import os
import shutil
from pathlib import Path
import pandas as pd


def extract_images_from_excel(excel_path: str, output_dir: str = "static/images"):
    """
    Extract images from Excel file and save with style_color.jpg naming.

    Args:
        excel_path: Path to Excel file
        output_dir: Directory to save images (default: static/images)
    """
    # Create output directory if it doesn't exist
    Path(output_dir).mkdir(parents=True, exist_ok=True)

    # Read Excel data to get style-color mapping
    df = pd.read_excel(excel_path)
    df.columns = df.columns.str.strip().str.lower()

    # Load workbook for images
    wb = openpyxl.load_workbook(excel_path)
    sheet = wb.active

    try:
        # Try to load images using openpyxl_image_loader
        image_loader = SheetImageLoader(sheet)

        # Map row numbers to style-color
        row_to_item = {}
        for idx, row in df.iterrows():
            excel_row = idx + 2  # Excel rows start at 1, header is row 1, data starts at 2
            style = str(row.get('style', '')).strip()
            color = str(row.get('color', '')).strip()

            # Clean up style (remove variants if present)
            import re
            style_match = re.match(r'^(\d+)', style)
            if style_match:
                style_clean = style_match.group(1).zfill(6)
            else:
                style_clean = style

            # Clean up color (remove spaces before parentheses)
            color_clean = color.replace(' (w)', '').replace(' (ww)', '')

            if style_clean and color_clean:
                row_to_item[excel_row] = (style_clean, color_clean)

        # Extract images
        extracted_count = 0
        for row_num, (style, color) in row_to_item.items():
            # Try to get image from various possible columns (A, B, C, etc.)
            for col in ['A', 'B', 'C', 'D', 'E']:
                cell = f'{col}{row_num}'
                if image_loader.image_in(cell):
                    image = image_loader.get(cell)
                    filename = f"{style}_{color}.jpg"
                    filepath = os.path.join(output_dir, filename)

                    # Save image
                    image.save(filepath, 'JPEG')
                    print(f"Extracted: {filename} from cell {cell}")
                    extracted_count += 1
                    break

        print(f"\nExtraction complete! Extracted {extracted_count} images to {output_dir}")

    except ImportError:
        print("Error: openpyxl_image_loader not installed.")
        print("Install it with: pip install openpyxl-image-loader")
        print("\nAlternative: Use the built-in image extraction method...")
        extract_images_builtin(excel_path, output_dir)
    except Exception as e:
        print(f"Error extracting images: {e}")
        print("\nTrying alternative extraction method...")
        extract_images_builtin(excel_path, output_dir)

    wb.close()


def extract_images_builtin(excel_path: str, output_dir: str = "static/images"):
    """
    Alternative method using openpyxl's built-in image handling.
    """
    from openpyxl.drawing.image import Image as OpenpyxlImage
    import openpyxl

    # Read Excel data
    df = pd.read_excel(excel_path)
    df.columns = df.columns.str.strip().str.lower()

    # Load workbook
    wb = openpyxl.load_workbook(excel_path)
    sheet = wb.active

    # Get all images from the sheet
    images = []
    for image in sheet._images:
        images.append(image)

    print(f"Found {len(images)} images in the Excel file")
    print(f"Found {len(df)} data rows")

    # Match images to rows (assuming images are in order)
    extracted_count = 0
    for idx, (image, (_, row)) in enumerate(zip(images, df.iterrows())):
        style = str(row.get('style', '')).strip()
        color = str(row.get('color', '')).strip()

        # Clean up style
        import re
        style_match = re.match(r'^(\d+)', style)
        if style_match:
            style_clean = style_match.group(1).zfill(6)
        else:
            continue

        # Clean up color
        color_clean = color.replace(' (w)', '').replace(' (ww)', '')

        if style_clean and color_clean:
            filename = f"{style_clean}_{color_clean}.jpg"
            filepath = os.path.join(output_dir, filename)

            # Save image
            try:
                with open(filepath, 'wb') as f:
                    f.write(image._data())
                print(f"Extracted: {filename}")
                extracted_count += 1
            except Exception as e:
                print(f"✗ Failed to extract {filename}: {e}")

    print(f"\nExtraction complete! Extracted {extracted_count} images to {output_dir}")
    wb.close()


if __name__ == "__main__":
    import sys

    print("=" * 60)
    print("  IMAGE EXTRACTION AND RENAMING TOOL")
    print("=" * 60)
    print("\nThis tool extracts images from Excel and names them correctly")
    print("as style_color.jpg (e.g., 104450_BBK.jpg)\n")

    if len(sys.argv) > 1:
        excel_file = sys.argv[1]
    else:
        excel_file = input("Enter path to Excel file: ").strip()

    if not os.path.exists(excel_file):
        print(f"Error: File not found: {excel_file}")
        sys.exit(1)

    # Backup existing images
    backup_dir = "static/images_backup"
    if os.path.exists("static/images") and os.listdir("static/images"):
        print(f"\nBacking up existing images to {backup_dir}...")
        if os.path.exists(backup_dir):
            shutil.rmtree(backup_dir)
        shutil.copytree("static/images", backup_dir)
        print("Backup complete")

    print(f"\nExtracting images from {excel_file}...\n")
    extract_images_from_excel(excel_file)
