import Foundation

// Unified Like model for all like types (feed items and car likes)
struct Like: Codable {
    let id: Int
    let userId: Int
    let targetId: Int
    let targetType: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case targetId = "target_id"
        case targetType = "target_type"
        case createdAt = "created_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        userId = try container.decode(Int.self, forKey: .userId)
        targetId = try container.decode(Int.self, forKey: .targetId)
        targetType = try container.decode(String.self, forKey: .targetType)
        
        let dateString = try container.decode(String.self, forKey: .createdAt)
        if let date = dateString.toDate() {
            createdAt = date
        } else {
            throw DecodingError.dataCorruptedError(forKey: .createdAt, in: container, debugDescription: "Date string does not match expected ISO8601 format")
        }
    }
    
    // Helper property to determine if this is a feed item like
    var isFeedItemLike: Bool {
        return targetType == "feed_item"
    }
    
    // Helper property to determine if this is a car like
    var isCarLike: Bool {
        return targetType == "user_car"
    }
    
    // For backward compatibility with code that expects a feedItemId
    var feedItemId: Int? {
        return isFeedItemLike ? targetId : nil
    }
    
    // For backward compatibility with code that expects a userCarId
    var userCarId: Int? {
        return isCarLike ? targetId : nil
    }
}

struct LikesResponse: Codable {
    let items: [Like]
    let nextCursor: String?
    
    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }
}

struct CarLikeCheckResponse: Codable {
    let liked: Bool
}

struct LikeCountResponse: Codable {
    let count: Int
}

@MainActor
final class LikeService {
    static let shared = LikeService()
    private init() {}
    
    func likeFeedItem(_ feedItemId: Int) async throws -> Like {
        Logger.info("Liking feed item: \(feedItemId)")
        do {
            let like: Like = try await APIClient.shared.post(
                endpoint: "/likes/\(feedItemId)",
                body: EmptyRequest()
            )
            Logger.info("Successfully liked feed item \(feedItemId)")
            return like
        } catch let error as APIError {
            switch error {
            case .httpError(409, _):
                Logger.error("Feed item \(feedItemId) already liked")
                throw error
            default:
                Logger.error("Failed to like feed item \(feedItemId): \(error)")
                throw error
            }
        }
    }
    
    func unlikeFeedItem(_ feedItemId: Int) async throws {
        Logger.info("Unliking feed item: \(feedItemId)")
        do {
            let _: EmptyResponse = try await APIClient.shared.delete(
                endpoint: "/likes/\(feedItemId)"
            )
            Logger.info("Successfully unliked feed item \(feedItemId)")
        } catch {
            Logger.error("Failed to unlike feed item \(feedItemId): \(error)")
            throw error
        }
    }
    
    func getUserReceivedLikes(userId: Int, pageSize: Int = 10, cursor: String? = nil) async throws -> LikesResponse {
        Logger.info("Fetching received likes for user \(userId)")
        var endpoint = "/likes/user/\(userId)?page_size=\(pageSize)"
        if let cursor {
            endpoint += "&cursor=\(cursor)"
        }
        
        do {
            let response: LikesResponse = try await APIClient.shared.get(endpoint: endpoint)
            Logger.info("Successfully fetched \(response.items.count) received likes for user \(userId)")
            return response
        } catch {
            Logger.error("Failed to fetch received likes for user \(userId): \(error)")
            throw error
        }
    }
    
    // MARK: - Car Like Methods
    
    func likeCar(_ userCarId: Int) async throws -> Like {
        Logger.info("Liking car: \(userCarId)")
        do {
            let like: Like = try await APIClient.shared.post(
                endpoint: "/likes/car/\(userCarId)",
                body: EmptyRequest()
            )
            Logger.info("Successfully liked car \(userCarId)")
            return like
        } catch let error as APIError {
            switch error {
            case .httpError(409, _):
                Logger.error("Car \(userCarId) already liked")
                throw error
            default:
                Logger.error("Failed to like car \(userCarId): \(error)")
                throw error
            }
        }
    }
    
    func unlikeCar(_ userCarId: Int) async throws {
        Logger.info("Unliking car: \(userCarId)")
        do {
            let _: EmptyResponse = try await APIClient.shared.delete(
                endpoint: "/likes/car/\(userCarId)"
            )
            Logger.info("Successfully unliked car \(userCarId)")
        } catch {
            Logger.error("Failed to unlike car \(userCarId): \(error)")
            throw error
        }
    }
    
    func getCarLikes(userCarId: Int, pageSize: Int = 10, cursor: String? = nil) async throws -> LikesResponse {
        Logger.info("Fetching likes for car \(userCarId)")
        var endpoint = "/likes/car/\(userCarId)?page_size=\(pageSize)"
        if let cursor {
            endpoint += "&cursor=\(cursor)"
        }
        
        do {
            let response: LikesResponse = try await APIClient.shared.get(endpoint: endpoint)
            Logger.info("Successfully fetched \(response.items.count) likes for car \(userCarId)")
            return response
        } catch {
            Logger.error("Failed to fetch likes for car \(userCarId): \(error)")
            throw error
        }
    }
    
    func checkIfUserLikedCar(userCarId: Int) async throws -> Bool {
        Logger.info("Checking if user liked car \(userCarId)")
        
        do {
            let response: CarLikeCheckResponse = try await APIClient.shared.get(
                endpoint: "/likes/car/\(userCarId)/check"
            )
            Logger.info("User liked car \(userCarId): \(response.liked)")
            return response.liked
        } catch {
            Logger.error("Failed to check if user liked car \(userCarId): \(error)")
            throw error
        }
    }
    
    func getCarLikesCount(userCarId: Int) async throws -> Int {
        Logger.info("Getting likes count for car \(userCarId)")
        
        do {
            let response: LikeCountResponse = try await APIClient.shared.get(
                endpoint: "/likes/car/\(userCarId)/count"
            )
            Logger.info("Car \(userCarId) has \(response.count) likes")
            return response.count
        } catch {
            Logger.error("Failed to get car likes count for \(userCarId): \(error)")
            throw error
        }
    }
}