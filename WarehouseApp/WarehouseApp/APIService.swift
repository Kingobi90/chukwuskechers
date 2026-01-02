import Foundation
import SwiftUI

class APIService: ObservableObject {
    private let baseURL = "https://warehouse.obinnachukwu.org"
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            request.httpBody = body
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        return try decoder.decode(T.self, from: data)
    }
    
    func healthCheck() async throws -> Bool {
        let _: MessageResponse = try await request(endpoint: "/health")
        return true
    }
    
    func getRooms() async throws -> [Room] {
        return try await request(endpoint: "/locations/rooms")
    }
    
    func createRoom(name: String, description: String?) async throws -> Room {
        let body = CreateRoomRequest(name: name, description: description)
        let data = try encoder.encode(body)
        return try await request(endpoint: "/locations/rooms", method: "POST", body: data)
    }
    
    func deleteRoom(id: Int) async throws {
        let _: MessageResponse = try await request(endpoint: "/locations/rooms/\(id)", method: "DELETE")
    }
    
    func getShelves(roomId: Int? = nil) async throws -> [Shelf] {
        let endpoint = roomId != nil ? "/locations/shelves?room_id=\(roomId!)" : "/locations/shelves"
        return try await request(endpoint: endpoint)
    }
    
    func createShelf(roomId: Int, name: String, description: String?) async throws -> Shelf {
        let body = CreateShelfRequest(roomId: roomId, name: name, description: description)
        let data = try encoder.encode(body)
        return try await request(endpoint: "/locations/shelves", method: "POST", body: data)
    }
    
    func deleteShelf(id: Int) async throws {
        let _: MessageResponse = try await request(endpoint: "/locations/shelves/\(id)", method: "DELETE")
    }
    
    func getRows(shelfId: Int? = nil) async throws -> [Row] {
        let endpoint = shelfId != nil ? "/locations/rows?shelf_id=\(shelfId!)" : "/locations/rows"
        return try await request(endpoint: endpoint)
    }
    
    func createRow(shelfId: Int, name: String, description: String?) async throws -> Row {
        let body = CreateRowRequest(shelfId: shelfId, name: name, description: description)
        let data = try encoder.encode(body)
        return try await request(endpoint: "/locations/rows", method: "POST", body: data)
    }
    
    func deleteRow(id: Int) async throws {
        let _: MessageResponse = try await request(endpoint: "/locations/rows/\(id)", method: "DELETE")
    }
    
    func getWarehouseLayout() async throws -> WarehouseLayout {
        return try await request(endpoint: "/warehouse/visual-layout")
    }
    
    func searchItems(style: String? = nil, color: String? = nil, limit: Int = 50) async throws -> [Item] {
        var components = URLComponents(string: "\(baseURL)/items/search")!
        var queryItems: [URLQueryItem] = []
        
        if let style = style, !style.isEmpty {
            queryItems.append(URLQueryItem(name: "style", value: style))
        }
        if let color = color, !color.isEmpty {
            queryItems.append(URLQueryItem(name: "color", value: color))
        }
        queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try decoder.decode([Item].self, from: data)
    }
    
    func getInventoryByStatus(status: String, limit: Int = 100, offset: Int = 0) async throws -> PaginatedResponse<Item> {
        let endpoint = status == "all" 
            ? "/inventory/search?limit=\(limit)&offset=\(offset)"
            : "/inventory/by-action/\(status)?limit=\(limit)&offset=\(offset)"
        return try await request(endpoint: endpoint)
    }
    
    func getStats() async throws -> Stats {
        return try await request(endpoint: "/inventory/stats")
    }
    
    func getItemProfile(itemId: String) async throws -> ItemProfile {
        return try await request(endpoint: "/items/\(itemId)/profile")
    }
    
    func updateItemLocation(itemId: String, rowId: Int?) async throws {
        let body = UpdateLocationRequest(rowId: rowId)
        let data = try encoder.encode(body)
        let _: MessageResponse = try await request(endpoint: "/items/\(itemId)/location", method: "PUT", body: data)
    }
    
    func scanBarcode(imageData: Data) async throws -> BarcodeScanResult {
        guard let url = URL(string: "\(baseURL)/scan-barcode") else {
            throw URLError(.badURL)
        }
        
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode(BarcodeScanResult.self, from: data)
    }
    
    func scanTag(imageData: Data) async throws -> BarcodeScanResult {
        guard let url = URL(string: "\(baseURL)/scan-tag") else {
            throw URLError(.badURL)
        }
        
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode(BarcodeScanResult.self, from: data)
    }
    
    func getDroppedReport() async throws -> DroppedReport {
        return try await request(endpoint: "/dropped-items/report")
    }
    
    func getFilesComparison() async throws -> FilesComparisonResponse {
        return try await request(endpoint: "/analytics/files/comparison")
    }
    
    func getTimelineTrends() async throws -> TimelineResponse {
        return try await request(endpoint: "/analytics/trends/timeline")
    }
}
