import Foundation
struct FriendshipStatusResponse: Decodable {
    let isFriend: Bool

    enum CodingKeys: String, CodingKey {
        case isFriend = "is_friend"
    }
}