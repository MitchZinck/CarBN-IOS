import Foundation

@MainActor
final class FriendService {
    static let shared = FriendService()
    private init() {}
    
    func sendFriendRequest(to userId: Int) async throws {
        let request = SendFriendRequest(friendId: userId)
        let _: EmptyResponse = try await APIClient.shared.post(
            endpoint: "/friends/request",
            body: request
        )
    }
    
    func respondToRequest(requestId: Int, accept: Bool) async throws {
        let response = FriendRequestResponse(
            requestId: requestId,
            response: accept ? "accept" : "reject"
        )
        let _: EmptyResponse = try await APIClient.shared.post(
            endpoint: "/friends/respond",
            body: response
        )
    }
    
    func getPendingRequests() async throws -> [FriendRequest] {
        try await APIClient.shared.get(endpoint: "/user/friend-requests")
    }
    
    func searchUsers(query: String) async throws -> [User] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await APIClient.shared.get(endpoint: "/user/search?q=\(encodedQuery)")
    }
    
    func getFriends(userId: Int? = nil, limit: Int = 10, offset: Int = 0) async throws -> FriendsResponse {
        let path = "/user/\(userId!)/friends"
        let queryParams = "?limit=\(limit)&offset=\(offset)"
        do {
            return try await APIClient.shared.get(endpoint: "\(path)\(queryParams)")
        } catch {
            // Don't log cancellation errors
            if let nsError = error as NSError?, nsError.code != -999 || nsError.domain != NSURLErrorDomain {
                Logger.error("Failed to get friends: \(error)")
            }
            throw error
        }
    }

    func checkFriendshipStatus(userId: Int? = nil) async throws -> Bool {
        let path = "/user/\(userId!)/is-friend"
        let response: FriendshipStatusResponse = try await APIClient.shared.get(endpoint: path)
        return response.isFriend
    }
}
