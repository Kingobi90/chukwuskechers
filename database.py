import os
from datetime import datetime
from sqlalchemy import create_engine, Column, Integer, String, DateTime, JSON, Index, UniqueConstraint, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.orm import declarative_base, sessionmaker
from dotenv import load_dotenv

load_dotenv()

Base = declarative_base()


class Room(Base):
    """Warehouse rooms for organizing inventory."""
    __tablename__ = 'rooms'
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(100), unique=True, nullable=False)
    description = Column(String(500))
    created_at = Column(DateTime, default=datetime.utcnow)
    
    shelves = relationship('Shelf', back_populates='room', cascade='all, delete-orphan')
    
    def __repr__(self):
        return f"<Room(name={self.name})>"


class Shelf(Base):
    """Shelves within rooms."""
    __tablename__ = 'shelves'
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    room_id = Column(Integer, ForeignKey('rooms.id'), nullable=False)
    name = Column(String(100), nullable=False)
    description = Column(String(500))
    created_at = Column(DateTime, default=datetime.utcnow)
    
    room = relationship('Room', back_populates='shelves')
    rows = relationship('Row', back_populates='shelf', cascade='all, delete-orphan')
    
    __table_args__ = (
        UniqueConstraint('room_id', 'name', name='uix_room_shelf'),
    )
    
    def __repr__(self):
        return f"<Shelf(room={self.room.name if self.room else None}, name={self.name})>"


class Row(Base):
    """Rows within shelves."""
    __tablename__ = 'rows'
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    shelf_id = Column(Integer, ForeignKey('shelves.id'), nullable=False)
    name = Column(String(100), nullable=False)
    description = Column(String(500))
    created_at = Column(DateTime, default=datetime.utcnow)
    
    shelf = relationship('Shelf', back_populates='rows')
    items = relationship('Item', back_populates='row')
    
    __table_args__ = (
        UniqueConstraint('shelf_id', 'name', name='uix_shelf_row'),
    )
    
    def __repr__(self):
        return f"<Row(shelf={self.shelf.name if self.shelf else None}, name={self.name})>"


class Item(Base):
    """Detailed table storing each color variant as a separate row."""
    __tablename__ = 'items'
    
    id = Column(String(120), primary_key=True)  # Format: {style}_{color}
    style = Column(String(10), nullable=False, index=True)  # Support 5-6 digit styles
    color = Column(String(100), nullable=False)  # Includes (w) and (ww) suffixes
    division = Column(String(100))
    outsole = Column(String(100))
    gender = Column(String(50))
    image_url = Column(String(500), nullable=True)
    source_files = Column(JSON, nullable=False)  # Array of Excel filenames
    status = Column(String(50), default='pending')  # pending, placed, showroom, waitlist, dropped
    row_id = Column(Integer, ForeignKey('rows.id'), nullable=True)  # Location in warehouse
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    row = relationship('Row', back_populates='items')
    
    __table_args__ = (
        Index('idx_style', 'style'),
        Index('idx_source_files', 'source_files', postgresql_using='gin'),  # For JSON queries
    )
    
    def __repr__(self):
        return f"<Item(id={self.id}, style={self.style}, color={self.color})>"


class StyleSummary(Base):
    """Summary table with one row per style number, aggregating all color variants."""
    __tablename__ = 'style_summary'
    
    style = Column(String(10), primary_key=True)  # Support 5-6 digit styles
    all_colors = Column(JSON, nullable=False)  # List of all color variants including widths
    division = Column(String(100))
    outsole = Column(String(100))
    gender = Column(String(50))
    source_files = Column(JSON, nullable=False)  # Array of Excel filenames
    color_count = Column(Integer, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def __repr__(self):
        return f"<StyleSummary(style={self.style}, colors={self.color_count})>"


class InventoryAction(Base):
    """Track actions taken on inventory items."""
    __tablename__ = 'inventory_actions'
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    item_id = Column(Integer, ForeignKey('items.id'), nullable=False)
    style = Column(String(10), nullable=False, index=True)
    color = Column(String(100), nullable=False)
    action = Column(String(50), nullable=False)  # placed, showroom, waitlist, dropped
    location = Column(String(200))
    notes = Column(String(500))
    user = Column(String(100), nullable=False)
    source_file = Column(String(200))  # Which Excel file this relates to
    timestamp = Column(DateTime, default=datetime.utcnow, index=True)
    
    def __repr__(self):
        return f"<InventoryAction(style={self.style}, color={self.color}, action={self.action})>"


class FileUpload(Base):
    """Track uploaded Excel files."""
    __tablename__ = 'file_uploads'
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    filename = Column(String(200), unique=True, nullable=False)
    uploaded_at = Column(DateTime, default=datetime.utcnow, index=True)
    styles_count = Column(Integer, default=0)
    items_count = Column(Integer, default=0)
    images_uploaded = Column(Integer, default=0)
    status = Column(String(50), default='processing')  # processing, completed, failed
    
    def __repr__(self):
        return f"<FileUpload(filename={self.filename}, status={self.status})>"


def get_engine():
    """Get database engine based on DATABASE_URL environment variable."""
    database_url = os.getenv('DATABASE_URL', 'sqlite:///chukwu_inventory.db')
    
    if database_url.startswith('postgres://'):
        database_url = database_url.replace('postgres://', 'postgresql://', 1)
    
    return create_engine(database_url, echo=False)


def get_session():
    """Create and return a new database session."""
    engine = get_engine()
    Session = sessionmaker(bind=engine)
    return Session()


def create_all():
    """Initialize all database tables."""
    engine = get_engine()
    Base.metadata.create_all(engine)
    print(f"Database tables created successfully")
    return engine


def get_db():
    """Dependency for FastAPI to get database session."""
    db = get_session()
    try:
        yield db
    finally:
        db.close()


if __name__ == "__main__":
    create_all()
    print("\nTables created:")
    print("  - rooms (warehouse rooms)")
    print("  - shelves (shelves within rooms)")
    print("  - rows (rows within shelves)")
    print("  - items (detailed color variants with location)")
    print("  - style_summary (aggregated style data)")
    print("  - inventory_actions (action tracking)")
    print("  - file_uploads (file tracking)")
