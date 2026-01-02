import pandas as pd
import re
import os
from typing import Dict, List, Optional
from sqlalchemy.exc import SQLAlchemyError
from backend.database import Item, StyleSummary, get_session
import openpyxl
from PIL import Image
import io
from pathlib import Path


class InventoryParser:
    def __init__(self, file_path: str):
        """Initialize the parser with an Excel file path."""
        self.file_path = file_path
        self.df = None
        self.styles_data = {}
        self._load_data()
    
    def _load_data(self):
        """Load and process the Excel file."""
        try:
            self.df = pd.read_excel(self.file_path)
            self.df.columns = self.df.columns.str.strip().str.lower()
            self._process_styles()
        except FileNotFoundError:
            raise FileNotFoundError(f"Excel file not found: {self.file_path}")
        except Exception as e:
            raise Exception(f"Error loading Excel file: {str(e)}")
    
    def _process_styles(self):
        """Group data by style and extract relevant information."""
        required_columns = ['style', 'color']
        
        for col in required_columns:
            if col not in self.df.columns:
                raise ValueError(f"Required column '{col}' not found in Excel file. Available columns: {list(self.df.columns)}")
        
        if 'division' not in self.df.columns:
            self.df['division'] = 'N/A'
        if 'outsole' not in self.df.columns:
            self.df['outsole'] = 'N/A'
        if 'gender' not in self.df.columns:
            self.df['gender'] = 'N/A'
        
        self.df['base_style'] = self.df['style'].astype(str).apply(self._extract_base_style)
        self.df['variant'] = self.df['style'].astype(str).apply(self._extract_variant)
        
        grouped = self.df.groupby('base_style')
        
        for base_style, group in grouped:
            color_list = []
            for _, row in group.iterrows():
                color = str(row['color'])
                variant = row['variant']
                if variant:
                    color_list.append(f"{color} ({variant})")
                else:
                    color_list.append(color)
            
            color_list = list(dict.fromkeys(color_list))
            
            self.styles_data[str(base_style)] = {
                'style': str(base_style),
                'colors': color_list,
                'division': str(group['division'].iloc[0]) if pd.notna(group['division'].iloc[0]) else 'N/A',
                'outsole': str(group['outsole'].iloc[0]) if pd.notna(group['outsole'].iloc[0]) else 'N/A',
                'gender': str(group['gender'].iloc[0]) if pd.notna(group['gender'].iloc[0]) else 'N/A',
                'color_count': len(color_list)
            }
    
    def _extract_base_style(self, style: str) -> str:
        """Extract base style number by removing w/ww suffix."""
        match = re.match(r'^(\d+)', str(style))
        return match.group(1) if match else str(style)
    
    def _extract_variant(self, style: str) -> str:
        """Extract variant suffix (w or ww) if present."""
        style_str = str(style).lower()
        if style_str.endswith('ww'):
            return 'ww'
        elif style_str.endswith('w'):
            return 'w'
        return ''
    
    def lookup(self, style: str) -> Optional[Dict]:
        """
        Lookup style information.
        
        Args:
            style: Style number to lookup
            
        Returns:
            Dictionary with style information or None if not found
        """
        style_str = str(style)
        if style_str not in self.styles_data:
            return None
        return self.styles_data[style_str]
    
    def print_style_info(self, style: str):
        """
        Print formatted style information.
        
        Args:
            style: Style number to print
        """
        info = self.lookup(style)
        
        if info is None:
            print(f"\nStyle {style} not found in data")
            return
        
        print("\n" + "=" * 50)
        print(f"Style: {info['style']}")
        print("=" * 50)
        print(f"Division:   {info['division']}")
        print(f"Outsole:    {info['outsole']}")
        print(f"Gender:     {info['gender']}")
        print(f"Colors:     {', '.join(info['colors'])}")
        print(f"Color Count: {info['color_count']}")
        print("=" * 50)
    
    def get_all_styles(self) -> List[str]:
        """Return list of all style numbers."""
        return list(self.styles_data.keys())
    
    def get_style_count(self) -> int:
        """Return count of unique styles."""
        return len(self.styles_data)

    def extract_images_to_folder(self, output_dir: str = "static/images") -> Dict:
        """
        Extract images from Excel file and save them with correct style_color naming.
        This ensures each image matches its corresponding row data.

        Args:
            output_dir: Directory to save images (default: static/images)

        Returns:
            Dictionary with extraction statistics
        """
        Path(output_dir).mkdir(parents=True, exist_ok=True)

        try:
            # Load workbook to extract images
            wb = openpyxl.load_workbook(self.file_path)
            sheet = wb.active

            # Get all images and their positions
            images_by_row = {}
            for img in sheet._images:
                # Get the row where this image is anchored
                if hasattr(img, 'anchor') and hasattr(img.anchor, '_from'):
                    row_idx = img.anchor._from.row  # 0-based in openpyxl
                    if row_idx not in images_by_row:
                        images_by_row[row_idx] = []
                    images_by_row[row_idx].append(img)

            print(f"Found {len(images_by_row)} rows with images")

            extracted_count = 0
            skipped_count = 0

            for excel_row_idx, images in sorted(images_by_row.items()):
                # Excel rows: header is row 1, data starts at row 2
                # df index: header consumed, data starts at index 0
                df_row_idx = excel_row_idx - 1

                if df_row_idx < 0 or df_row_idx >= len(self.df):
                    skipped_count += 1
                    continue

                # Get the data for this row
                row_data = self.df.iloc[df_row_idx]

                # Extract style and color
                style_raw = str(row_data.get('style', '')).strip()
                color_raw = str(row_data.get('color', '')).strip()

                if not style_raw or not color_raw or style_raw == 'nan' or color_raw == 'nan':
                    skipped_count += 1
                    continue

                # Clean up style (extract base digits, pad to 6)
                style_match = re.match(r'^(\d+)', style_raw)
                if style_match:
                    style_clean = style_match.group(1).zfill(6)
                else:
                    skipped_count += 1
                    continue

                # Extract variant from style and add to color
                variant = self._extract_variant(style_raw)
                if variant:
                    color_clean = f"{color_raw} ({variant})"
                else:
                    color_clean = color_raw.strip()

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

                        print(f"Extracted: {filename} (from row {excel_row_idx})")
                        extracted_count += 1

                    except Exception as e:
                        print(f"✗ Error extracting image from row {excel_row_idx}: {e}")
                        skipped_count += 1

            wb.close()

            return {
                'extracted': extracted_count,
                'skipped': skipped_count,
                'output_dir': output_dir
            }

        except Exception as e:
            print(f"Error extracting images: {e}")
            return {
                'extracted': 0,
                'skipped': 0,
                'error': str(e)
            }
    
    def save_to_database(self, source_filename: str) -> Dict:
        """
        Save parsed inventory data to database.
        
        Args:
            source_filename: Name of the source Excel file
            
        Returns:
            Dictionary with save statistics
        """
        session = get_session()
        items_saved = 0
        styles_processed = 0
        
        try:
            for base_style, style_data in self.styles_data.items():
                base_style_6digit = base_style.zfill(6)
                
                style_rows = self.df[self.df['base_style'] == base_style]
                
                processed_colors = set()
                for _, row in style_rows.iterrows():
                    color = str(row['color'])
                    variant = row['variant']
                    color_with_variant = f"{color} ({variant})" if variant else color
                    
                    if color_with_variant in processed_colors:
                        continue
                    processed_colors.add(color_with_variant)
                    
                    image_url = None
                    if 'image' in self.df.columns and 'image' in row.index and pd.notna(row['image']):
                        image_url = str(row['image'])
                    elif 'image_url' in self.df.columns and 'image_url' in row.index and pd.notna(row['image_url']):
                        image_url = str(row['image_url'])
                    
                    # Generate ID as style_color
                    item_id = f"{base_style_6digit}_{color_with_variant}"
                    
                    existing_item = session.query(Item).filter_by(id=item_id).first()
                    
                    if existing_item:
                        existing_item.division = str(row['division'])
                        existing_item.outsole = str(row['outsole'])
                        existing_item.gender = str(row['gender'])
                        if image_url:
                            existing_item.image_url = image_url
                        
                        existing_files = set(existing_item.source_files)
                        existing_files.add(source_filename)
                        existing_item.source_files = sorted(list(existing_files))
                        
                        from datetime import datetime
                        existing_item.updated_at = datetime.utcnow()
                    else:
                        new_item = Item(
                            id=item_id,
                            style=base_style_6digit,
                            color=color_with_variant,
                            division=str(row['division']),
                            outsole=str(row['outsole']),
                            gender=str(row['gender']),
                            image_url=image_url,
                            source_files=[source_filename]
                        )
                        session.add(new_item)
                    
                    items_saved += 1
                
                existing_summary = session.query(StyleSummary).filter_by(
                    style=base_style_6digit
                ).first()
                
                if existing_summary:
                    existing_colors = set(existing_summary.all_colors)
                    new_colors = set(style_data['colors'])
                    merged_colors = sorted(list(existing_colors | new_colors))
                    
                    existing_files = set(existing_summary.source_files)
                    existing_files.add(source_filename)
                    
                    existing_summary.all_colors = merged_colors
                    existing_summary.source_files = sorted(list(existing_files))
                    existing_summary.color_count = len(merged_colors)
                    from datetime import datetime
                    existing_summary.updated_at = datetime.utcnow()
                else:
                    new_summary = StyleSummary(
                        style=base_style_6digit,
                        all_colors=style_data['colors'],
                        division=style_data['division'],
                        outsole=style_data['outsole'],
                        gender=style_data['gender'],
                        source_files=[source_filename],
                        color_count=style_data['color_count']
                    )
                    session.add(new_summary)
                
                styles_processed += 1
            
            session.commit()
            
            return {
                'items_saved': items_saved,
                'styles_processed': styles_processed,
                'source_file': source_filename
            }
            
        except SQLAlchemyError as e:
            session.rollback()
            raise Exception(f"Database error: {str(e)}")
        finally:
            session.close()


def main():
    """Interactive terminal interface for the inventory parser."""
    print("\n" + "=" * 50)
    print("  SKECHERS INVENTORY LOOKUP SYSTEM")
    print("=" * 50)
    
    file_path = input("\nEnter Excel file path: ").strip()
    
    try:
        parser = InventoryParser(file_path)
        print(f"\nLoaded {parser.get_style_count()} unique styles")
    except Exception as e:
        print(f"\nError: {str(e)}")
        return
    
    while True:
        print("\n" + "=" * 50)
        print("[1] Lookup style")
        print("[2] List all styles")
        print("[3] Extract images (FIXES IMAGE MISMATCH)")
        print("[4] Save to database")
        print("[5] Exit")
        print("=" * 50)

        choice = input("\nChoice: ").strip()
        
        if choice == "1":
            style = input("Enter style: ").strip()
            parser.print_style_info(style)
        
        elif choice == "2":
            styles = parser.get_all_styles()
            print(f"\n{'=' * 50}")
            print(f"First 30 styles (Total: {len(styles)})")
            print("=" * 50)
            for i, style in enumerate(styles[:30], 1):
                print(f"{i:2d}. {style}")
            if len(styles) > 30:
                print(f"\n... and {len(styles) - 30} more styles")
            print("=" * 50)

        elif choice == "3":
            print(f"\nExtracting images from Excel file...")
            print("This will backup existing images and extract fresh ones")

            # Backup existing images
            import shutil
            from datetime import datetime
            backup_dir = f"static/images_backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
            if os.path.exists("static/images"):
                print(f"Backing up existing images to {backup_dir}...")
                shutil.copytree("static/images", backup_dir)
                print("Backup complete")

            try:
                result = parser.extract_images_to_folder("static/images")
                if 'error' in result:
                    print(f"\nImage extraction failed: {result['error']}")
                else:
                    print(f"\nImage extraction complete!")
                    print(f"   Extracted: {result['extracted']} images")
                    print(f"   Skipped: {result['skipped']} images")
                    print(f"   Saved to: {result['output_dir']}")
                    print(f"\n   Original images backed up to: {backup_dir}")
            except Exception as e:
                print(f"\nImage extraction failed: {str(e)}")

        elif choice == "4":
            source_filename = os.path.basename(file_path)
            print(f"\nSaving to database...")
            try:
                result = parser.save_to_database(source_filename)
                print(f"\nDatabase save successful!")
                print(f"   Items saved: {result['items_saved']}")
                print(f"   Styles processed: {result['styles_processed']}")
                print(f"   Source file: {result['source_file']}")
            except Exception as e:
                print(f"\nDatabase save failed: {str(e)}")

        elif choice == "5":
            print("\nGoodbye!")
            break
        
        else:
            print("\nInvalid choice. Please select 1, 2, 3, 4, or 5.")


if __name__ == "__main__":
    main()
