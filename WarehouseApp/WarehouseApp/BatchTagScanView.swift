import SwiftUI
import AVFoundation

struct ScannedItem: Identifiable, Codable {
    var id = UUID()
    var styleNumber: String
    var color: String
    let timestamp: Date
}

struct BatchTagScanView: View {
    @StateObject private var scanner = TagScannerViewModel()
    @State private var scannedItems: [ScannedItem] = []
    @State private var isScanning = false
    @State private var showingExportSheet = false
    @State private var exportURL: URL?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var editingItem: ScannedItem?
    @State private var showingEditSheet = false
    @State private var isExporting = false
    @Environment(\.dismiss) var dismiss
    
    private let storageKey = "BatchScannedItems"
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isScanning {
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
                                
                                if let style = scanner.extractedStyle, let color = scanner.extractedColor {
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
                                        
                                        Spacer()
                                        
                                        Button(action: addScannedItem) {
                                            Image(systemName: "plus.circle.fill")
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
                                Button(action: stopScanning) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 36))
                                        .foregroundColor(.white)
                                        .shadow(radius: 3)
                                }
                                .padding()
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("\(scannedItems.count) items")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.green)
                                        .cornerRadius(20)
                                }
                                .padding()
                            }
                            Spacer()
                        }
                    }
                } else {
                    VStack(spacing: 20) {
                        if scannedItems.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "barcode.viewfinder")
                                    .font(.system(size: 80))
                                    .foregroundColor(.gray)
                                
                                Text("Batch Tag Scanner")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("Scan multiple tags and export to CSV")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Button(action: startScanning) {
                                    HStack {
                                        Image(systemName: "camera.fill")
                                        Text("Start Scanning")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                                .padding(.horizontal)
                            }
                            .padding()
                        } else {
                            VStack(spacing: 16) {
                                HStack {
                                    Text("\(scannedItems.count) Items Scanned")
                                        .font(.headline)
                                    Spacer()
                                    Button(action: clearAll) {
                                        Text("Clear All")
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding(.horizontal)
                                
                                List {
                                    ForEach(scannedItems) { item in
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(item.styleNumber)
                                                    .font(.headline)
                                                Text(item.color)
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            Text(item.timestamp, style: .time)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Button(action: {
                                                editingItem = item
                                                showingEditSheet = true
                                            }) {
                                                Image(systemName: "pencil.circle.fill")
                                                    .foregroundColor(.blue)
                                                    .font(.title3)
                                            }
                                        }
                                    }
                                    .onDelete(perform: deleteItems)
                                }
                                
                                VStack(spacing: 12) {
                                    Button(action: startScanning) {
                                        HStack {
                                            Image(systemName: "camera.fill")
                                            Text("Scan More")
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                    }
                                    
                                    Button(action: exportToCSV) {
                                        HStack {
                                            if isExporting {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                Text("Preparing...")
                                            } else {
                                                Image(systemName: "square.and.arrow.up")
                                                Text("Export CSV")
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.green)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                    }
                                    .disabled(isExporting)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Batch Tag Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingExportSheet) {
                if let url = exportURL {
                    ActivityViewController(activityItems: [url])
                }
            }
            .alert("Export", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showingEditSheet) {
                if let item = editingItem {
                    EditItemView(item: item) { updatedItem in
                        if let index = scannedItems.firstIndex(where: { $0.id == updatedItem.id }) {
                            scannedItems[index] = updatedItem
                            saveItems()
                        }
                        showingEditSheet = false
                    }
                }
            }
            .onAppear {
                loadItems()
            }
        }
    }
    
    private func startScanning() {
        isScanning = true
        scanner.startScanning()
    }
    
    private func stopScanning() {
        isScanning = false
        scanner.stopScanning()
    }
    
    private func addScannedItem() {
        guard let style = scanner.extractedStyle,
              let color = scanner.extractedColor else {
            return
        }
        
        let item = ScannedItem(
            styleNumber: style,
            color: color,
            timestamp: Date()
        )
        
        scannedItems.append(item)
        saveItems()
        
        scanner.extractedStyle = nil
        scanner.extractedColor = nil
        scanner.detectedText = nil
    }
    
    private func deleteItems(at offsets: IndexSet) {
        scannedItems.remove(atOffsets: offsets)
        saveItems()
    }
    
    private func clearAll() {
        scannedItems.removeAll()
        saveItems()
    }
    
    private func exportToCSV() {
        guard !scannedItems.isEmpty else {
            alertMessage = "No items to export"
            showingAlert = true
            return
        }
        
        isExporting = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            var csvString = "stylenumber,color\n"
            
            for item in self.scannedItems {
                csvString += "\(item.styleNumber),\(item.color)\n"
            }
            
            let fileName = "scanned_tags_\(Date().timeIntervalSince1970).csv"
            let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            do {
                try csvString.write(to: path, atomically: true, encoding: .utf8)
                
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.exportURL = path
                    self.showingExportSheet = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.alertMessage = "Failed to export CSV: \(error.localizedDescription)"
                    self.showingAlert = true
                }
            }
        }
    }
    
    private func saveItems() {
        if let encoded = try? JSONEncoder().encode(scannedItems) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadItems() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ScannedItem].self, from: data) {
            scannedItems = decoded
        }
    }
}

struct EditItemView: View {
    let item: ScannedItem
    let onSave: (ScannedItem) -> Void
    
    @State private var styleNumber: String
    @State private var color: String
    @Environment(\.dismiss) var dismiss
    
    init(item: ScannedItem, onSave: @escaping (ScannedItem) -> Void) {
        self.item = item
        self.onSave = onSave
        _styleNumber = State(initialValue: item.styleNumber)
        _color = State(initialValue: item.color)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Style Number")) {
                    TextField("Style Number", text: $styleNumber)
                        .keyboardType(.numberPad)
                        .font(.title3)
                }
                
                Section(header: Text("Color Code")) {
                    TextField("Color Code", text: $color)
                        .textCase(.uppercase)
                        .autocapitalization(.allCharacters)
                        .font(.title3)
                }
                
                Section {
                    HStack {
                        Text("Scanned at:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(item.timestamp, style: .time)
                    }
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        var updatedItem = item
                        updatedItem.styleNumber = styleNumber.trimmingCharacters(in: .whitespaces)
                        updatedItem.color = color.uppercased().trimmingCharacters(in: .whitespaces)
                        onSave(updatedItem)
                    }
                    .disabled(styleNumber.trimmingCharacters(in: .whitespaces).isEmpty || color.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
