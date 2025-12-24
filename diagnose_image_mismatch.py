"""
Diagnostic tool to check if images match their filenames.
Creates an HTML report showing all images with their filenames.
"""
import os
from pathlib import Path


def create_image_diagnostic_report(images_dir="static/images", output_file="image_diagnostic.html"):
    """Create an HTML report showing all images with their filenames."""

    # Get all JPG files
    image_files = sorted([f for f in os.listdir(images_dir) if f.endswith('.jpg')])

    html_content = """
<!DOCTYPE html>
<html>
<head>
    <title>Image Diagnostic Report</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 20px;
            background: #f5f5f5;
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            padding: 20px;
            border-radius: 10px;
        }
        h1 {
            color: #333;
            border-bottom: 3px solid #667eea;
            padding-bottom: 10px;
        }
        .image-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
            gap: 20px;
            margin-top: 20px;
        }
        .image-card {
            border: 2px solid #ddd;
            border-radius: 8px;
            padding: 15px;
            background: #fafafa;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        .image-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 5px 15px rgba(0,0,0,0.2);
        }
        .image-card img {
            width: 100%;
            height: auto;
            border-radius: 5px;
            background: white;
            border: 1px solid #ddd;
        }
        .filename {
            margin-top: 10px;
            font-weight: bold;
            color: #667eea;
            word-break: break-all;
        }
        .style-color {
            margin-top: 5px;
            font-size: 0.9em;
            color: #666;
        }
        .warning {
            background: #fff3cd;
            border: 2px solid #ffc107;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        .stats {
            background: #e7f3ff;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Image Diagnostic Report</h1>

        <div class="warning">
            <strong>Important:</strong> Review each image to ensure it matches the style and color in the filename.
            If the shoe in the image doesn't match the filename, the image file needs to be corrected.
        </div>

        <div class="stats">
            <strong>Total Images:</strong> """ + str(len(image_files)) + """<br>
            <strong>Location:</strong> """ + images_dir + """
        </div>

        <div class="image-grid">
"""

    for filename in image_files:
        # Parse filename
        parts = filename.replace('.jpg', '').split('_')
        if len(parts) == 2:
            style, color = parts
        else:
            style, color = filename, "UNKNOWN"

        html_content += f"""
            <div class="image-card">
                <img src="/static/images/{filename}" alt="{filename}" onerror="this.src='data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 width=%22200%22 height=%22200%22%3E%3Crect fill=%22%23f8f9fa%22 width=%22200%22 height=%22200%22/%3E%3Ctext x=%2250%25%22 y=%2250%25%22 dominant-baseline=%22middle%22 text-anchor=%22middle%22 font-family=%22Arial%22 font-size=%2214%22 fill=%22%236c757d%22%3EError Loading%3C/text%3E%3C/svg%3E'">
                <div class="filename">{filename}</div>
                <div class="style-color">
                    Style: {style}<br>
                    Color: {color}
                </div>
            </div>
"""

    html_content += """
        </div>
    </div>
</body>
</html>
"""

    # Write HTML file
    with open(output_file, 'w') as f:
        f.write(html_content)

    print(f"Diagnostic report created: {output_file}")
    print(f"   Open this file in a web browser to review all images")
    print(f"   Total images: {len(image_files)}")
    print(f"\n   To view: open {output_file}")


if __name__ == "__main__":
    print("=" * 60)
    print("  IMAGE DIAGNOSTIC TOOL")
    print("=" * 60)
    print()
    create_image_diagnostic_report()
