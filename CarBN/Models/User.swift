import Foundation

struct User: Codable, Identifiable {
    let id: Int
    let email: String?
    var displayName: String
    let friendCount: Int
    let profilePicture: String?
    var currency: Int
    let carScore: Int?
    let carCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case friendCount = "friend_count"
        case profilePicture = "profile_picture"
        case currency
        case carScore = "car_score"
        case carCount = "car_count"
    }
    
    // Helper method to check subscription status
    func checkSubscriptionStatus() async -> Bool {
        do {
            return try await SubscriptionService.shared.getUserSubscriptionStatus(userId: id)
        } catch {
            return false
        }
    }
}