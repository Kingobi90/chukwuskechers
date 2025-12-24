# Adding Shoe Images to the System

## How Images Work

The system displays shoe images in the search results and inventory views. Images are stored as URLs in the database and loaded from the Excel files during upload.

## Adding Images to Your Excel Files

### Option 1: Add an 'image' or 'image_url' Column

1. Open your Excel file (e.g., `wof10.29.2025.xlsx`)
2. Add a new column named either:
   - `image` 
   - `image_url`
3. In this column, add the full URL to each shoe image
4. Save the file and re-upload it through the UI

**Example Excel structure:**
```
| style  | color | division        | outsole | gender | image                                    |
|--------|-------|-----------------|---------|--------|------------------------------------------|
| 100702 | BBK   | MODERN COMFORT  | TPR     | WOMENS | https://example.com/images/100702-BBK.jpg|
| 100702 | CCL   | MODERN COMFORT  | TPR     | WOMENS | https://example.com/images/100702-CCL.jpg|
```

### Option 2: Update Existing Items via Database

If you already have items in the database, you can update them directly:

```sql
UPDATE items 
SET image_url = 'https://example.com/images/100702-BBK.jpg' 
WHERE style = '100702' AND color = 'BBK';
```

## Image Display Features

### In Search Results (Search & Place Items tab)
- Images appear on the left side of each item card
- 150px width, auto height
- Falls back to "No Image" placeholder if URL is invalid

### In Inventory View (View Inventory tab)
- Same image display as search results
- Shows alongside all item details and location information

### Placeholder Behavior
- If `image_url` is NULL or empty: No image shown, full width for text
- If `image_url` exists but fails to load: Shows gray "No Image" placeholder

## Image URL Requirements

- Must be a valid HTTP/HTTPS URL
- Should be publicly accessible (not behind authentication)
- Recommended formats: JPG, PNG, WebP
- Recommended size: 300-500px width for best quality

## Testing

1. Upload an Excel file with image URLs
2. Go to **Search & Place Items** tab
3. Search for a style that has an image URL
4. The image should appear on the left side of the item card

## Troubleshooting

**Images not showing?**
- Check if the Excel file has an 'image' or 'image_url' column
- Verify the URLs are publicly accessible
- Check browser console for CORS or loading errors
- Ensure URLs use HTTPS (not HTTP) if your site uses HTTPS

**Images showing "No Image" placeholder?**
- The URL might be broken or inaccessible
- Check the URL in a browser to verify it works
- Ensure there are no typos in the URL

## Re-uploading Files with Images

If you want to add images to existing items:

1. Delete the old file from the **Upload Excel** tab
2. Update your Excel file with the image URLs
3. Re-upload the file
4. The system will update existing items with the new image URLs
