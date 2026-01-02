import SwiftUI
import AVFoundation
import PhotosUI

// MARK: - Seasonal Drop View
struct SeasonalDropView: View {
    @EnvironmentObject var apiService: APIService
    @State private var droppedReport: DroppedReport?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var expandedLocations: Set<String> = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.title2)
                                .foregroundColor(.red)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Seasonal Drop Report")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Items marked as dropped from current season")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    Button(action: loadDroppedReport) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh Report")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal)
                    
                    if isLoading {
                        ProgressView()
                            .padding()
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    
                    if let report = droppedReport {
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                StatCard(title: "Total Dropped", value: "\(report.totalDropped)", color: .red, icon: "xmark.circle.fill")
                                StatCard(title: "With Location", value: "\(report.withLocation)", color: .orange, icon: "location.fill")
                            }
                            .padding(.horizontal)
                            
                            if !report.itemsByLocation.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "building.2.fill")
                                            .foregroundColor(.orange)
                                        Text("Items by Warehouse Location")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                    }
                                    .padding(.horizontal)
                                    
                                    ForEach(Array(report.itemsByLocation.keys.sorted()), id: \.self) { location in
                                        DroppedLocationCard(
                                            location: location,
                                            items: report.itemsByLocation[location] ?? [],
                                            isExpanded: expandedLocations.contains(location),
                                            onToggle: {
                                                if expandedLocations.contains(location) {
                                                    expandedLocations.remove(location)
                                                } else {
                                                    expandedLocations.insert(location)
                                                }
                                            }
                                        )
                                    }
                                }
                            }
                            
                            if !report.itemsWithoutLocation.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.yellow)
                                        Text("Items Without Location (\(report.itemsWithoutLocation.count))")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                    }
                                    .padding(.horizontal)
                                    
                                    VStack(spacing: 8) {
                                        ForEach(report.itemsWithoutLocation) { item in
                                            DroppedItemRow(item: item)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Seasonal Drop")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if droppedReport == nil {
                    loadDroppedReport()
                }
            }
        }
    }
    
    private func loadDroppedReport() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                droppedReport = try await apiService.getDroppedReport()
                isLoading = false
            } catch {
                errorMessage = "Failed to load report: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

struct DroppedLocationCard: View {
    let location: String
    let items: [DroppedItem]
    let isExpanded: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onToggle) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(location)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("\(items.count) items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Divider()
                VStack(spacing: 8) {
                    ForEach(items) { item in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(item.style) - \(item.color)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if let division = item.division, let gender = item.gender {
                                    Text("\(division) • \(gender)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct DroppedItemRow: View {
    let item: DroppedItem
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(item.style) - \(item.color)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let division = item.division, let gender = item.gender {
                    Text("\(division) • \(gender)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Image(systemName: "location.slash")
                .foregroundColor(.orange)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Visual Shelves View
struct VisualShelvesView: View {
    @EnvironmentObject var apiService: APIService
    @State private var warehouseLayout: WarehouseLayout?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedItem: Item?
    @State private var expandedRooms: Set<Int> = []
    @State private var expandedShelves: Set<Int> = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "square.grid.3x3.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Warehouse Visual Layout")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Browse items by physical location")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    Button(action: loadWarehouse) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh Layout")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal)
                    
                    if isLoading {
                        ProgressView()
                            .padding()
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    
                    if let layout = warehouseLayout {
                        ForEach(layout.warehouseLayout) { room in
                            RoomCard(
                                room: room,
                                isExpanded: expandedRooms.contains(room.id),
                                expandedShelves: $expandedShelves,
                                onToggle: {
                                    if expandedRooms.contains(room.id) {
                                        expandedRooms.remove(room.id)
                                    } else {
                                        expandedRooms.insert(room.id)
                                    }
                                },
                                onItemTap: { item in
                                    selectedItem = item
                                }
                            )
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Visual Shelves")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if warehouseLayout == nil {
                    loadWarehouse()
                }
            }
            .sheet(item: $selectedItem) { item in
                ItemDetailSheet(item: item)
            }
        }
    }
    
    private func loadWarehouse() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                warehouseLayout = try await apiService.getWarehouseLayout()
                isLoading = false
            } catch {
                errorMessage = "Failed to load warehouse: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

struct RoomCard: View {
    let room: RoomLayout
    let isExpanded: Bool
    @Binding var expandedShelves: Set<Int>
    let onToggle: () -> Void
    let onItemTap: (Item) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onToggle) {
                HStack {
                    Image(systemName: "building.2.fill")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(room.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("\(room.shelves.count) shelves")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                        .foregroundColor(.blue)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Divider()
                ForEach(room.shelves) { shelf in
                    ShelfCard(
                        shelf: shelf,
                        isExpanded: expandedShelves.contains(shelf.id),
                        onToggle: {
                            if expandedShelves.contains(shelf.id) {
                                expandedShelves.remove(shelf.id)
                            } else {
                                expandedShelves.insert(shelf.id)
                            }
                        },
                        onItemTap: onItemTap
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct ShelfCard: View {
    let shelf: ShelfLayout
    let isExpanded: Bool
    let onToggle: () -> Void
    let onItemTap: (Item) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onToggle) {
                HStack {
                    Image(systemName: "square.stack.3d.up.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text(shelf.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text("(\(shelf.rows.count) rows)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                ForEach(shelf.rows) { row in
                    RowCard(row: row, onItemTap: onItemTap)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct RowCard: View {
    let row: RowLayout
    let onItemTap: (Item) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "rectangle.stack.fill")
                    .foregroundColor(.purple)
                    .font(.caption2)
                Text(row.name)
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text("\(row.items.count) items")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !row.items.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(row.items) { item in
                            Button(action: { onItemTap(item) }) {
                                VStack(spacing: 4) {
                                    if let imageUrl = item.imageUrl {
                                        AsyncImage(url: URL(string: "https://warehouse.obinnachukwu.org\(imageUrl)")) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Color.gray.opacity(0.3)
                                        }
                                        .frame(width: 60, height: 60)
                                        .clipped()
                                        .cornerRadius(8)
                                    } else {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 60, height: 60)
                                            .cornerRadius(8)
                                    }
                                    
                                    Text(item.styleNumber)
                                        .font(.caption2)
                                        .lineLimit(1)
                                }
                                .frame(width: 70)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(6)
    }
}

struct ItemDetailSheet: View {
    let item: Item
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let imageUrl = item.imageUrl {
                        AsyncImage(url: URL(string: "https://warehouse.obinnachukwu.org\(imageUrl)")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                    }
                    
                    VStack(spacing: 16) {
                        DetailRow(label: "Style", value: item.styleNumber)
                        DetailRow(label: "Color", value: item.colorCode)
                        if let division = item.division {
                            DetailRow(label: "Division", value: division)
                        }
                        if let gender = item.gender {
                            DetailRow(label: "Gender", value: gender)
                        }
                        if let status = item.status {
                            DetailRow(label: "Status", value: status.capitalized)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Item Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Locations View
struct LocationsView: View {
    @EnvironmentObject var apiService: APIService
    @State private var rooms: [Room] = []
    @State private var shelves: [Shelf] = []
    @State private var rows: [Row] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAddRoom = false
    @State private var showingAddShelf = false
    @State private var showingAddRow = false
    @State private var expandedRooms: Set<Int> = []
    @State private var expandedShelves: Set<Int> = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "building.2.fill")
                                .font(.title2)
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Manage Locations")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Create and organize warehouse structure")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    HStack(spacing: 12) {
                        Button(action: { showingAddRoom = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Room")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        Button(action: loadLocations) {
                            Image(systemName: "arrow.clockwise")
                                .frame(width: 44, height: 44)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    
                    if isLoading {
                        ProgressView()
                            .padding()
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    
                    if rooms.isEmpty && !isLoading {
                        VStack(spacing: 12) {
                            Image(systemName: "building.2")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("No locations yet")
                                .foregroundColor(.secondary)
                            Text("Tap 'Add Room' to get started")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else {
                        ForEach(rooms) { room in
                            LocationRoomCard(
                                room: room,
                                shelves: shelves.filter { $0.roomId == room.id },
                                rows: rows,
                                isExpanded: expandedRooms.contains(room.id),
                                expandedShelves: $expandedShelves,
                                onToggle: {
                                    if expandedRooms.contains(room.id) {
                                        expandedRooms.remove(room.id)
                                    } else {
                                        expandedRooms.insert(room.id)
                                    }
                                },
                                onAddShelf: {
                                    showingAddShelf = true
                                },
                                onDeleteRoom: {
                                    deleteRoom(room.id)
                                },
                                onDeleteShelf: { shelfId in
                                    deleteShelf(shelfId)
                                },
                                onDeleteRow: { rowId in
                                    deleteRow(rowId)
                                },
                                onAddRow: {
                                    showingAddRow = true
                                }
                            )
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Locations")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if rooms.isEmpty {
                    loadLocations()
                }
            }
            .sheet(isPresented: $showingAddRoom) {
                AddRoomSheet(apiService: apiService, onComplete: loadLocations)
            }
            .sheet(isPresented: $showingAddShelf) {
                AddShelfSheet(apiService: apiService, rooms: rooms, onComplete: loadLocations)
            }
            .sheet(isPresented: $showingAddRow) {
                AddRowSheet(apiService: apiService, shelves: shelves, onComplete: loadLocations)
            }
        }
    }
    
    private func loadLocations() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                async let roomsData = apiService.getRooms()
                async let shelvesData = apiService.getShelves()
                async let rowsData = apiService.getRows()
                
                rooms = try await roomsData
                shelves = try await shelvesData
                rows = try await rowsData
                isLoading = false
            } catch {
                errorMessage = "Failed to load locations: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func deleteRoom(_ id: Int) {
        Task {
            do {
                try await apiService.deleteRoom(id: id)
                loadLocations()
            } catch {
                errorMessage = "Failed to delete room: \(error.localizedDescription)"
            }
        }
    }
    
    private func deleteShelf(_ id: Int) {
        Task {
            do {
                try await apiService.deleteShelf(id: id)
                loadLocations()
            } catch {
                errorMessage = "Failed to delete shelf: \(error.localizedDescription)"
            }
        }
    }
    
    private func deleteRow(_ id: Int) {
        Task {
            do {
                try await apiService.deleteRow(id: id)
                loadLocations()
            } catch {
                errorMessage = "Failed to delete row: \(error.localizedDescription)"
            }
        }
    }
}

struct LocationRoomCard: View {
    let room: Room
    let shelves: [Shelf]
    let rows: [Row]
    let isExpanded: Bool
    @Binding var expandedShelves: Set<Int>
    let onToggle: () -> Void
    let onAddShelf: () -> Void
    let onDeleteRoom: () -> Void
    let onDeleteShelf: (Int) -> Void
    let onDeleteRow: (Int) -> Void
    let onAddRow: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: onToggle) {
                    HStack {
                        Image(systemName: "building.2.fill")
                            .foregroundColor(.blue)
                        Text(room.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("(\(shelves.count) shelves)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onDeleteRoom) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            
            if isExpanded {
                Divider()
                
                Button(action: onAddShelf) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add Shelf to \(room.name)")
                            .font(.subheadline)
                    }
                    .foregroundColor(.blue)
                }
                .padding(.vertical, 4)
                
                ForEach(shelves) { shelf in
                    LocationShelfCard(
                        shelf: shelf,
                        rows: rows.filter { $0.shelfId == shelf.id },
                        isExpanded: expandedShelves.contains(shelf.id),
                        onToggle: {
                            if expandedShelves.contains(shelf.id) {
                                expandedShelves.remove(shelf.id)
                            } else {
                                expandedShelves.insert(shelf.id)
                            }
                        },
                        onAddRow: onAddRow,
                        onDeleteShelf: { onDeleteShelf(shelf.id) },
                        onDeleteRow: onDeleteRow
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct LocationShelfCard: View {
    let shelf: Shelf
    let rows: [Row]
    let isExpanded: Bool
    let onToggle: () -> Void
    let onAddRow: () -> Void
    let onDeleteShelf: () -> Void
    let onDeleteRow: (Int) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: onToggle) {
                    HStack {
                        Image(systemName: "square.stack.3d.up.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text(shelf.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("(\(rows.count) rows)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onDeleteShelf) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            if isExpanded {
                Button(action: onAddRow) {
                    HStack {
                        Image(systemName: "plus.circle")
                            .font(.caption)
                        Text("Add Row to \(shelf.name)")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
                .padding(.vertical, 2)
                
                ForEach(rows) { row in
                    HStack {
                        Image(systemName: "rectangle.stack.fill")
                            .foregroundColor(.purple)
                            .font(.caption2)
                        Text(row.name)
                            .font(.caption)
                        Spacer()
                        Button(action: { onDeleteRow(row.id) }) {
                            Image(systemName: "trash")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(8)
                    .background(Color(.systemBackground))
                    .cornerRadius(6)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct AddRoomSheet: View {
    let apiService: APIService
    let onComplete: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var roomName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Room Details")) {
                    TextField("Room Name", text: $roomName)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button(action: createRoom) {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                            } else {
                                Text("Create Room")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(roomName.isEmpty || isLoading)
                }
            }
            .navigationTitle("Add Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func createRoom() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await apiService.createRoom(name: roomName, description: nil)
                isLoading = false
                onComplete()
                dismiss()
            } catch {
                errorMessage = "Failed to create room: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

struct AddShelfSheet: View {
    let apiService: APIService
    let rooms: [Room]
    let onComplete: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var shelfName = ""
    @State private var selectedRoomId: Int?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Shelf Details")) {
                    TextField("Shelf Name", text: $shelfName)
                    
                    Picker("Room", selection: $selectedRoomId) {
                        Text("Select Room").tag(nil as Int?)
                        ForEach(rooms) { room in
                            Text(room.name).tag(room.id as Int?)
                        }
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button(action: createShelf) {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                            } else {
                                Text("Create Shelf")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(shelfName.isEmpty || selectedRoomId == nil || isLoading)
                }
            }
            .navigationTitle("Add Shelf")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func createShelf() {
        guard let roomId = selectedRoomId else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await apiService.createShelf(roomId: roomId, name: shelfName, description: nil)
                isLoading = false
                onComplete()
                dismiss()
            } catch {
                errorMessage = "Failed to create shelf: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

struct AddRowSheet: View {
    let apiService: APIService
    let shelves: [Shelf]
    let onComplete: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var rowName = ""
    @State private var selectedShelfId: Int?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Row Details")) {
                    TextField("Row Name", text: $rowName)
                    
                    Picker("Shelf", selection: $selectedShelfId) {
                        Text("Select Shelf").tag(nil as Int?)
                        ForEach(shelves) { shelf in
                            Text(shelf.name).tag(shelf.id as Int?)
                        }
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button(action: createRow) {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                            } else {
                                Text("Create Row")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(rowName.isEmpty || selectedShelfId == nil || isLoading)
                }
            }
            .navigationTitle("Add Row")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func createRow() {
        guard let shelfId = selectedShelfId else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await apiService.createRow(shelfId: shelfId, name: rowName, description: nil)
                isLoading = false
                onComplete()
                dismiss()
            } catch {
                errorMessage = "Failed to create row: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}
struct SearchView: View {
    @EnvironmentObject var apiService: APIService
    @State private var styleNumber = ""
    @State private var colorCode = ""
    @State private var searchResults: [Item] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingScanner = false
    @State private var selectedItem: Item?
    @State private var showingAssignLocation = false
    
    let initialQuery: String?
    
    init(initialQuery: String? = nil) {
        self.initialQuery = initialQuery
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        TextField("Style Number", text: $styleNumber)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.allCharacters)
                        
                        Button(action: { showingScanner = true }) {
                            Image(systemName: "barcode.viewfinder")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }
                    
                    TextField("Color Code (Optional)", text: $colorCode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.allCharacters)
                    
                    HStack(spacing: 12) {
                        Button(action: searchItems) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                Text("Search")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled((styleNumber.isEmpty && colorCode.isEmpty) || isLoading)
                        
                        Button(action: clearSearch) {
                            HStack {
                                Image(systemName: "xmark.circle")
                                Text("Clear")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                if isLoading {
                    ProgressView()
                        .padding()
                    Spacer()
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding()
                    Spacer()
                } else if searchResults.isEmpty && (!styleNumber.isEmpty || !colorCode.isEmpty) {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No items found")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    Spacer()
                } else {
                    List(searchResults) { item in
                        SearchItemRow(item: item) {
                            selectedItem = item
                            showingAssignLocation = true
                        }
                    }
                }
            }
            .navigationTitle("Search Items")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingScanner) {
                BarcodeScannerView { result in
                    if let style = result.styleNumber {
                        styleNumber = style
                        searchItems()
                    }
                }
            }
            .sheet(item: $selectedItem) { item in
                AssignLocationSheet(item: item, apiService: apiService)
            }
        }
    }
    
    private func searchItems() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                searchResults = try await apiService.searchItems(
                    style: styleNumber.isEmpty ? nil : styleNumber,
                    color: colorCode.isEmpty ? nil : colorCode
                )
                isLoading = false
            } catch {
                errorMessage = "Search failed: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func clearSearch() {
        styleNumber = ""
        colorCode = ""
        searchResults = []
        errorMessage = nil
    }
}

struct SearchItemRow: View {
    let item: Item
    let onAssign: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            if let imageUrl = item.imageUrl {
                AsyncImage(url: URL(string: "https://warehouse.obinnachukwu.org\(imageUrl)")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 60, height: 60)
                .clipped()
                .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.styleNumber)
                    .font(.headline)
                Text(item.colorCode)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if let status = item.status {
                    Text(status.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor(status).opacity(0.2))
                        .foregroundColor(statusColor(status))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            Button(action: onAssign) {
                Text("Assign")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "placed": return .green
        case "pending": return .orange
        case "dropped": return .red
        default: return .gray
        }
    }
}

struct AssignLocationSheet: View {
    let item: Item
    let apiService: APIService
    @Environment(\.dismiss) var dismiss
    @State private var rooms: [Room] = []
    @State private var shelves: [Shelf] = []
    @State private var rows: [Row] = []
    @State private var selectedRoomId: Int?
    @State private var selectedShelfId: Int?
    @State private var selectedRowId: Int?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Item Details")) {
                    HStack {
                        Text("Style")
                        Spacer()
                        Text(item.styleNumber)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Color")
                        Spacer()
                        Text(item.colorCode)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Select Location")) {
                    Picker("Room", selection: $selectedRoomId) {
                        Text("Select Room").tag(nil as Int?)
                        ForEach(rooms) { room in
                            Text(room.name).tag(room.id as Int?)
                        }
                    }
                    .onChange(of: selectedRoomId) { _ in
                        loadShelves()
                    }
                    
                    Picker("Shelf", selection: $selectedShelfId) {
                        Text("Select Shelf").tag(nil as Int?)
                        ForEach(shelves) { shelf in
                            Text(shelf.name).tag(shelf.id as Int?)
                        }
                    }
                    .disabled(selectedRoomId == nil)
                    .onChange(of: selectedShelfId) { _ in
                        loadRows()
                    }
                    
                    Picker("Row", selection: $selectedRowId) {
                        Text("Select Row").tag(nil as Int?)
                        ForEach(rows) { row in
                            Text(row.name).tag(row.id as Int?)
                        }
                    }
                    .disabled(selectedShelfId == nil)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                if let success = successMessage {
                    Section {
                        Text(success)
                            .foregroundColor(.green)
                    }
                }
                
                Section {
                    Button(action: assignLocation) {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                            } else {
                                Text("Assign to Location")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(selectedRowId == nil || isLoading)
                }
            }
            .navigationTitle("Assign Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                loadRooms()
            }
        }
    }
    
    private func loadRooms() {
        Task {
            do {
                rooms = try await apiService.getRooms()
            } catch {}
        }
    }
    
    private func loadShelves() {
        selectedShelfId = nil
        selectedRowId = nil
        shelves = []
        rows = []
        
        guard let roomId = selectedRoomId else { return }
        
        Task {
            do {
                shelves = try await apiService.getShelves(roomId: roomId)
            } catch {}
        }
    }
    
    private func loadRows() {
        selectedRowId = nil
        rows = []
        
        guard let shelfId = selectedShelfId else { return }
        
        Task {
            do {
                rows = try await apiService.getRows(shelfId: shelfId)
            } catch {}
        }
    }
    
    private func assignLocation() {
        guard let rowId = selectedRowId else { return }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            do {
                try await apiService.updateItemLocation(itemId: item.id, rowId: rowId)
                successMessage = "Item assigned successfully!"
                isLoading = false
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            } catch {
                errorMessage = "Failed to assign: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

// MARK: - Inventory View
struct InventoryView: View {
    @EnvironmentObject var apiService: APIService
    @State private var items: [Item] = []
    @State private var allItems: [Item] = []
    @State private var selectedStatus = "all"
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedItem: Item?
    @State private var searchText = ""
    @State private var showingScanner = false
    
    let statusOptions = ["all", "pending", "placed", "showroom", "waitlist", "dropped"]
    
    var filteredItems: [Item] {
        if searchText.isEmpty {
            return items
        }
        return items.filter { item in
            item.styleNumber.localizedCaseInsensitiveContains(searchText) ||
            item.colorCode.localizedCaseInsensitiveContains(searchText) ||
            (item.division?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (item.gender?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search style, color, division...", text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        
                        Button(action: { showingScanner = true }) {
                            Image(systemName: "camera.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    
                    Picker("Status", selection: $selectedStatus) {
                        ForEach(statusOptions, id: \.self) { status in
                            Text(status.capitalized).tag(status)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .onChange(of: selectedStatus) { _ in
                        loadInventory()
                    }
                }
                .padding(.vertical, 12)
                
                if isLoading {
                    ProgressView()
                        .padding()
                    Spacer()
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                    Spacer()
                } else if items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No items found")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredItems) { item in
                                InventoryItemCard(item: item) {
                                    selectedItem = item
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: loadInventory) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                if items.isEmpty {
                    loadInventory()
                }
            }
            .sheet(item: $selectedItem) { item in
                InventoryItemDetailView(item: item)
            }
            .fullScreenCover(isPresented: $showingScanner) {
                TagScannerView(onScanComplete: { style, color in
                    showingScanner = false
                    searchText = ""
                    performScan(style: style, color: color)
                })
            }
        }
    }
    
    private func performScan(style: String, color: String?) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let results = try await apiService.searchItems(style: style, color: color)
                if !results.isEmpty {
                    allItems = results
                    items = results
                    selectedStatus = "all"
                } else {
                    errorMessage = "No items found for style: \(style)" + (color != nil ? ", color: \(color!)" : "")
                }
                isLoading = false
            } catch {
                errorMessage = "Search failed: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func loadInventory() {
        isLoading = true
        errorMessage = nil
        searchText = ""
        
        Task {
            do {
                let response: PaginatedResponse<Item> = try await apiService.getInventoryByStatus(status: selectedStatus, limit: 1000)
                items = response.items
                allItems = response.items
                isLoading = false
            } catch {
                errorMessage = "Failed to load inventory: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

// MARK: - Tag Scanner View
struct TagScannerView: View {
    let onScanComplete: (String, String?) -> Void
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = TagScannerViewModel()
    
    var body: some View {
        ZStack {
            CameraPreview(session: viewModel.captureSession)
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding()
                    
                    Spacer()
                }
                
                Spacer()
                
                VStack(spacing: 20) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(viewModel.isScanning ? Color.green : Color.white, lineWidth: 3)
                            .frame(width: 300, height: 200)
                        
                        VStack(spacing: 8) {
                            Image(systemName: "tag.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                            Text("Position tag here")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    
                    if let detectedText = viewModel.detectedText, !detectedText.isEmpty {
                        VStack(spacing: 8) {
                            Text("Detected:")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                            Text(detectedText)
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(10)
                        }
                    }
                    
                    if let style = viewModel.extractedStyle {
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Style: \(style)")
                                        .font(.headline)
                                    if let color = viewModel.extractedColor {
                                        Text("Color: \(color)")
                                            .font(.subheadline)
                                    } else {
                                        Text("Color: Not detected")
                                            .font(.subheadline)
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                }
                                .foregroundColor(.white)
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color.green.opacity(0.8))
                            .cornerRadius(12)
                            
                            Button(action: {
                                onScanComplete(style, viewModel.extractedColor)
                            }) {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                    Text(viewModel.extractedColor != nil ? "Search Database" : "Search All Colors")
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            viewModel.startScanning()
        }
        .onDisappear {
            viewModel.stopScanning()
        }
    }
}

struct InventoryItemCard: View {
    let item: Item
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if let imageUrl = item.imageUrl {
                    AsyncImage(url: URL(string: "https://warehouse.obinnachukwu.org\(imageUrl)")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(width: 80, height: 80)
                    .clipped()
                    .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 80)
                        .cornerRadius(8)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.styleNumber)
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        if let status = item.status {
                            Text(status.uppercased())
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(statusColor(status).opacity(0.2))
                                .foregroundColor(statusColor(status))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(item.colorCode)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let division = item.division, let gender = item.gender {
                        Text("\(division) • \(gender)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let sourceFiles = item.sourceFiles, !sourceFiles.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.fill")
                                .font(.caption2)
                            Text("\(sourceFiles.count) file\(sourceFiles.count == 1 ? "" : "s")")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "placed": return .green
        case "showroom": return .blue
        case "waitlist": return .orange
        case "dropped": return .red
        default: return .gray
        }
    }
}

struct InventoryItemDetailView: View {
    let item: Item
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let imageUrl = item.imageUrl {
                        AsyncImage(url: URL(string: "https://warehouse.obinnachukwu.org\(imageUrl)")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                    }
                    
                    VStack(spacing: 16) {
                        DetailRow(label: "Style Number", value: item.styleNumber)
                        DetailRow(label: "Color Code", value: item.colorCode)
                        
                        if let division = item.division {
                            DetailRow(label: "Division", value: division)
                        }
                        
                        if let gender = item.gender {
                            DetailRow(label: "Gender", value: gender)
                        }
                        
                        if let outsole = item.outsole {
                            DetailRow(label: "Outsole", value: outsole)
                        }
                        
                        if let status = item.status {
                            DetailRow(label: "Status", value: status.capitalized)
                        }
                        
                        if let location = item.location {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Location")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Room: \(location.room)")
                                        .font(.subheadline)
                                        .bold()
                                    Text("Shelf: \(location.shelf)")
                                        .font(.subheadline)
                                        .bold()
                                    Text("Row: \(location.row)")
                                        .font(.subheadline)
                                        .bold()
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    if let sourceFiles = item.sourceFiles, !sourceFiles.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(.blue)
                                Text("Source Files (\(sourceFiles.count))")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                            
                            VStack(spacing: 8) {
                                ForEach(sourceFiles, id: \.self) { filename in
                                    HStack {
                                        Image(systemName: "doc.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                        Text(filename)
                                            .font(.subheadline)
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Item Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Statistics View
struct StatisticsView: View {
    @EnvironmentObject var apiService: APIService
    @State private var stats: Stats?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Button(action: loadStats) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh Statistics")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal)
                    
                    if isLoading {
                        ProgressView()
                            .padding()
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    
                    if let stats = stats {
                        VStack(spacing: 20) {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                StatCard(title: "Total Items", value: "\(stats.totalItems)", color: .blue, icon: "cube.box.fill")
                                StatCard(title: "Total Styles", value: "\(stats.totalStyles)", color: .green, icon: "tag.fill")
                                StatCard(title: "Files Processed", value: "\(stats.totalFilesProcessed)", color: .purple, icon: "doc.fill")
                            }
                            .padding(.horizontal)
                            
                            if !stats.byAction.isEmpty {
                                StatSection(title: "By Status", data: stats.byAction, icon: "checkmark.circle.fill")
                            }
                            
                            if !stats.byDivision.isEmpty {
                                StatSection(title: "By Division", data: stats.byDivision, icon: "square.grid.2x2.fill")
                            }
                            
                            if !stats.byGender.isEmpty {
                                StatSection(title: "By Gender", data: stats.byGender, icon: "person.fill")
                            }
                            
                            if !stats.byWidth.isEmpty {
                                StatSection(title: "By Width", data: stats.byWidth, icon: "ruler.fill")
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if stats == nil {
                    loadStats()
                }
            }
        }
    }
    
    private func loadStats() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                stats = try await apiService.getStats()
                isLoading = false
            } catch {
                errorMessage = "Failed to load stats: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(.white)
            
            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(12)
        .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

struct StatSection: View {
    let title: String
    let data: [String: Int]
    let icon: String
    
    var sortedData: [(String, Int)] {
        data.sorted { $0.value > $1.value }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
            }
            .padding(.horizontal)
            
            VStack(spacing: 8) {
                ForEach(sortedData, id: \.0) { key, value in
                    HStack {
                        Text(key.capitalized)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("\(value)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Analytics View
struct AnalyticsView: View {
    @EnvironmentObject var apiService: APIService
    @State private var filesData: FilesComparisonResponse?
    @State private var timelineData: TimelineResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.title2)
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Excel Files Analytics")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Comprehensive comparison and trend analysis")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    Button(action: loadAnalytics) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh Analytics")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal)
                    
                    if isLoading {
                        ProgressView()
                            .padding()
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    
                    if let filesData = filesData {
                        VStack(spacing: 20) {
                            if !filesData.files.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "doc.text.fill")
                                            .foregroundColor(.green)
                                        Text("Uploaded Files (\(filesData.totalFiles))")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                    }
                                    .padding(.horizontal)
                                    
                                    ForEach(filesData.files) { file in
                                        FileAnalyticsCard(file: file)
                                    }
                                }
                            }
                            
                            if let timeline = timelineData {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "chart.xyaxis.line")
                                            .foregroundColor(.purple)
                                        Text("Growth Trends")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                    }
                                    .padding(.horizontal)
                                    
                                    TimelineTrendsCard(timeline: timeline)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if filesData == nil {
                    loadAnalytics()
                }
            }
        }
    }
    
    private func loadAnalytics() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                async let files = apiService.getFilesComparison()
                async let timeline = apiService.getTimelineTrends()
                
                filesData = try await files
                timelineData = try await timeline
                isLoading = false
            } catch {
                errorMessage = "Failed to load analytics: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

struct FileAnalyticsCard: View {
    let file: FileAnalytics
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(file.filename)
                            .font(.headline)
                            .foregroundColor(.primary)
                        if let fileDate = file.fileDate {
                            Text(formatDate(fileDate))
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        Text("Uploaded: \(formatDate(file.uploadedAt))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(file.totalItems)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unique")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(file.uniqueItems)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Shared")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(file.sharedItems)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Styles")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(file.uniqueStyles)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                }
            }
            
            if isExpanded {
                Divider()
                
                if !file.divisions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Divisions")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        ForEach(file.divisions.sorted(by: { $0.value > $1.value }), id: \.key) { key, value in
                            HStack {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 8, height: 8)
                                Text(key)
                                    .font(.caption)
                                Spacer()
                                Text("\(value)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                
                if !file.statuses.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Status Breakdown")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        ForEach(file.statuses.sorted(by: { $0.value > $1.value }), id: \.key) { key, value in
                            HStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                Text(key.capitalized)
                                    .font(.caption)
                                Spacer()
                                Text("\(value)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

struct TimelineTrendsCard: View {
    let timeline: TimelineResponse
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Files")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(timeline.totalFiles)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unique Styles")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(timeline.finalUniqueStyles)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unique Items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(timeline.finalUniqueItems)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            if !timeline.timeline.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                        Text("Cumulative Items Growth")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    let maxValue = timeline.timeline.map { $0.cumulativeItems }.max() ?? 1
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(timeline.timeline) { point in
                            VStack {
                                Spacer()
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue, Color.blue.opacity(0.6)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(height: CGFloat(point.cumulativeItems) / CGFloat(maxValue) * 100)
                                    .cornerRadius(4)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 120)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                        Text("Cumulative Styles Growth")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    let maxStyles = timeline.timeline.map { $0.cumulativeStyles }.max() ?? 1
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(timeline.timeline) { point in
                            VStack {
                                Spacer()
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.green, Color.green.opacity(0.6)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(height: CGFloat(point.cumulativeStyles) / CGFloat(maxStyles) * 100)
                                    .cornerRadius(4)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 120)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }
}

// MARK: - Barcode Scanner View
struct BarcodeScannerView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var scanner = TagScannerViewModel()
    let onScanComplete: (BarcodeScanResult) -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                CameraPreview(session: scanner.captureSession)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        if let detectedText = scanner.detectedText {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Detected Text:")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                Text(detectedText)
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .lineLimit(3)
                            }
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                        }
                        
                        if let style = scanner.extractedStyle {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Style Number")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                    Text(style)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                                
                                if let color = scanner.extractedColor {
                                    Divider()
                                        .background(Color.white)
                                        .frame(height: 40)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Color Code")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.8))
                                        Text(color)
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    let result = BarcodeScanResult(
                                        success: true,
                                        styleNumber: style,
                                        message: "Scanned successfully"
                                    )
                                    onScanComplete(result)
                                    dismiss()
                                }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.green)
                                }
                            }
                            .padding()
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(15)
                        } else {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Scanning for tag...")
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                }
                
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                                .shadow(radius: 3)
                        }
                        .padding()
                    }
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                scanner.startScanning()
            }
            .onDisappear {
                scanner.stopScanning()
            }
        }
    }
}
