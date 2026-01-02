const API_BASE = '';
let visualShelvesRefreshInterval = null;

function toggleSidebar() {
    document.getElementById('sidebar').classList.toggle('active');
}

function switchTab(tabName) {
    // Stop auto-refresh when leaving visual-shelves tab
    if (tabName !== 'visual-shelves') {
        stopVisualShelvesAutoRefresh();
    }

    document.querySelectorAll('.nav-item').forEach(item => item.classList.remove('active'));
    event.target.classList.add('active');
    document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
    document.getElementById(`${tabName}-tab`).classList.add('active');

    const titles = {
        'upload': 'Upload Excel', 'seasonal': 'Seasonal Drop', 'visual-shelves': 'Visual Shelves',
        'locations': 'Manage Locations', 'search': 'Search & Place Items', 'inventory': 'View Inventory',
        'stats': 'Statistics', 'analytics': 'Analytics Dashboard'
    };
    document.getElementById('pageTitle').textContent = titles[tabName];

    if (window.innerWidth <= 768) document.getElementById('sidebar').classList.remove('active');

    if (tabName === 'locations') {
        loadLocations(); loadRoomsForSelects(); loadShelvesForSelects(); loadRowsForSelects();
    } else if (tabName === 'upload') loadUploadedFiles();
    else if (tabName === 'search') loadRowsForSelects();
    else if (tabName === 'inventory') loadInventory();
    else if (tabName === 'stats') loadStats();
    else if (tabName === 'analytics') loadAllAnalytics();
    else if (tabName === 'visual-shelves') {
        loadVisualShelves();
        startVisualShelvesAutoRefresh();
    }
}

function startVisualShelvesAutoRefresh() {
    stopVisualShelvesAutoRefresh(); // Clear any existing interval
    // Auto-refresh every 30 seconds
    visualShelvesRefreshInterval = setInterval(() => {
        loadVisualShelves();
    }, 30000);
}

function stopVisualShelvesAutoRefresh() {
    if (visualShelvesRefreshInterval) {
        clearInterval(visualShelvesRefreshInterval);
        visualShelvesRefreshInterval = null;
    }
}

function showAlert(elementId, message, type) {
    const alertDiv = document.getElementById(elementId);
    alertDiv.innerHTML = `<div class="alert alert-${type}">${message}</div>`;
    setTimeout(() => alertDiv.innerHTML = '', 5000);
}

async function uploadExcel() {
    const fileInput = document.getElementById('excel-file');
    const file = fileInput.files[0];
    if (!file) { showAlert('upload-alert', 'Please select a file', 'error'); return; }
    const formData = new FormData();
    formData.append('file', file);
    try {
        showAlert('upload-alert', 'Uploading and parsing...', 'info');
        const response = await fetch(`${API_BASE}/upload-excel?upload_images=true`, { method: 'POST', body: formData });
        const result = await response.json();
        if (response.ok) {
            showAlert('upload-alert', `Success! Processed ${result.styles_processed} styles, ${result.items_saved} items`, 'success');
            loadUploadedFiles(); fileInput.value = '';
        } else showAlert('upload-alert', `Error: ${result.detail}`, 'error');
    } catch (error) { showAlert('upload-alert', `Error: ${error.message}`, 'error'); }
}

async function loadUploadedFiles() {
    try {
        const response = await fetch(`${API_BASE}/inventory/files`);
        const files = await response.json();
        const filesList = document.getElementById('files-list');
        if (files.length === 0) {
            filesList.innerHTML = '<p style="color: #666; text-align: center; padding: 40px;">No files uploaded yet</p>';
            return;
        }
        filesList.innerHTML = files.map(f => `
            <div class="list-item">
                <div class="list-item-info">
                    <div class="list-item-title">${f.filename} <span class="badge badge-${f.status === 'completed' ? 'success' : 'info'}">${f.status}</span></div>
                    <div class="list-item-meta">Styles: ${f.styles_count} | Items: ${f.items_count} | ${new Date(f.uploaded_at).toLocaleString()}</div>
                </div>
                <div class="list-item-actions"><button class="btn btn-danger" onclick="deleteFile('${f.filename}')"><i data-lucide="trash-2" style="width: 16px; height: 16px;"></i> Delete</button></div>
            </div>
        `).join('');
        lucide.createIcons();
    } catch (error) { console.error('Error loading files:', error); }
}

async function deleteFile(filename) {
    if (!confirm(`Delete file "${filename}"? This cannot be undone.`)) return;
    try {
        const response = await fetch(`${API_BASE}/inventory/file/${encodeURIComponent(filename)}`, { method: 'DELETE' });
        if (response.ok) { const result = await response.json(); alert(`File deleted successfully!`); loadUploadedFiles(); }
        else { const error = await response.json(); alert(`Error: ${error.detail}`); }
    } catch (error) { alert(`Error: ${error.message}`); }
}

async function createRoom() {
    const name = document.getElementById('room-name').value;
    const description = document.getElementById('room-desc').value;
    if (!name) { alert('Please enter a room name'); return; }
    try {
        const response = await fetch(`${API_BASE}/locations/rooms`, {
            method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({name, description})
        });
        if (response.ok) {
            alert('Room created successfully!');
            document.getElementById('room-name').value = ''; document.getElementById('room-desc').value = '';
            loadLocations(); loadRoomsForSelects();
        } else { const error = await response.json(); alert(`Error: ${error.detail}`); }
    } catch (error) { alert(`Error: ${error.message}`); }
}

async function createShelf() {
    const roomId = document.getElementById('shelf-room-select').value;
    const name = document.getElementById('shelf-name').value;
    const description = document.getElementById('shelf-desc').value;
    if (!roomId || !name) { alert('Please select a room and enter a shelf name'); return; }
    try {
        const response = await fetch(`${API_BASE}/locations/shelves`, {
            method: 'POST', headers: {'Content-Type': 'application/json'}, 
            body: JSON.stringify({room_id: parseInt(roomId), name, description})
        });
        if (response.ok) {
            alert('Shelf created successfully!');
            document.getElementById('shelf-name').value = ''; document.getElementById('shelf-desc').value = '';
            loadLocations(); loadShelvesForSelects();
        } else { const error = await response.json(); alert(`Error: ${error.detail}`); }
    } catch (error) { alert(`Error: ${error.message}`); }
}

async function createRow() {
    const shelfId = document.getElementById('row-shelf-select').value;
    const name = document.getElementById('row-name').value;
    const description = document.getElementById('row-desc').value;
    if (!shelfId || !name) { alert('Please select a shelf and enter a row name'); return; }
    try {
        const response = await fetch(`${API_BASE}/locations/rows`, {
            method: 'POST', headers: {'Content-Type': 'application/json'}, 
            body: JSON.stringify({shelf_id: parseInt(shelfId), name, description})
        });
        if (response.ok) {
            alert('Row created successfully!');
            document.getElementById('row-name').value = ''; document.getElementById('row-desc').value = '';
            loadLocations(); loadRowsForSelects();
        } else { const error = await response.json(); alert(`Error: ${error.detail}`); }
    } catch (error) { alert(`Error: ${error.message}`); }
}

async function loadRoomsForSelects() {
    try {
        const response = await fetch(`${API_BASE}/locations/rooms`);
        const rooms = await response.json();
        const select = document.getElementById('shelf-room-select');
        select.innerHTML = '<option value="">Select a room</option>' + rooms.map(r => `<option value="${r.id}">${r.name}</option>`).join('');
    } catch (error) { console.error('Error loading rooms:', error); }
}

async function loadShelvesForSelects() {
    try {
        const response = await fetch(`${API_BASE}/locations/shelves`);
        const shelves = await response.json();
        const select = document.getElementById('row-shelf-select');
        select.innerHTML = '<option value="">Select a shelf</option>' + shelves.map(s => `<option value="${s.id}">${s.room_name} - ${s.name}</option>`).join('');
    } catch (error) { console.error('Error loading shelves:', error); }
}

async function loadRowsForSelects() {
    try {
        const response = await fetch(`${API_BASE}/locations/rows`);
        const rows = await response.json();
        const selects = ['assign-row-select'];
        selects.forEach(selectId => {
            const select = document.getElementById(selectId);
            if (select) select.innerHTML = '<option value="">Select a row</option>' + rows.map(r => `<option value="${r.id}">${r.room_name} > ${r.shelf_name} > ${r.name}</option>`).join('');
        });
    } catch (error) { console.error('Error loading rows:', error); }
}

async function loadLocations() {
    const treeDiv = document.getElementById('locations-tree');
    treeDiv.innerHTML = '<div class="loading"><div class="spinner"></div><p>Loading...</p></div>';
    try {
        const roomsResponse = await fetch(`${API_BASE}/locations/rooms`);
        const rooms = await roomsResponse.json();
        if (rooms.length === 0) {
            treeDiv.innerHTML = '<p style="color: #666; text-align: center; padding: 40px;">No locations yet.</p>';
            return;
        }
        let html = '';
        for (const room of rooms) {
            const shelvesResponse = await fetch(`${API_BASE}/locations/shelves?room_id=${room.id}`);
            const shelves = await shelvesResponse.json();
            html += `<div class="visual-room"><div class="visual-room-header"><i data-lucide="building" style="width: 20px; height: 20px; display: inline-block; vertical-align: middle; margin-right: 8px;"></i>${room.name}</div>`;
            for (const shelf of shelves) {
                const rowsResponse = await fetch(`${API_BASE}/locations/rows?shelf_id=${shelf.id}`);
                const rows = await rowsResponse.json();
                html += `<div class="visual-shelf"><div class="visual-shelf-header"><i data-lucide="layers" style="width: 18px; height: 18px; display: inline-block; vertical-align: middle; margin-right: 8px;"></i>${shelf.name}</div>`;
                for (const row of rows) html += `<div class="visual-row"><div class="visual-row-header"><span><i data-lucide="package" style="width: 16px; height: 16px; display: inline-block; vertical-align: middle; margin-right: 8px;"></i>${row.name}</span></div></div>`;
                html += '</div>';
            }
            html += '</div>';
        }
        treeDiv.innerHTML = html;
        lucide.createIcons();
    } catch (error) { console.error('Error loading locations:', error); }
}

async function searchItems() {
    const style = document.getElementById('search-style').value;
    const color = document.getElementById('search-color').value;
    if (!style && !color) { alert('Please enter at least one search criterion'); return; }
    try {
        let url = `${API_BASE}/inventory/search?`;
        if (style) url += `style=${encodeURIComponent(style)}&`;
        if (color) url += `color=${encodeURIComponent(color)}`;
        const response = await fetch(url);
        const items = await response.json();
        const resultsDiv = document.getElementById('search-results');
        if (items.length === 0) {
            resultsDiv.innerHTML = '<p style="color: #666; text-align: center; padding: 40px;">No items found.</p>';
            return;
        }
        resultsDiv.innerHTML = `<h4 style="margin: 24px 0 16px; font-weight: 600;">Found ${items.length} item(s)</h4><div class="items-grid">${items.map(item => `
            <div class="item-card" onclick="showItemProfile('${item.style}', '${item.color}')">
                ${item.image_url ? `<img src="${item.image_url}" class="item-image">` : '<div class="item-image" style="display: flex; align-items: center; justify-content: center; color: #999;">No Image</div>'}
                <div class="item-style">${item.style}</div><div class="item-color">${item.color}</div>
                <span class="badge badge-${item.status === 'placed' ? 'success' : 'info'}">${item.status}</span>
            </div>
        `).join('')}</div>`;
    } catch (error) { console.error('Error searching items:', error); }
}

function showItemProfile(style, color) {
    const modal = document.getElementById('item-profile-modal');
    modal.classList.add('active');
    document.getElementById('modal-title').textContent = `${style} - ${color}`;
    document.getElementById('modal-body').innerHTML = '<div class="loading"><div class="spinner"></div></div>';
}

function closeItemProfile() {
    document.getElementById('item-profile-modal').classList.remove('active');
}

async function loadInventory() { }
async function loadStats() { }
async function loadVisualShelves() { }
async function uploadSeasonalSheet() { }
async function viewDroppedReport() { }
async function exportDroppedReport() { }
async function scanBarcodeImage() { }
async function startCameraScanner() { }
async function stopCameraScanner() { }
async function scanTagImage() { }
async function loadColorsForStyle() { }
async function assignItemLocation() { }
async function unassignItemLocation() { }
async function loadAllAnalytics() { }

async function searchForManualDrop() {
    const style = document.getElementById('manual-drop-style').value.trim();
    if (!style) { alert('Please enter a style number'); return; }
    const resultsDiv = document.getElementById('manual-drop-results');
    resultsDiv.innerHTML = '<div class="loading"><div class="spinner"></div><p>Searching...</p></div>';
    try {
        const response = await fetch(`${API_BASE}/inventory/items?style=${encodeURIComponent(style)}`);
        const data = await response.json();
        if (data.items.length === 0) {
            resultsDiv.innerHTML = '<p style="color: #666; text-align: center; padding: 20px;">No items found for this style.</p>';
            return;
        }
        let html = '<div style="margin-top: 20px;"><h4 style="margin-bottom: 16px;">Found ' + data.items.length + ' items:</h4>';
        for (const item of data.items) {
            const statusBadge = item.status === 'dropped' ? 'badge-error' : 'badge-success';
            html += `
                <div class="list-item" style="margin-bottom: 12px;">
                    <div class="list-item-info">
                        <div class="list-item-title">${item.style} - ${item.color} <span class="badge ${statusBadge}">${item.status}</span></div>
                        <div class="list-item-meta">${item.division || 'N/A'} | ${item.gender || 'N/A'}</div>
                    </div>
                    <div class="list-item-actions">
                        ${item.status === 'dropped' 
                            ? `<button class="btn btn-primary" onclick="updateItemStatus('${item.id}', 'pending')"><i data-lucide="rotate-ccw" style="width: 16px; height: 16px;"></i> Unmark Drop</button>`
                            : `<button class="btn btn-secondary" onclick="updateItemStatus('${item.id}', 'dropped')"><i data-lucide="x" style="width: 16px; height: 16px;"></i> Mark as Drop</button>`
                        }
                    </div>
                </div>
            `;
        }
        html += '</div>';
        resultsDiv.innerHTML = html;
        lucide.createIcons();
    } catch (error) { resultsDiv.innerHTML = '<p style="color: red;">Error: ' + error.message + '</p>'; }
}

async function updateItemStatus(itemId, newStatus) {
    try {
        const response = await fetch(`${API_BASE}/inventory/items/${encodeURIComponent(itemId)}/status`, {
            method: 'PUT',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({status: newStatus})
        });
        if (response.ok) {
            alert(`Item status updated to "${newStatus}"!`);
            searchForManualDrop();
        } else {
            const error = await response.json();
            alert(`Error: ${error.detail}`);
        }
    } catch (error) { alert(`Error: ${error.message}`); }
}

async function resetAllDropped() {
    if (!confirm('Reset ALL dropped items back to pending status? This cannot be undone.')) return;
    const alertDiv = document.getElementById('bulk-action-alert');
    alertDiv.innerHTML = '<div class="alert alert-info">Resetting all dropped items...</div>';
    try {
        const response = await fetch(`${API_BASE}/inventory/items/bulk-status`, {
            method: 'PUT',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({from_status: 'dropped', to_status: 'pending'})
        });
        const result = await response.json();
        if (response.ok) {
            alertDiv.innerHTML = `<div class="alert alert-success">Successfully reset ${result.updated_count} items from dropped to pending!</div>`;
            setTimeout(() => alertDiv.innerHTML = '', 5000);
        } else {
            alertDiv.innerHTML = `<div class="alert alert-error">Error: ${result.detail}</div>`;
        }
    } catch (error) { alertDiv.innerHTML = `<div class="alert alert-error">Error: ${error.message}</div>`; }
}

async function viewDroppedCount() {
    const alertDiv = document.getElementById('bulk-action-alert');
    alertDiv.innerHTML = '<div class="alert alert-info">Loading...</div>';
    try {
        const response = await fetch(`${API_BASE}/inventory/items?status=dropped&page=1&page_size=1`);
        const data = await response.json();
        alertDiv.innerHTML = `<div class="alert alert-info">Currently ${data.total} items marked as dropped.</div>`;
        setTimeout(() => alertDiv.innerHTML = '', 5000);
    } catch (error) { alertDiv.innerHTML = `<div class="alert alert-error">Error: ${error.message}</div>`; }
}

window.onload = () => loadUploadedFiles();

async function loadInventory() {
    const status = document.getElementById('status-filter').value;
    const listDiv = document.getElementById('inventory-list');
    listDiv.innerHTML = '<div class="loading"><div class="spinner"></div><p>Loading inventory...</p></div>';
    try {
        const url = status === 'all' ? `${API_BASE}/inventory/items` : `${API_BASE}/inventory/items?status=${status}`;
        const response = await fetch(url);
        const items = await response.json();
        if (items.length === 0) {
            listDiv.innerHTML = '<p style="color: #666; text-align: center; padding: 40px;">No items found.</p>';
            return;
        }
        listDiv.innerHTML = `<div class="items-grid">${items.map(item => `
            <div class="item-card" onclick="showItemProfile('${item.style}', '${item.color}')">
                ${item.image_url ? `<img src="${item.image_url}" class="item-image">` : '<div class="item-image" style="display: flex; align-items: center; justify-content: center; color: #999;">No Image</div>'}
                <div class="item-style">${item.style}</div>
                <div class="item-color">${item.color}</div>
                <span class="badge badge-${item.status === 'placed' ? 'success' : 'info'}">${item.status}</span>
            </div>
        `).join('')}</div>`;
    } catch (error) { console.error('Error loading inventory:', error); }
}

async function loadStats() {
    const statsDiv = document.getElementById('stats-content');
    statsDiv.innerHTML = '<div class="loading"><div class="spinner"></div><p>Loading statistics...</p></div>';
    try {
        const response = await fetch(`${API_BASE}/inventory/stats`);
        const stats = await response.json();
        statsDiv.innerHTML = `
            <div class="grid-3" style="margin-top: 24px;">
                <div class="stat-card"><div class="stat-value">${stats.total_items}</div><div class="stat-label">Total Items</div></div>
                <div class="stat-card"><div class="stat-value">${stats.total_styles}</div><div class="stat-label">Total Styles</div></div>
                <div class="stat-card"><div class="stat-value">${stats.placed_items}</div><div class="stat-label">Placed Items</div></div>
                <div class="stat-card"><div class="stat-value">${stats.pending_items}</div><div class="stat-label">Pending Items</div></div>
                <div class="stat-card"><div class="stat-value">${stats.showroom_items}</div><div class="stat-label">Showroom Items</div></div>
                <div class="stat-card"><div class="stat-value">${stats.dropped_items}</div><div class="stat-label">Dropped Items</div></div>
            </div>
        `;
    } catch (error) { console.error('Error loading stats:', error); }
}

async function loadVisualShelves() {
    const container = document.getElementById('visual-warehouse-container');
    container.innerHTML = '<div class="loading"><div class="spinner"></div><p>Loading warehouse...</p></div>';

    try {
        const roomsResponse = await fetch(`${API_BASE}/locations/rooms`);
        const rooms = await roomsResponse.json();

        if (rooms.length === 0) {
            container.innerHTML = '<p style="color: #666; text-align: center; padding: 40px;">No warehouse structure created yet. Go to "Manage Locations" to create rooms, shelves, and rows.</p>';
            return;
        }

        // Create room carousel container
        let html = '<div class="room-carousel-container">';
        if (rooms.length > 1) {
            html += '<button class="room-carousel-arrow left" onclick="navigateRoom(-1)" id="room-prev">‹</button>';
            html += '<button class="room-carousel-arrow right" onclick="navigateRoom(1)" id="room-next">›</button>';
        }
        html += '<div class="room-carousel">';
        html += '<div class="room-carousel-track" id="room-track" data-current="0">';

        for (let roomIndex = 0; roomIndex < rooms.length; roomIndex++) {
            const room = rooms[roomIndex];
            html += '<div class="room-carousel-item">';
            const shelvesResponse = await fetch(`${API_BASE}/locations/shelves?room_id=${room.id}`);
            const shelves = await shelvesResponse.json();
            
            let totalItems = 0;
            for (const shelf of shelves) {
                const rowsResponse = await fetch(`${API_BASE}/locations/rows?shelf_id=${shelf.id}`);
                const rows = await rowsResponse.json();
                for (const row of rows) {
                    const itemsResponse = await fetch(`${API_BASE}/locations/rows/${row.id}/items`);
                    const itemsData = await itemsResponse.json();
                    totalItems += (itemsData.items || []).length;
                }
            }
            
            html += `<div class="visual-room" data-room-id="${room.id}">`;
            html += `<div class="visual-room-header">`;
            html += `<span><i data-lucide="building" style="width: 20px; height: 20px; display: inline-block; vertical-align: middle; margin-right: 8px;"></i>${room.name} <span style="font-size: 16px; opacity: 0.8;">(${shelves.length} shelves, ${totalItems} items)</span></span>`;
            html += `</div>`;
            html += `<div class="visual-room-content" id="room-content-${room.id}">`;
            
            if (shelves.length === 0) {
                html += '<p style="color: #999; text-align: center; padding: 20px; font-style: italic;">No shelves in this room</p>';
            }
            
            if (shelves.length > 0) {
                html += `<div class="shelf-carousel-container">`;
                html += `<button class="carousel-arrow left" onclick="navigateShelf(${room.id}, -1)" id="shelf-prev-${room.id}">‹</button>`;
                html += `<button class="carousel-arrow right" onclick="navigateShelf(${room.id}, 1)" id="shelf-next-${room.id}">›</button>`;
                html += `<div class="shelf-carousel">`;
                html += `<div class="shelf-carousel-track" id="shelf-track-${room.id}" data-current="0">`;
                
                for (let shelfIndex = 0; shelfIndex < shelves.length; shelfIndex++) {
                    const shelf = shelves[shelfIndex];
                    const rowsResponse = await fetch(`${API_BASE}/locations/rows?shelf_id=${shelf.id}`);
                    const rows = await rowsResponse.json();
                    
                    let shelfItemCount = 0;
                    for (const row of rows) {
                        const itemsResponse = await fetch(`${API_BASE}/locations/rows/${row.id}/items`);
                        const itemsData = await itemsResponse.json();
                        shelfItemCount += (itemsData.items || []).length;
                    }
                    
                    html += `<div class="shelf-carousel-item">`;
                    html += `<div class="visual-shelf">`;
                    html += `<div class="visual-shelf-header">`;
                    html += `<span><i data-lucide="layers" style="width: 18px; height: 18px; display: inline-block; vertical-align: middle; margin-right: 8px;"></i>${shelf.name} <span style="font-size: 14px; opacity: 0.8;">(${rows.length} rows, ${shelfItemCount} items)</span></span>`;
                    html += `</div>`;
                    html += `<div class="visual-shelf-content" id="shelf-content-${room.id}-${shelf.id}">`;
                    
                    if (rows.length === 0) {
                        html += '<p style="color: #999; text-align: center; padding: 20px; font-style: italic;">No rows on this shelf. Create rows to start placing items.</p>';
                    } else {
                        // Create row carousel
                        html += `<div class="row-carousel-container">`;
                        if (rows.length > 1) {
                            html += `<button class="row-carousel-arrow left" onclick="navigateRow(${room.id}, ${shelf.id}, -1)" id="row-prev-${room.id}-${shelf.id}">‹</button>`;
                            html += `<button class="row-carousel-arrow right" onclick="navigateRow(${room.id}, ${shelf.id}, 1)" id="row-next-${room.id}-${shelf.id}">›</button>`;
                        }
                        html += `<div class="row-carousel">`;
                        html += `<div class="row-carousel-track" id="row-track-${room.id}-${shelf.id}" data-current="0">`;

                        for (let rowIndex = 0; rowIndex < rows.length; rowIndex++) {
                            const row = rows[rowIndex];
                            const itemsResponse = await fetch(`${API_BASE}/locations/rows/${row.id}/items`);
                            const itemsData = await itemsResponse.json();
                            const items = itemsData.items || [];

                            html += `<div class="row-carousel-item">`;
                            html += `<div class="visual-row">`;
                            html += `<div class="visual-row-header"><span><i data-lucide="package" style="width: 16px; height: 16px; display: inline-block; vertical-align: middle; margin-right: 8px;"></i>${row.name}</span><span>${items.length} items</span></div>`;

                            if (items.length > 0) {
                                html += `<div class="items-grid">${items.map(item => `
                                    <div class="item-card" onclick="showItemProfile('${item.id}')">
                                        ${item.image_url ? `<img src="${API_BASE}${item.image_url}" class="item-image" alt="${item.style}">` : '<div class="item-image" style="display: flex; align-items: center; justify-content: center; color: #999;">No Image</div>'}
                                        <div class="item-style">${item.style}</div>
                                        <div class="item-color">${item.color}</div>
                                        <div class="item-division">${item.division || 'N/A'}</div>
                                    </div>
                                `).join('')}</div>`;
                            } else {
                                html += '<p style="color: #999; text-align: center; padding: 20px; font-style: italic;">Empty row - no items placed here yet</p>';
                            }
                            html += '</div></div>'; // Close visual-row, row-carousel-item
                        }

                        html += `</div></div>`; // Close row-carousel-track, row-carousel
                        if (rows.length > 1) {
                            html += `<div class="row-indicator">Row <span id="row-current-${room.id}-${shelf.id}">1</span> of ${rows.length}</div>`;
                        }
                        html += `</div>`; // Close row-carousel-container
                    }
                    
                    html += '</div></div></div>';
                }
                
                html += `</div></div>`;
                html += `<div class="shelf-indicator">Shelf <span id="shelf-current-${room.id}">1</span> of ${shelves.length}</div>`;
                html += `</div>`;
            }
            html += '</div></div></div>'; // Close room-carousel-item, visual-room, visual-room-content
        }

        html += '</div></div>'; // Close room-carousel-track, room-carousel
        if (rooms.length > 1) {
            html += '<div class="room-indicator">Room <span id="room-current">1</span> of ' + rooms.length + '</div>';
        }
        html += '</div>'; // Close room-carousel-container

        container.innerHTML = html;
        lucide.createIcons();

        // Initialize room navigation
        if (rooms.length > 1) {
            updateRoomNavigation(0, rooms.length);
        }

        // Initialize shelf and row navigation for the first room
        if (rooms.length > 0) {
            const firstRoom = rooms[0];
            // Initialize shelf navigation
            const shelfTrack = document.getElementById(`shelf-track-${firstRoom.id}`);
            if (shelfTrack) {
                const shelfItems = shelfTrack.querySelectorAll('.shelf-carousel-item');
                if (shelfItems.length > 1) {
                    const prevBtn = document.getElementById(`shelf-prev-${firstRoom.id}`);
                    const nextBtn = document.getElementById(`shelf-next-${firstRoom.id}`);
                    if (prevBtn) prevBtn.disabled = true;
                    if (nextBtn) nextBtn.disabled = shelfItems.length <= 1;
                }
                // Initialize row navigation for first shelf
                if (shelfItems.length > 0) {
                    // Find all row tracks in this room and initialize them
                    const rowTracks = container.querySelectorAll(`[id^="row-track-${firstRoom.id}-"]`);
                    rowTracks.forEach(rowTrack => {
                        const trackId = rowTrack.id;
                        const match = trackId.match(/row-track-(\d+)-(\d+)/);
                        if (match) {
                            const roomId = parseInt(match[1]);
                            const shelfId = parseInt(match[2]);
                            const rowItems = rowTrack.querySelectorAll('.row-carousel-item');
                            if (rowItems.length > 1) {
                                updateRowNavigation(roomId, shelfId, 0, rowItems.length);
                            }
                        }
                    });
                }
            }
        }
    } catch (error) {
        console.error('Error loading visual shelves:', error);
        container.innerHTML = '<p style="color: red; text-align: center; padding: 40px;">Error loading warehouse: ' + error.message + '</p>';
    }
}

async function uploadSeasonalSheet() {
    const seasonName = document.getElementById('season-name').value;
    const fileInput = document.getElementById('seasonal-file-input');
    const file = fileInput.files[0];
    if (!seasonName || !file) { showAlert('seasonal-alert', 'Please enter season name and select a file', 'error'); return; }
    const formData = new FormData();
    formData.append('file', file);
    formData.append('season_name', seasonName);
    try {
        showAlert('seasonal-alert', 'Processing seasonal drop...', 'info');
        const response = await fetch(`${API_BASE}/seasonal-drop`, { method: 'POST', body: formData });
        const result = await response.json();
        if (response.ok) {
            showAlert('seasonal-alert', `Success! Dropped ${result.dropped_count} items, kept ${result.kept_count} items`, 'success');
            fileInput.value = '';
        } else showAlert('seasonal-alert', `Error: ${result.detail}`, 'error');
    } catch (error) { showAlert('seasonal-alert', `Error: ${error.message}`, 'error'); }
}

async function viewDroppedReport() {
    const reportDiv = document.getElementById('dropped-report');
    reportDiv.innerHTML = '<div class="loading"><div class="spinner"></div><p>Loading report...</p></div>';
    try {
        const response = await fetch(`${API_BASE}/seasonal-drop/report`);
        const report = await response.json();
        if (report.total_dropped === 0) {
            reportDiv.innerHTML = '<p style="color: #666; text-align: center; padding: 40px;">No dropped items found.</p>';
            return;
        }
        let html = `<h4 style="margin: 20px 0; font-weight: 600;">Total Dropped Items: ${report.total_dropped}</h4>`;
        for (const [location, items] of Object.entries(report.by_location)) {
            html += `<div class="card" style="margin-bottom: 16px;"><h5 style="font-weight: 600; margin-bottom: 12px;">${location} (${items.length} items)</h5><div class="items-grid">`;
            for (const item of items) {
                html += `<div class="item-card"><div class="item-style">${item.style}</div><div class="item-color">${item.color}</div></div>`;
            }
            html += '</div></div>';
        }
        reportDiv.innerHTML = html;
    } catch (error) { console.error('Error loading report:', error); }
}

async function exportDroppedReport() {
    try {
        const response = await fetch(`${API_BASE}/seasonal-drop/export`);
        const blob = await response.blob();
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `dropped_items_report_${new Date().toISOString().split('T')[0]}.txt`;
        document.body.appendChild(a);
        a.click();
        window.URL.revokeObjectURL(url);
        document.body.removeChild(a);
    } catch (error) { console.error('Error exporting report:', error); alert('Error exporting report'); }
}

async function scanBarcodeImage() {
    const fileInput = document.getElementById('barcode-file-input');
    const file = fileInput.files[0];
    if (!file) { showAlert('scanner-alert', 'Please select an image', 'error'); return; }
    const formData = new FormData();
    formData.append('file', file);
    try {
        showAlert('scanner-alert', 'Scanning barcode...', 'info');
        const response = await fetch(`${API_BASE}/scan-barcode`, { method: 'POST', body: formData });
        const result = await response.json();
        if (response.ok && result.barcode) {
            showAlert('scanner-alert', `Barcode found: ${result.barcode}`, 'success');
            document.getElementById('search-style').value = result.barcode;
            searchItems();
        } else showAlert('scanner-alert', 'No barcode found in image', 'error');
    } catch (error) { showAlert('scanner-alert', `Error: ${error.message}`, 'error'); }
}

let cameraStream = null;
let scanningInterval = null;

async function startCameraScanner() {
    try {
        cameraStream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' } });
        const video = document.getElementById('camera-video');
        video.srcObject = cameraStream;
        document.getElementById('camera-container').style.display = 'block';
        document.getElementById('start-camera-btn').style.display = 'none';
        document.getElementById('stop-camera-btn').style.display = 'block';
        scanningInterval = setInterval(captureAndScan, 2000);
    } catch (error) { alert('Error accessing camera: ' + error.message); }
}

function stopCameraScanner() {
    if (cameraStream) {
        cameraStream.getTracks().forEach(track => track.stop());
        cameraStream = null;
    }
    if (scanningInterval) {
        clearInterval(scanningInterval);
        scanningInterval = null;
    }
    document.getElementById('camera-container').style.display = 'none';
    document.getElementById('start-camera-btn').style.display = 'block';
    document.getElementById('stop-camera-btn').style.display = 'none';
}

async function captureAndScan() {
    const video = document.getElementById('camera-video');
    const canvas = document.getElementById('camera-canvas');
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    const ctx = canvas.getContext('2d');
    ctx.drawImage(video, 0, 0);
    canvas.toBlob(async (blob) => {
        const formData = new FormData();
        formData.append('file', blob, 'camera-capture.jpg');
        try {
            const response = await fetch(`${API_BASE}/scan-tag`, { method: 'POST', body: formData });
            const result = await response.json();
            if (response.ok && result.style) {
                document.getElementById('scan-progress').textContent = `Found: ${result.style} - ${result.color}`;
                setTimeout(() => {
                    stopCameraScanner();
                    document.getElementById('search-style').value = result.style;
                    document.getElementById('search-color').value = result.color;
                    searchItems();
                }, 1000);
            }
        } catch (error) { console.error('Scan error:', error); }
    }, 'image/jpeg');
}

async function scanTagImage() {
    const fileInput = document.getElementById('tag-file-input');
    const file = fileInput.files[0];
    if (!file) { showAlert('tag-scanner-alert', 'Please select an image', 'error'); return; }
    const formData = new FormData();
    formData.append('file', file);
    try {
        showAlert('tag-scanner-alert', 'Scanning tag...', 'info');
        const response = await fetch(`${API_BASE}/scan-tag`, { method: 'POST', body: formData });
        const result = await response.json();
        if (response.ok && result.style) {
            showAlert('tag-scanner-alert', `Found: ${result.style} - ${result.color}`, 'success');
            document.getElementById('search-style').value = result.style;
            document.getElementById('search-color').value = result.color;
            searchItems();
        } else showAlert('tag-scanner-alert', 'Could not read tag', 'error');
    } catch (error) { showAlert('tag-scanner-alert', `Error: ${error.message}`, 'error'); }
}

async function loadColorsForStyle() {
    const style = document.getElementById('assign-style-number').value;
    if (!style) { document.getElementById('assign-color-group').style.display = 'none'; return; }
    try {
        const response = await fetch(`${API_BASE}/inventory/style/${encodeURIComponent(style)}`);
        const data = await response.json();
        if (data.colors && data.colors.length > 0) {
            const select = document.getElementById('assign-color-select');
            select.innerHTML = '<option value="">Select a color</option>' + data.colors.map(c => `<option value="${c.color}">${c.color}</option>`).join('');
            document.getElementById('assign-color-group').style.display = 'block';
        } else {
            document.getElementById('assign-color-group').style.display = 'none';
            alert('No colors found for this style');
        }
    } catch (error) { console.error('Error loading colors:', error); }
}

async function assignItemLocation() {
    const style = document.getElementById('assign-style-number').value;
    const color = document.getElementById('assign-color-select').value;
    const rowId = document.getElementById('assign-row-select').value;
    if (!style || !color || !rowId) { alert('Please fill in all fields'); return; }
    try {
        const response = await fetch(`${API_BASE}/inventory/item/${encodeURIComponent(style)}/${encodeURIComponent(color)}/location`, {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({row_id: parseInt(rowId)})
        });
        if (response.ok) {
            alert('Location assigned successfully!');
            document.getElementById('assign-style-number').value = '';
            document.getElementById('assign-color-group').style.display = 'none';
        } else {
            const error = await response.json();
            alert(`Error: ${error.detail}`);
        }
    } catch (error) { alert(`Error: ${error.message}`); }
}

async function unassignItemLocation() {
    const style = document.getElementById('assign-style-number').value;
    const color = document.getElementById('assign-color-select').value;
    if (!style || !color) { alert('Please enter style and select color'); return; }
    try {
        const response = await fetch(`${API_BASE}/inventory/item/${encodeURIComponent(style)}/${encodeURIComponent(color)}/location`, {
            method: 'DELETE'
        });
        if (response.ok) {
            alert('Location removed successfully!');
            document.getElementById('assign-style-number').value = '';
            document.getElementById('assign-color-group').style.display = 'none';
        } else {
            const error = await response.json();
            alert(`Error: ${error.detail}`);
        }
    } catch (error) { alert(`Error: ${error.message}`); }
}

function navigateRoom(direction) {
    const track = document.getElementById('room-track');
    if (!track) return;

    const currentIndex = parseInt(track.dataset.current);
    const items = track.querySelectorAll('.room-carousel-item');
    const newIndex = currentIndex + direction;

    if (newIndex < 0 || newIndex >= items.length) return;

    track.dataset.current = newIndex;
    track.style.transform = `translateX(-${newIndex * 100}%)`;

    const currentSpan = document.getElementById('room-current');
    if (currentSpan) currentSpan.textContent = newIndex + 1;

    updateRoomNavigation(newIndex, items.length);
}

function updateRoomNavigation(currentIndex, totalRooms) {
    const prevBtn = document.getElementById('room-prev');
    const nextBtn = document.getElementById('room-next');

    if (prevBtn) prevBtn.disabled = currentIndex === 0;
    if (nextBtn) nextBtn.disabled = currentIndex === totalRooms - 1;
}

function toggleShelf(roomId, shelfId) {
    const content = document.getElementById(`shelf-content-${roomId}-${shelfId}`);
    const icon = document.getElementById(`shelf-toggle-${roomId}-${shelfId}`);
    
    if (content.classList.contains('collapsed')) {
        content.classList.remove('collapsed');
        content.style.maxHeight = content.scrollHeight + 'px';
        icon.classList.remove('collapsed');
        icon.textContent = '▼';
    } else {
        content.classList.add('collapsed');
        content.style.maxHeight = '0';
        icon.classList.add('collapsed');
        icon.textContent = '▶';
    }
}

function collapseAllRooms() {
    document.querySelectorAll('.visual-room-content').forEach(content => {
        content.classList.add('collapsed');
        content.style.maxHeight = '0';
    });
    document.querySelectorAll('.visual-room-header .toggle-icon').forEach(icon => {
        icon.classList.add('collapsed');
        icon.textContent = '▶';
    });
}

function expandAllRooms() {
    document.querySelectorAll('.visual-room-content').forEach(content => {
        content.classList.remove('collapsed');
        content.style.maxHeight = content.scrollHeight + 'px';
    });
    document.querySelectorAll('.visual-room-header .toggle-icon').forEach(icon => {
        icon.classList.remove('collapsed');
        icon.textContent = '▼';
    });
    document.querySelectorAll('.visual-shelf-content').forEach(content => {
        content.classList.remove('collapsed');
        content.style.maxHeight = content.scrollHeight + 'px';
    });
    document.querySelectorAll('.visual-shelf-header .toggle-icon').forEach(icon => {
        icon.classList.remove('collapsed');
        icon.textContent = '▼';
    });
}

function navigateShelf(roomId, direction) {
    const track = document.getElementById(`shelf-track-${roomId}`);
    const currentIndex = parseInt(track.dataset.current);
    const items = track.querySelectorAll('.shelf-carousel-item');
    const newIndex = currentIndex + direction;
    
    if (newIndex < 0 || newIndex >= items.length) return;
    
    track.dataset.current = newIndex;
    track.style.transform = `translateX(-${newIndex * 100}%)`;
    
    document.getElementById(`shelf-current-${roomId}`).textContent = newIndex + 1;
    
    const prevBtn = document.getElementById(`shelf-prev-${roomId}`);
    const nextBtn = document.getElementById(`shelf-next-${roomId}`);
    
    prevBtn.disabled = newIndex === 0;
    nextBtn.disabled = newIndex === items.length - 1;
}

function navigateRow(roomId, shelfId, direction) {
    const track = document.getElementById(`row-track-${roomId}-${shelfId}`);
    if (!track) return;

    const currentIndex = parseInt(track.dataset.current);
    const items = track.querySelectorAll('.row-carousel-item');
    const newIndex = currentIndex + direction;

    if (newIndex < 0 || newIndex >= items.length) return;

    track.dataset.current = newIndex;
    track.style.transform = `translateX(-${newIndex * 100}%)`;

    const currentSpan = document.getElementById(`row-current-${roomId}-${shelfId}`);
    if (currentSpan) currentSpan.textContent = newIndex + 1;

    updateRowNavigation(roomId, shelfId, newIndex, items.length);
}

function updateRowNavigation(roomId, shelfId, currentIndex, totalRows) {
    const prevBtn = document.getElementById(`row-prev-${roomId}-${shelfId}`);
    const nextBtn = document.getElementById(`row-next-${roomId}-${shelfId}`);

    if (prevBtn) prevBtn.disabled = currentIndex === 0;
    if (nextBtn) nextBtn.disabled = currentIndex === totalRows - 1;
}

async function loadAllAnalytics() {
    try {
        await Promise.all([
            loadAnalyticsOverview(),
            loadAnalyticsTimeline(),
            loadAnalyticsFileComparison(),
            loadAnalyticsDivisionTrends(),
            loadAnalyticsOverlap(),
            loadAnalyticsPlacement(),
            loadAnalyticsStyleFamilies()
        ]);
    } catch (error) { console.error('Error loading analytics:', error); }
}

async function loadAnalyticsOverview() {
    try {
        const response = await fetch(`${API_BASE}/analytics/files/comparison`);
        const data = await response.json();
        if (!data.files || data.files.length === 0) {
            document.getElementById('overview-stats').innerHTML = '<p style="color: #666; text-align: center; padding: 40px;">No files uploaded yet. Upload an Excel file to see analytics.</p>';
            return;
        }
        const totalItems = data.files.reduce((sum, f) => sum + (f.total_items || 0), 0);
        const totalStyles = data.files.reduce((sum, f) => sum + (f.unique_styles || 0), 0);
        document.getElementById('overview-stats').innerHTML = `
            <div class="grid-3" style="margin-top: 20px;">
                <div class="stat-card"><div class="stat-value">${data.total_files || 0}</div><div class="stat-label">Total Files</div></div>
                <div class="stat-card"><div class="stat-value">${totalItems}</div><div class="stat-label">Total Items</div></div>
                <div class="stat-card"><div class="stat-value">${totalStyles}</div><div class="stat-label">Unique Styles</div></div>
            </div>
        `;
    } catch (error) { 
        console.error('Error loading overview:', error);
        document.getElementById('overview-stats').innerHTML = '<p style="color: #f44336; text-align: center; padding: 20px;">Error loading analytics data</p>';
    }
}

async function loadAnalyticsTimeline() {
    try {
        const response = await fetch(`${API_BASE}/analytics/trends/timeline`);
        const data = await response.json();
        if (!data.timeline || data.timeline.length === 0) {
            document.getElementById('timeline-content').innerHTML = '<p style="color: #666; text-align: center; padding: 20px;">No timeline data available</p>';
            return;
        }
        let html = '<div style="margin-top: 20px;">';
        data.timeline.forEach(entry => {
            html += `<div style="padding: 15px; border-left: 3px solid #2c2c2c; margin-bottom: 15px; background: #f8f9fa; border-radius: 8px;">
                <div style="font-weight: 600; margin-bottom: 8px;">${entry.filename}</div>
                <div style="font-size: 14px; color: #666;">Items: ${entry.items_in_file} | Styles: ${entry.styles_in_file} | New: ${entry.new_items} items, ${entry.new_styles} styles</div>
            </div>`;
        });
        html += '</div>';
        document.getElementById('timeline-content').innerHTML = html;
        
        const ctx = document.getElementById('timelineChart').getContext('2d');
        if (window.timelineChart) window.timelineChart.destroy();
        window.timelineChart = new Chart(ctx, {
            type: 'line',
            data: {
                labels: data.timeline.map(t => t.filename),
                datasets: [{
                    label: 'Cumulative Styles',
                    data: data.timeline.map(t => t.cumulative_styles),
                    borderColor: '#4CAF50',
                    backgroundColor: 'rgba(76, 175, 80, 0.1)',
                    tension: 0.4
                }, {
                    label: 'Cumulative Items',
                    data: data.timeline.map(t => t.cumulative_items),
                    borderColor: '#2196F3',
                    backgroundColor: 'rgba(33, 150, 243, 0.1)',
                    tension: 0.4
                }]
            },
            options: { responsive: true, maintainAspectRatio: false }
        });
    } catch (error) { 
        console.error('Error loading timeline:', error);
        document.getElementById('timeline-content').innerHTML = '<p style="color: #f44336; text-align: center; padding: 20px;">Error loading timeline data</p>';
    }
}

async function loadAnalyticsFileComparison() {
    try {
        const response = await fetch(`${API_BASE}/analytics/files/comparison`);
        const data = await response.json();
        if (!data.files || data.files.length === 0) {
            document.getElementById('file-comparison').innerHTML = '<p style="color: #666; text-align: center; padding: 20px;">No files to compare</p>';
            return;
        }
        let html = '<div class="grid-2" style="margin-top: 20px;">';
        data.files.forEach(file => {
            html += `<div class="card" style="background: #f8f9fa;">
                <h4 style="margin-bottom: 12px; color: #2c2c2c;">${file.filename}</h4>
                <div style="display: grid; gap: 8px; font-size: 14px;">
                    <div><strong>Total Items:</strong> ${file.total_items || 0}</div>
                    <div><strong>Unique Styles:</strong> ${file.unique_styles || 0}</div>
                    <div><strong>Shared Items:</strong> ${file.shared_items || 0}</div>
                    <div><strong>Status:</strong> <span class="badge badge-success">${file.status || 'unknown'}</span></div>
                </div>
            </div>`;
        });
        html += '</div>';
        document.getElementById('file-comparison').innerHTML = html;
    } catch (error) { 
        console.error('Error loading file comparison:', error);
        document.getElementById('file-comparison').innerHTML = '<p style="color: #f44336; text-align: center; padding: 20px;">Error loading file comparison</p>';
    }
}

async function loadAnalyticsDivisionTrends() {
    try {
        const response = await fetch(`${API_BASE}/analytics/division/trends`);
        const data = await response.json();
        const ctx = document.getElementById('divisionTrendsChart').getContext('2d');
        if (window.divisionChart) window.divisionChart.destroy();
        
        const datasets = data.all_divisions.map((div, idx) => ({
            label: div,
            data: data.trends.map(t => t.divisions[div] || 0),
            borderColor: `hsl(${idx * 360 / data.all_divisions.length}, 70%, 50%)`,
            backgroundColor: `hsla(${idx * 360 / data.all_divisions.length}, 70%, 50%, 0.1)`,
            tension: 0.4
        }));
        
        window.divisionChart = new Chart(ctx, {
            type: 'line',
            data: {
                labels: data.trends.map(t => t.filename),
                datasets: datasets
            },
            options: { responsive: true, maintainAspectRatio: false }
        });
    } catch (error) { console.error('Error loading division trends:', error); }
}

async function loadAnalyticsOverlap() {
    try {
        const response = await fetch(`${API_BASE}/analytics/comparison/overlap`);
        const data = await response.json();
        let html = '<div style="margin-top: 20px;">';
        if (data.overlaps && data.overlaps.length > 0) {
            data.overlaps.forEach(overlap => {
                html += `<div style="padding: 15px; background: #f8f9fa; border-radius: 8px; margin-bottom: 12px;">
                    <div style="font-weight: 600; margin-bottom: 8px;">${overlap.file1} ↔ ${overlap.file2}</div>
                    <div style="font-size: 14px; color: #666;">Shared: ${overlap.shared_items} | Overlap: ${overlap.overlap_percentage}%</div>
                </div>`;
            });
        } else {
            html += '<p style="color: #666; text-align: center; padding: 20px;">Need at least 2 files for overlap analysis</p>';
        }
        html += '</div>';
        document.getElementById('overlap-content').innerHTML = html;
    } catch (error) { console.error('Error loading overlap:', error); }
}

async function loadAnalyticsPlacement() {
    try {
        const response = await fetch(`${API_BASE}/analytics/placement/analytics`);
        const data = await response.json();
        const ctx = document.getElementById('placementChart').getContext('2d');
        if (window.placementChart) window.placementChart.destroy();
        
        window.placementChart = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: data.placement_analytics.map(p => p.filename),
                datasets: [{
                    label: 'Placed',
                    data: data.placement_analytics.map(p => p.placed),
                    backgroundColor: '#4CAF50'
                }, {
                    label: 'Pending',
                    data: data.placement_analytics.map(p => p.pending),
                    backgroundColor: '#FFC107'
                }]
            },
            options: { responsive: true, maintainAspectRatio: false, scales: { x: { stacked: true }, y: { stacked: true } } }
        });
        
        let html = '<div style="margin-top: 20px; display: grid; gap: 12px;">';
        data.placement_analytics.forEach(p => {
            html += `<div style="padding: 12px; background: #f8f9fa; border-radius: 8px;">
                <strong>${p.filename}:</strong> ${p.placement_rate}% placed (${p.placed}/${p.total_items})
            </div>`;
        });
        html += '</div>';
        document.getElementById('placement-details').innerHTML = html;
    } catch (error) { console.error('Error loading placement:', error); }
}

async function loadAnalyticsStyleFamilies() {
    try {
        const response = await fetch(`${API_BASE}/analytics/style-families`);
        const data = await response.json();
        document.getElementById('style-family-summary').innerHTML = `
            <div class="grid-3" style="margin-top: 20px;">
                <div class="stat-card"><div class="stat-value">${data.total_families}</div><div class="stat-label">Style Families</div></div>
                <div class="stat-card"><div class="stat-value">${data.summary.avg_items_per_family}</div><div class="stat-label">Avg Items/Family</div></div>
                <div class="stat-card"><div class="stat-value">${data.summary.avg_styles_per_family}</div><div class="stat-label">Avg Styles/Family</div></div>
            </div>
        `;
        
        const ctx = document.getElementById('styleFamilyChart').getContext('2d');
        if (window.familyChart) window.familyChart.destroy();
        
        window.familyChart = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: data.top_families.map(f => f.family_prefix),
                datasets: [{
                    label: 'Total Items',
                    data: data.top_families.map(f => f.total_items),
                    backgroundColor: '#4CAF50'
                }]
            },
            options: { responsive: true, maintainAspectRatio: false }
        });
        
        let html = '<div style="margin-top: 20px; display: grid; gap: 12px;">';
        data.top_families.slice(0, 10).forEach(f => {
            html += `<div style="padding: 12px; background: #f8f9fa; border-radius: 8px;">
                <strong>${f.family_prefix}xxx:</strong> ${f.total_items} items, ${f.unique_styles} styles, ${f.placement_rate}% placed
            </div>`;
        });
        html += '</div>';
        document.getElementById('style-family-details').innerHTML = html;
    } catch (error) { console.error('Error loading style families:', error); }
}

window.onload = () => loadUploadedFiles();
