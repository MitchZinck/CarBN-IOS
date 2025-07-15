import SwiftUI

@Observable
@MainActor
final class FriendsViewModel {
    var pendingRequests: [FriendRequest] = []
    private var currentUserCars: [Car] = []
    var searchResults: [User] = []
    var isLoading = false
    var isSearching = false
    var errorMessage: String?
    var searchQuery = ""
    var friends: [Friend] = []
    var hasMore = false
    var total = 0
    var currentOffset = 0
    private let limit = 20
    var friendSubscriptionStatus: [Int: Bool] = [:]
    private(set) var hasSearched = false
    
    func loadPendingRequests() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            pendingRequests = try await FriendService.shared.getPendingRequests()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func sendFriendRequest(to userId: Int) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await FriendService.shared.sendFriendRequest(to: userId)
            // Reload requests to show updated state
            await loadPendingRequests()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func handleRequest(requestId: Int, accept: Bool) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await FriendService.shared.respondToRequest(requestId: requestId, accept: accept)
            // Reload requests after response
            await loadPendingRequests()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func searchUsers() async {
        isSearching = true
        hasSearched = true
        defer { isSearching = false }
        
        do {
            searchResults = try await FriendService.shared.searchUsers(query: searchQuery)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func loadFriends(userId: Int? = nil) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await FriendService.shared.getFriends(userId: userId, limit: limit, offset: 0)
            self.friends = response.friends ?? []
            self.hasMore = response.hasMore
            self.total = response.total
            self.currentOffset = self.friends.count
            
            // Only check subscription status when viewing general friends list
            if userId == nil {
                let statuses = await SubscriptionService.shared.batchCheckSubscriptionStatus(
                    userIds: self.friends.map { $0.id }
                )
                friendSubscriptionStatus = statuses
            }
            errorMessage = nil
        } catch {
            // Don't display error message for cancellation
            if let nsError = error as NSError?, nsError.code == -999 && nsError.domain == NSURLErrorDomain {
                Logger.info("Friends request cancelled during navigation")
            } else {
                errorMessage = error.localizedDescription
                Logger.error("Failed to load friends: \(error)")
            }
        }
    }
    
    func loadMoreFriends(userId: Int? = nil) async {
        guard !isLoading && hasMore else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await FriendService.shared.getFriends(userId: userId, limit: limit, offset: currentOffset)
            if let newFriends = response.friends {
                friends.append(contentsOf: newFriends)
                hasMore = response.hasMore
                currentOffset += newFriends.count
                
                // Check subscription status for new friends
                if userId == nil {
                    let statuses = await SubscriptionService.shared.batchCheckSubscriptionStatus(
                        userIds: newFriends.map { $0.id }
                    )
                    friendSubscriptionStatus.merge(statuses) { _, new in new }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func loadCurrentUserCars() async {
        do {
            let localCars = CarService.shared.getLocalCars()
            if !localCars.isEmpty {
                currentUserCars = localCars
            } else {
                try await CarService.shared.fetchAndStoreUsersCars()
                currentUserCars = CarService.shared.getLocalCars()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearSearchState() {
        searchResults = []
        searchQuery = ""
        hasSearched = false
    }
    
    func clearState() {
        friends = []
        pendingRequests = []
        searchResults = []
        errorMessage = nil
        searchQuery = ""
        hasMore = false
        total = 0
        currentOffset = 0
        friendSubscriptionStatus = [:]
    }
}
