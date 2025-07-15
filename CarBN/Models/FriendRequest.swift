import Foundation

enum FriendRequestState: String, Codable {
    case pending
    case accepted
    case rejected
}

struct FriendRequest: Identifiable, Codable {
    let id: Int
    let userId: Int
    let userName: String
    let userProfilePicture: String?
    let friendProfilePicture: String?
    let friendId: Int
    let friendDisplayName: String
    
    // Map the server's "ID" to our "id" property
    private enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case userName = "user_display_name"
        case userProfilePicture = "user_profile_picture"
        case friendProfilePicture = "friend_profile_picture"
        case friendId = "friend_id"
        case friendDisplayName = "friend_display_name"
    }
}

struct FriendRequestResponse: Codable {
    let requestId: Int
    let response: String

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case response
    }
}

struct SendFriendRequest: Codable {
    let friendId: Int

    enum CodingKeys: String, CodingKey {
        case friendId = "friend_id"
    }
}