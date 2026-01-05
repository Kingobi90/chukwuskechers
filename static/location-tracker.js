// Global variable to store warehouse data for location tracking
let warehouseData = [];

function updateLocationDisplay(rooms) {
    if (!rooms || rooms.length === 0) return;
    
    warehouseData = rooms;
    const roomIndex = 0;
    const shelfIndex = 0;
    const rowIndex = 0;
    
    updateLocationText(roomIndex, shelfIndex, rowIndex);
}

function updateLocationText(roomIndex, shelfIndex, rowIndex) {
    if (!warehouseData || warehouseData.length === 0) return;
    
    const room = warehouseData[roomIndex];
    if (!room) return;
    
    const shelf = room.shelves && room.shelves[shelfIndex];
    const row = shelf && shelf.rows && shelf.rows[rowIndex];
    
    const locationDisplay = document.getElementById('current-location-display');
    const sublocationDisplay = document.getElementById('current-sublocation-display');
    
    if (locationDisplay) {
        locationDisplay.textContent = room.name;
    }
    
    if (sublocationDisplay) {
        if (shelf && row) {
            const itemCount = row.items ? row.items.length : 0;
            sublocationDisplay.textContent = `${shelf.name} → ${row.name} (${itemCount} items)`;
        } else if (shelf) {
            sublocationDisplay.textContent = `${shelf.name}`;
        } else {
            sublocationDisplay.textContent = 'No shelves';
        }
    }
}

// Override navigation functions to update location display
const originalNavigateRoom = window.navigateRoom;
window.navigateRoom = function(direction) {
    if (originalNavigateRoom) originalNavigateRoom(direction);
    
    const track = document.getElementById('room-track');
    if (!track) return;
    
    const currentIndex = parseInt(track.dataset.current);
    updateLocationText(currentIndex, 0, 0);
};

const originalNavigateShelf = window.navigateShelf;
window.navigateShelf = function(roomId, direction) {
    if (originalNavigateShelf) originalNavigateShelf(roomId, direction);
    
    const roomTrack = document.getElementById('room-track');
    const shelfTrack = document.getElementById(`shelf-track-${roomId}`);
    
    if (!roomTrack || !shelfTrack) return;
    
    const roomIndex = parseInt(roomTrack.dataset.current);
    const shelfIndex = parseInt(shelfTrack.dataset.current);
    
    updateLocationText(roomIndex, shelfIndex, 0);
};

const originalNavigateRow = window.navigateRow;
window.navigateRow = function(roomId, shelfId, direction) {
    if (originalNavigateRow) originalNavigateRow(roomId, shelfId, direction);
    
    const roomTrack = document.getElementById('room-track');
    const shelfTrack = document.getElementById(`shelf-track-${roomId}`);
    const rowTrack = document.getElementById(`row-track-${roomId}-${shelfId}`);
    
    if (!roomTrack || !shelfTrack || !rowTrack) return;
    
    const roomIndex = parseInt(roomTrack.dataset.current);
    const shelfIndex = parseInt(shelfTrack.dataset.current);
    const rowIndex = parseInt(rowTrack.dataset.current);
    
    updateLocationText(roomIndex, shelfIndex, rowIndex);
};
