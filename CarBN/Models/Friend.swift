import Foundation

struct Friend: Codable, Equatable, Identifiable {
    let id: Int
    let displayName: String
    let profilePicture: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case profilePicture = "profile_picture"
    }
}

struct FriendsResponse: Codable {
    let friends: [Friend]?
    let total: Int
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case friends
        case total
        case hasMore = "has_more"
    }
}
