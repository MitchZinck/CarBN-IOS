import Foundation

struct CarUpgrade: Codable {
    let id: Int
    let upgradeType: String
    let active: Bool
    let metadata: CarUpgradeMetadata?
    let createdAt: Date
    let updatedAt: Date
    
    private enum CodingKeys: String, CodingKey {
        case id
        case upgradeType = "upgrade_type"
        case active
        case metadata
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        upgradeType = try container.decode(String.self, forKey: .upgradeType)
        active = try container.decode(Bool.self, forKey: .active)
        metadata = try container.decodeIfPresent(CarUpgradeMetadata.self, forKey: .metadata)
        
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        let updatedAtString = try container.decode(String.self, forKey: .updatedAt)
        
        // Try parsing with any of our supported date formats
        if let createdAtDate = createdAtString.toDate() {
            createdAt = createdAtDate
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: container.codingPath + [CodingKeys.createdAt],
                debugDescription: "Invalid date format"
            ))
        }
        
        if let updatedAtDate = updatedAtString.toDate() {
            updatedAt = updatedAtDate
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: container.codingPath + [CodingKeys.updatedAt],
                debugDescription: "Invalid date format"
            ))
        }
    }
    
    init(id: Int, upgradeType: String, active: Bool, metadata: CarUpgradeMetadata?, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.upgradeType = upgradeType
        self.active = active
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(upgradeType, forKey: .upgradeType)
        try container.encode(active, forKey: .active)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encode(createdAt.rfc3339String(), forKey: .createdAt)
        try container.encode(updatedAt.rfc3339String(), forKey: .updatedAt)
    }
}

struct CarUpgradeMetadata: Codable {
    let originalLowRes: String?
    let originalHighRes: String?
    
    private enum CodingKeys: String, CodingKey {
        case originalLowRes = "original_low_res"
        case originalHighRes = "original_high_res"
    }
}