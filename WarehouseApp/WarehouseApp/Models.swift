import Foundation

struct Item: Codable, Identifiable {
    let id: String
    let styleNumber: String
    let colorCode: String
    let division: String?
    let gender: String?
    let description: String?
    let status: String?
    let rowId: Int?
    let imageUrl: String?
    let location: ItemLocation?
    let sourceFiles: [String]?
    let outsole: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case styleNumber = "style_number"
        case colorCode = "color_code"
        case division
        case gender
        case description
        case status
        case rowId = "row_id"
        case imageUrl = "image_url"
        case location
        case style
        case color
        case outsole
        case sourceFiles = "source_files"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let idInt = try? container.decode(Int.self, forKey: .id) {
            id = String(idInt)
        } else {
            id = try container.decode(String.self, forKey: .id)
        }
        
        if let style = try? container.decode(String.self, forKey: .style) {
            styleNumber = style
        } else {
            styleNumber = try container.decode(String.self, forKey: .styleNumber)
        }
        
        if let color = try? container.decode(String.self, forKey: .color) {
            colorCode = color
        } else {
            colorCode = try container.decode(String.self, forKey: .colorCode)
        }
        
        division = try? container.decode(String.self, forKey: .division)
        gender = try? container.decode(String.self, forKey: .gender)
        description = try? container.decode(String.self, forKey: .description)
        status = try? container.decode(String.self, forKey: .status)
        rowId = try? container.decode(Int.self, forKey: .rowId)
        imageUrl = try? container.decode(String.self, forKey: .imageUrl)
        location = try? container.decode(ItemLocation.self, forKey: .location)
        sourceFiles = try? container.decode([String].self, forKey: .sourceFiles)
        outsole = try? container.decode(String.self, forKey: .outsole)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(styleNumber, forKey: .styleNumber)
        try container.encode(colorCode, forKey: .colorCode)
        try container.encodeIfPresent(division, forKey: .division)
        try container.encodeIfPresent(gender, forKey: .gender)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(rowId, forKey: .rowId)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(sourceFiles, forKey: .sourceFiles)
        try container.encodeIfPresent(outsole, forKey: .outsole)
    }
}

struct Room: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let shelfCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case shelfCount = "shelf_count"
    }
}

struct Shelf: Codable, Identifiable {
    let id: Int
    let roomId: Int
    let roomName: String
    let name: String
    let description: String?
    let rowCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case roomId = "room_id"
        case roomName = "room_name"
        case name
        case description
        case rowCount = "row_count"
    }
}

struct Row: Codable, Identifiable {
    let id: Int
    let shelfId: Int
    let shelfName: String
    let roomName: String
    let name: String
    let description: String?
    let itemCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case shelfId = "shelf_id"
        case shelfName = "shelf_name"
        case roomName = "room_name"
        case name
        case description
        case itemCount = "item_count"
    }
}

struct WarehouseLayout: Codable {
    let warehouseLayout: [RoomLayout]
    
    enum CodingKeys: String, CodingKey {
        case warehouseLayout = "warehouse_layout"
    }
}

struct RoomLayout: Codable, Identifiable {
    let id: Int
    let name: String
    let shelves: [ShelfLayout]
}

struct ShelfLayout: Codable, Identifiable {
    let id: Int
    let name: String
    let rows: [RowLayout]
}

struct RowLayout: Codable, Identifiable {
    let id: Int
    let name: String
    let items: [Item]
}

struct Stats: Codable {
    let totalItems: Int
    let totalStyles: Int
    let totalFilesProcessed: Int
    let byAction: [String: Int]
    let byDivision: [String: Int]
    let byGender: [String: Int]
    let byWidth: [String: Int]
    
    enum CodingKeys: String, CodingKey {
        case totalItems = "total_items"
        case totalStyles = "total_styles"
        case totalFilesProcessed = "total_files_processed"
        case byAction = "by_action"
        case byDivision = "by_division"
        case byGender = "by_gender"
        case byWidth = "by_width"
    }
}

struct PaginatedResponse<T: Codable>: Codable {
    let items: [T]
    let total: Int
    let limit: Int
    let offset: Int
}

struct SearchResult: Codable {
    let items: [Item]
}

struct ItemProfile: Codable {
    let id: String
    let styleNumber: String
    let colorCode: String
    let division: String?
    let gender: String?
    let description: String?
    let status: String?
    let imageUrl: String?
    let location: LocationInfo?
    
    enum CodingKeys: String, CodingKey {
        case id
        case styleNumber = "style_number"
        case colorCode = "color_code"
        case division
        case gender
        case description
        case status
        case imageUrl = "image_url"
        case location
    }
}

struct LocationInfo: Codable {
    let roomName: String
    let shelfName: String
    let rowName: String
    
    enum CodingKeys: String, CodingKey {
        case roomName = "room_name"
        case shelfName = "shelf_name"
        case rowName = "row_name"
    }
}

struct CreateRoomRequest: Codable {
    let name: String
    let description: String?
}

struct CreateShelfRequest: Codable {
    let roomId: Int
    let name: String
    let description: String?
    
    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case name
        case description
    }
}

struct CreateRowRequest: Codable {
    let shelfId: Int
    let name: String
    let description: String?
    
    enum CodingKeys: String, CodingKey {
        case shelfId = "shelf_id"
        case name
        case description
    }
}

struct UpdateLocationRequest: Codable {
    let rowId: Int?
    
    enum CodingKeys: String, CodingKey {
        case rowId = "row_id"
    }
}

struct BarcodeScanResult: Codable {
    let success: Bool
    let styleNumber: String?
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case styleNumber = "style_number"
        case message
    }
}

struct DroppedReport: Codable {
    let totalDropped: Int
    let withLocation: Int
    let withoutLocation: Int
    let itemsByLocation: [String: [DroppedItem]]
    let itemsWithoutLocation: [DroppedItem]
    
    enum CodingKeys: String, CodingKey {
        case totalDropped = "total_dropped"
        case withLocation = "with_location"
        case withoutLocation = "without_location"
        case itemsByLocation = "items_by_location"
        case itemsWithoutLocation = "items_without_location"
    }
}

struct DroppedItem: Codable, Identifiable {
    let id: Int
    let style: String
    let color: String
    let division: String?
    let gender: String?
    let location: ItemLocation?
}

struct ItemLocation: Codable {
    let room: String
    let shelf: String
    let row: String
}

struct FilesComparisonResponse: Codable {
    let files: [FileAnalytics]
    let totalFiles: Int
    
    enum CodingKeys: String, CodingKey {
        case files
        case totalFiles = "total_files"
    }
}

struct FileAnalytics: Codable, Identifiable {
    var id: String { filename }
    let filename: String
    let fileDate: String?
    let uploadedAt: String
    let totalItems: Int
    let uniqueItems: Int
    let sharedItems: Int
    let uniqueStyles: Int
    let divisions: [String: Int]
    let genders: [String: Int]
    let statuses: [String: Int]
    let widths: [String: Int]
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case filename
        case fileDate = "file_date"
        case uploadedAt = "uploaded_at"
        case totalItems = "total_items"
        case uniqueItems = "unique_items"
        case sharedItems = "shared_items"
        case uniqueStyles = "unique_styles"
        case divisions
        case genders
        case statuses
        case widths
        case status
    }
}

struct TimelineResponse: Codable {
    let timeline: [TimelinePoint]
    let totalFiles: Int
    let finalUniqueStyles: Int
    let finalUniqueItems: Int
    
    enum CodingKeys: String, CodingKey {
        case timeline
        case totalFiles = "total_files"
        case finalUniqueStyles = "final_unique_styles"
        case finalUniqueItems = "final_unique_items"
    }
}

struct TimelinePoint: Codable, Identifiable {
    var id: String { filename }
    let filename: String
    let fileDate: String?
    let uploadedAt: String
    let itemsInFile: Int
    let stylesInFile: Int
    let newStyles: Int
    let newItems: Int
    let cumulativeStyles: Int
    let cumulativeItems: Int
    
    enum CodingKeys: String, CodingKey {
        case filename
        case fileDate = "file_date"
        case uploadedAt = "uploaded_at"
        case itemsInFile = "items_in_file"
        case stylesInFile = "styles_in_file"
        case newStyles = "new_styles"
        case newItems = "new_items"
        case cumulativeStyles = "cumulative_styles"
        case cumulativeItems = "cumulative_items"
    }
}

struct MessageResponse: Codable {
    let message: String
    let success: Bool?
}
