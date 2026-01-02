import SwiftUI
import AVFoundation

// MARK: - Bulk Location Scan View
struct BulkLocationScanView: View {
    @EnvironmentObject var apiService: APIService
    @Environment(\.dismiss) var dismiss
    
    @State private var rooms: [Room] = []
    @State private var shelves: [Shelf] = []
    @State private var rows: [Row] = []
    
    @State private var selectedRoomId: Int?
    @State private var selectedShelfId: Int?
    @State private var selectedRowId: Int?
    
    @State private var showingScanner = false
    @State private var scannedItems: [ScannedItemRecord] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    @State private var currentScanningItem: ScannedItemRecord?
    
    struct ScannedItemRecord: Identifiable {
        let id = UUID()
        let styleNumber: String
        let colorCode: String?
        let timestamp: Date
        var isAssigned: Bool = false
        var assignmentError: String?
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Location Selection Section
                VStack(spacing: 16) {
                    Text("Select Target Location")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 12) {
                        Picker("Room", selection: $selectedRoomId) {
                            Text("Select Room").tag(nil as Int?)
                            ForEach(rooms) { room in
                                Text(room.name).tag(room.id as Int?)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .onChange(of: selectedRoomId) { _ in
                            loadShelves()
                            selectedShelfId = nil
                            selectedRowId = nil
                        }
                        
                        Picker("Shelf", selection: $selectedShelfId) {
                            Text("Select Shelf").tag(nil as Int?)
                            ForEach(shelves) { shelf in
                                Text(shelf.name).tag(shelf.id as Int?)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .disabled(selectedRoomId == nil)
                        .onChange(of: selectedShelfId) { _ in
                            loadRows()
                            selectedRowId = nil
                        }
                        
                        Picker("Row", selection: $selectedRowId) {
                            Text("Select Row").tag(nil as Int?)
                            ForEach(rows) { row in
                                Text(row.name).tag(row.id as Int?)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .disabled(selectedShelfId == nil)
                    }
                    
                    if let roomId = selectedRoomId,
                       let shelfId = selectedShelfId,
                       let rowId = selectedRowId {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Location: \(getLocationPath())")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                
                Divider()
                
                // Scanning Section
                VStack(spacing: 16) {
                    HStack {
                        Text("Scanned Items")
                            .font(.headline)
                        Spacer()
                        Text("\(scannedItems.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: {
                        if selectedRowId != nil {
                            showingScanner = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Start Scanning")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedRowId != nil ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(selectedRowId == nil)
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    if let success = successMessage {
                        Text(success)
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding()
                
                // Scanned Items List
                if !scannedItems.isEmpty {
                    List {
                        ForEach(scannedItems) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Style: \(item.styleNumber)")
                                        .font(.headline)
                                    if let color = item.colorCode {
                                        Text("Color: \(color)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    Text(item.timestamp.formatted(date: .omitted, time: .shortened))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if item.isAssigned {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.title2)
                                } else if let error = item.assignmentError {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                        .font(.title2)
                                } else {
                                    ProgressView()
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: deleteItems)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No items scanned yet")
                            .foregroundColor(.secondary)
                        Text("Select a location and start scanning")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .navigationTitle("Bulk Location Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear All") {
                        scannedItems.removeAll()
                        successMessage = nil
                        errorMessage = nil
                    }
                    .disabled(scannedItems.isEmpty)
                }
            }
            .sheet(isPresented: $showingScanner) {
                BulkScannerView { result in
                    if let style = result.styleNumber {
                        handleScannedItem(styleNumber: style, colorCode: nil)
                    }
                }
            }
            .onAppear {
                loadRooms()
            }
        }
    }
    
    private func getLocationPath() -> String {
        guard let roomId = selectedRoomId,
              let shelfId = selectedShelfId,
              let rowId = selectedRowId else {
            return ""
        }
        
        let roomName = rooms.first(where: { $0.id == roomId })?.name ?? ""
        let shelfName = shelves.first(where: { $0.id == shelfId })?.name ?? ""
        let rowName = rows.first(where: { $0.id == rowId })?.name ?? ""
        
        return "\(roomName) > \(shelfName) > \(rowName)"
    }
    
    private func handleScannedItem(styleNumber: String, colorCode: String?) {
        let newItem = ScannedItemRecord(
            styleNumber: styleNumber,
            colorCode: colorCode,
            timestamp: Date(),
            isAssigned: false
        )
        
        scannedItems.insert(newItem, at: 0)
        
        // Automatically assign to selected location
        assignItemToLocation(item: newItem)
    }
    
    private func assignItemToLocation(item: ScannedItemRecord) {
        guard let rowId = selectedRowId else { return }
        
        Task {
            do {
                // Search for the item first
                let items = try await apiService.searchItems(style: item.styleNumber, color: item.colorCode)
                
                if let foundItem = items.first {
                    // Construct proper item_id in format: style_color
                    let itemId = "\(foundItem.styleNumber)_\(foundItem.colorCode)"
                    
                    // Assign to location
                    try await apiService.updateItemLocation(itemId: itemId, rowId: rowId)
                    
                    // Update the record
                    if let index = scannedItems.firstIndex(where: { $0.id == item.id }) {
                        scannedItems[index].isAssigned = true
                    }
                    
                    successMessage = "✓ \(item.styleNumber) assigned successfully"
                    
                    // Clear success message after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        successMessage = nil
                    }
                } else {
                    // Item not found
                    if let index = scannedItems.firstIndex(where: { $0.id == item.id }) {
                        scannedItems[index].assignmentError = "Item not found in inventory"
                    }
                    errorMessage = "Item \(item.styleNumber) not found in inventory"
                }
            } catch {
                // Assignment failed
                if let index = scannedItems.firstIndex(where: { $0.id == item.id }) {
                    scannedItems[index].assignmentError = error.localizedDescription
                }
                errorMessage = "Failed to assign \(item.styleNumber): \(error.localizedDescription)"
            }
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        scannedItems.remove(atOffsets: offsets)
    }
    
    private func loadRooms() {
        Task {
            do {
                rooms = try await apiService.getRooms()
            } catch {
                errorMessage = "Failed to load rooms: \(error.localizedDescription)"
            }
        }
    }
    
    private func loadShelves() {
        guard let roomId = selectedRoomId else {
            shelves = []
            return
        }
        
        Task {
            do {
                shelves = try await apiService.getShelves()
                shelves = shelves.filter { $0.roomId == roomId }
            } catch {
                errorMessage = "Failed to load shelves: \(error.localizedDescription)"
            }
        }
    }
    
    private func loadRows() {
        guard let shelfId = selectedShelfId else {
            rows = []
            return
        }
        
        Task {
            do {
                rows = try await apiService.getRows()
                rows = rows.filter { $0.shelfId == shelfId }
            } catch {
                errorMessage = "Failed to load rows: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Bulk Scanner View
struct BulkScannerView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var scanner = TagScannerViewModel()
    @State private var selectedColor: String?
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
                            VStack(spacing: 12) {
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
                                    
                                    if let color = selectedColor ?? scanner.extractedColor {
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
                                        
                                        // Reset scanner for next scan
                                        scanner.extractedStyle = nil
                                        scanner.extractedColor = nil
                                        scanner.detectedText = nil
                                        scanner.allDetectedColors = []
                                        scanner.multipleColorsDetected = false
                                        selectedColor = nil
                                    }) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.green)
                                    }
                                }
                                
                                // Show color picker if multiple colors detected
                                if scanner.multipleColorsDetected && !scanner.allDetectedColors.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.yellow)
                                            Text("Multiple colors detected - Choose one:")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                        }
                                        
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 8) {
                                                ForEach(scanner.allDetectedColors, id: \.self) { color in
                                                    Button(action: {
                                                        selectedColor = color
                                                        scanner.extractedColor = color
                                                    }) {
                                                        Text(color)
                                                            .font(.caption)
                                                            .fontWeight(.semibold)
                                                            .padding(.horizontal, 12)
                                                            .padding(.vertical, 6)
                                                            .background((selectedColor ?? scanner.extractedColor) == color ? Color.blue : Color.white.opacity(0.3))
                                                            .foregroundColor(.white)
                                                            .cornerRadius(8)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .padding(.top, 8)
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
                        
                        Text(scanner.multipleColorsDetected ? "Select correct color, then tap ✓" : "Tap ✓ to add item and continue scanning")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal)
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
