import Foundation

enum FeedItemType: String, Codable {
    case carScanned = "car_scanned"
    case tradeCompleted = "trade_completed"
    case friendAccepted = "friend_accepted"
}

struct FeedItem: Identifiable, Codable {
    let id: Int
    let userId: Int
    let type: FeedItemType
    let referenceId: Int
    let createdAt: Date
    let relatedUserId: Int?
    var likeCount: Int  // Changed from let to var
    
    // Non-serialized properties for user details
    var userName: String?
    var relatedUserName: String?
    var userProfilePicture: String?
    var relatedUserProfilePicture: String?
    var isLikedByCurrentUser: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type
        case referenceId = "reference_id"
        case createdAt = "created_at"
        case relatedUserId = "related_user_id"
        case likeCount = "like_count"
        case isLikedByCurrentUser = "user_liked"
    }
    
    // Custom initializer for creating FeedItem instances programmatically
    init(id: Int, userId: Int, type: FeedItemType, referenceId: Int, createdAt: Date, relatedUserId: Int?, likeCount: Int, userLiked: Bool) {
        self.id = id
        self.userId = userId
        self.type = type
        self.referenceId = referenceId
        self.createdAt = createdAt
        self.relatedUserId = relatedUserId
        self.likeCount = likeCount
        self.userName = nil
        self.relatedUserName = nil
        self.userProfilePicture = nil
        self.relatedUserProfilePicture = nil
        self.isLikedByCurrentUser = userLiked
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        userId = try container.decode(Int.self, forKey: .userId)
        type = try container.decode(FeedItemType.self, forKey: .type)
        referenceId = try container.decode(Int.self, forKey: .referenceId)
        likeCount = try container.decode(Int.self, forKey: .likeCount)
        isLikedByCurrentUser = try container.decodeIfPresent(Bool.self, forKey: .isLikedByCurrentUser) ?? false
        
        let dateString = try container.decode(String.self, forKey: .createdAt)
        if let date = dateString.toDate() {
            createdAt = date
        } else {
            throw DecodingError.dataCorruptedError(forKey: .createdAt, in: container, debugDescription: "Date string does not match expected TIMESTAMPTZ format")
        }
        
        relatedUserId = try container.decodeIfPresent(Int.self, forKey: .relatedUserId)
        userName = nil
        relatedUserName = nil
    }

    // Add encoding support
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(type, forKey: .type)
        try container.encode(referenceId, forKey: .referenceId)
        try container.encode(createdAt.rfc3339String(), forKey: .createdAt)
        try container.encodeIfPresent(relatedUserId, forKey: .relatedUserId)
        try container.encode(likeCount, forKey: .likeCount)
        try container.encodeIfPresent(isLikedByCurrentUser, forKey: .isLikedByCurrentUser) 
    }
}

struct FeedResponse: Codable {
    let items: [FeedItem]
    let nextCursor: String?
    
    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }
}
