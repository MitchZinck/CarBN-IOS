import Foundation

enum FeedType: String, CaseIterable {
    case global
    case friends
}

@MainActor
final class FeedService {
    static let shared = FeedService()
    private init() {}
    
    func fetchFeed(pageSize: Int = 10, cursor: String? = nil, feedType: FeedType = .global) async throws -> FeedResponse {
        Logger.info("Fetching feed with pageSize: \(pageSize), cursor: \(cursor ?? "nil"), feedType: \(feedType.rawValue)")
        var endpoint = "/feed?page_size=\(pageSize)&feed_type=\(feedType.rawValue)"
        if let cursor, !cursor.isEmpty {
            endpoint += "&cursor=\(cursor)"
        }
        let response: FeedResponse = try await APIClient.shared.get(endpoint: endpoint)
        Logger.info("Successfully fetched \(response.items.count) feed items")
        return response
    }
    
    func fetchFeedItem(id: Int) async throws -> FeedItem {
        Logger.info("Fetching feed item with id: \(id)")
        let endpoint = "/feed/\(id)"
        let item: FeedItem = try await APIClient.shared.get(endpoint: endpoint)
        Logger.info("Successfully fetched feed item \(id)")
        return item
    }
}