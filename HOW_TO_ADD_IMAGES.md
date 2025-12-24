# How to Add Images to Your Inventory

## Current Status
- **Total items in database:** 5,696
- **Items with images:** 0
- **Images will show in UI once you add image URLs to your Excel files**

## How the System Works

The system automatically matches images to the correct items based on the **style and color** in your Excel file. When you add an `image` or `image_url` column to your Excel file, the parser extracts the URL and stores it with the matching item.

## Step-by-Step Instructions

### 1. Add Image Column to Your Excel File

Open your Excel file (e.g., `wof10.29.2025.xlsx`) and add a column named either:
- `image` OR
- `image_url`

### 2. Add Image URLs for Each Row

In this column, add the full URL to the image for each shoe. The URL should point to the actual shoe image online.

**Example Excel Structure:**

```
| style  | color    | division        | outsole      | gender | image                                                    |
|--------|----------|-----------------|--------------|--------|----------------------------------------------------------|
| 100702 | BBK      | MODERN COMFORT  | GRACEFUL     | WOMENS | https://images.skechers.com/img/productimages/xlarge/100702_BBK.jpg |
| 100702 | CCL      | MODERN COMFORT  | GRACEFUL     | WOMENS | https://images.skechers.com/img/productimages/xlarge/100702_CCL.jpg |
| 100702 | TPE      | MODERN COMFORT  | GRACEFUL     | WOMENS | https://images.skechers.com/img/productimages/xlarge/100702_TPE.jpg |
| 100762 | WHT      | MODERN COMFORT  | BREATHE-EASY | WOMENS | https://images.skechers.com/img/productimages/xlarge/100762_WHT.jpg |
| 100615 | BBK      | MODERN COMFORT  | BREATHE-EASY | WOMENS | https://images.skechers.com/img/productimages/xlarge/100615_BBK.jpg |
```

### 3. Upload the Excel File

1. Go to http://localhost:8001/static/warehouse.html
2. Click on **Upload Excel** tab
3. Upload your Excel file with the new `image` column
4. The system will automatically:
   - Extract the image URL from each row
   - Match it to the item with that **exact style and color**
   - Store it in the database

### 4. View Images in UI

After uploading, images will automatically appear in:

**Search & Place Items Tab:**
- Search for any style (e.g., "100702")
- Images appear on the left side of each result
- Shows the correct image for each color variant

**View Inventory Tab:**
- Filter by status (pending, placed, etc.)
- Images display with full item details
- Shows location if item is placed

## How Matching Works

The system ensures images match correctly:

1. **Excel Row:** Style `100702`, Color `BBK`, Image URL `https://...100702_BBK.jpg`
2. **Database:** Creates/updates item with ID `100702_BBK`
3. **Stores:** Image URL with that specific item
4. **UI Displays:** When you search for style `100702`, it shows the BBK image only for the BBK color variant

**Each color variant gets its own image URL** - no random matching!

## Example Image URL Formats

If your images follow a pattern, you can use formulas in Excel:

**Pattern 1: Skechers-style URLs**
```
https://images.skechers.com/img/productimages/xlarge/{style}_{color}.jpg
```

**Pattern 2: Your own server**
```
https://yourserver.com/images/{style}/{color}.jpg
```

**Pattern 3: Cloud storage**
```
https://storage.googleapis.com/your-bucket/shoes/{style}_{color}.png
```

## Testing

After uploading your Excel file with image URLs:

1. **Check Database:**
   ```bash
   sqlite3 chukwu_inventory.db "SELECT id, style, color, image_url FROM items WHERE image_url IS NOT NULL LIMIT 5;"
   ```

2. **Test in UI:**
   - Go to **Search & Place Items**
   - Search for a style you added images for
   - Images should display on the left side

3. **Verify Matching:**
   - Each color variant should show its own unique image
   - Style `100702` color `BBK` shows black shoe
   - Style `100702` color `WHT` shows white shoe
   - No random or mismatched images

## Important Notes

- **Image URLs must be publicly accessible** (not behind login/authentication)
- **HTTPS URLs recommended** for security
- **Images load from the URLs** you provide (not stored locally on server)
- **Re-uploading a file** will update image URLs for existing items
- **Each row in Excel** = One item with one image URL

## Need Help?

If images aren't showing:
1. Check browser console (F12) for errors
2. Verify URLs are accessible in a browser
3. Ensure Excel column is named `image` or `image_url`
4. Check that URLs match the correct style/color combinations
