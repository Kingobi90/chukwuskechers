#!/usr/bin/env python3
"""
Migration script to convert Item table from integer ID to style_color composite ID.
This will backup the old database and create a new one with the updated schema.
"""

import sqlite3
import os
from datetime import datetime

def migrate_database():
    """Migrate the database to use style_color as primary key."""
    
    db_path = "chukwu_inventory.db"
    backup_path = f"chukwu_inventory_backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}.db"
    
    print("=" * 80)
    print("DATABASE MIGRATION: Integer ID -> Style_Color Composite ID")
    print("=" * 80)
    
    # Create backup
    print(f"\n1. Creating backup: {backup_path}")
    os.system(f"cp {db_path} {backup_path}")
    print(f"   Backup created")
    
    # Connect to database
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Check if migration is needed
    cursor.execute("PRAGMA table_info(items)")
    columns = cursor.fetchall()
    id_column = [col for col in columns if col[1] == 'id'][0]
    
    if id_column[2] == 'VARCHAR(120)' or id_column[2] == 'TEXT':
        print("\n   Database already migrated (ID is already string type)")
        conn.close()
        return
    
    print("\n2. Reading existing data...")
    cursor.execute("SELECT * FROM items")
    old_items = cursor.fetchall()
    
    # Get column names
    cursor.execute("PRAGMA table_info(items)")
    columns_info = cursor.fetchall()
    column_names = [col[1] for col in columns_info]
    
    print(f"   Found {len(old_items)} items to migrate")
    
    # Create new table with updated schema
    print("\n3. Creating new table schema...")
    cursor.execute("""
        CREATE TABLE items_new (
            id VARCHAR(120) PRIMARY KEY,
            style VARCHAR(10) NOT NULL,
            color VARCHAR(100) NOT NULL,
            division VARCHAR(100),
            outsole VARCHAR(100),
            gender VARCHAR(50),
            image_url VARCHAR(500),
            source_files JSON NOT NULL,
            status VARCHAR(50) DEFAULT 'pending',
            row_id INTEGER,
            created_at DATETIME,
            updated_at DATETIME,
            FOREIGN KEY (row_id) REFERENCES rows(id)
        )
    """)
    print("   New table created")
    
    # Migrate data
    print("\n4. Migrating data with new IDs...")
    migrated = 0
    skipped = 0
    
    for item in old_items:
        item_dict = dict(zip(column_names, item))
        
        # Generate new ID as style_color
        new_id = f"{item_dict['style']}_{item_dict['color']}"
        
        try:
            cursor.execute("""
                INSERT INTO items_new (
                    id, style, color, division, outsole, gender, 
                    image_url, source_files, status, row_id, 
                    created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                new_id,
                item_dict['style'],
                item_dict['color'],
                item_dict['division'],
                item_dict['outsole'],
                item_dict['gender'],
                item_dict['image_url'],
                item_dict['source_files'],
                item_dict['status'],
                item_dict['row_id'],
                item_dict['created_at'],
                item_dict['updated_at']
            ))
            migrated += 1
        except sqlite3.IntegrityError as e:
            print(f"   Skipped duplicate: {new_id} (old ID: {item_dict['id']})")
            skipped += 1
    
    print(f"   Migrated {migrated} items")
    if skipped > 0:
        print(f"   Skipped {skipped} duplicate items")
    
    # Drop old table and rename new one
    print("\n5. Replacing old table...")
    cursor.execute("DROP TABLE items")
    cursor.execute("ALTER TABLE items_new RENAME TO items")
    print("   Table replaced")
    
    # Create indexes
    print("\n6. Creating indexes...")
    cursor.execute("CREATE INDEX idx_style ON items(style)")
    print("   Indexes created")
    
    # Commit changes
    conn.commit()
    conn.close()
    
    print("\n" + "=" * 80)
    print("MIGRATION COMPLETED SUCCESSFULLY")
    print("=" * 80)
    print(f"\nBackup saved to: {backup_path}")
    print(f"Items migrated: {migrated}")
    print(f"New ID format: style_color (e.g., '100702_BBK')")
    print("\nYou can now restart the server to use the new schema.")

if __name__ == "__main__":
    try:
        migrate_database()
    except Exception as e:
        print(f"\n✗ Migration failed: {e}")
        print("\nThe backup file has been preserved. You can restore it if needed.")
        raise
