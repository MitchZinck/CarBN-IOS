import SwiftUI

enum HomeTab {
    case feed, likes
}

@Observable
@MainActor
final class HomeViewModel {
    var feedItems: [FeedItem] = []
    var receivedLikes: [Like] = []
    var selectedTab: HomeTab = .feed
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?
    var showError = false
    var newLikesCount = 0
    var selectedFeedType: FeedType = .global
    
    // Storage keys for likes tracking
    private let lastLikeIdsKey = "last_received_like_ids"
    private let maxStoredLikeIds = 10
    
    private var currentCursor: String?
    private var likeCursor: String?
    private var hasMoreItems = true
    private var hasMoreLikes = true
    private let feedService: FeedService
    private let carService: CarService
    private let likeService: LikeService
    private let pageSize = 10
    
    init() async {
        self.feedService = FeedService.shared
        self.carService = CarService.shared
        self.likeService = LikeService.shared
    }
    
    func checkForNewLikes() async {
        guard let currentUserId = UserManager.shared.currentUser?.id else { return }
        
        do {
            let response = try await likeService.getUserReceivedLikes(userId: currentUserId, pageSize: 50)
            
            // Get current like IDs (up to maxStoredLikeIds)
            let currentLikeIds = response.items.prefix(maxStoredLikeIds).map { $0.id }
            
            // Get previously stored like IDs
            let previousLikeIds = UserDefaults.standard.array(forKey: lastLikeIdsKey) as? [Int] ?? []
            
            // Calculate new likes
            let newLikeIds = currentLikeIds.filter { !previousLikeIds.contains($0) }
            
            // Update the count if we're not on the likes tab
            if selectedTab != .likes {
                if newLikeIds.count >= maxStoredLikeIds {
                    newLikesCount = maxStoredLikeIds
                } else {
                    newLikesCount = newLikeIds.count
                }
            }
            
            // Store the current like IDs for future comparison
            UserDefaults.standard.set(Array(currentLikeIds), forKey: lastLikeIdsKey)
            UserDefaults.standard.synchronize()
            
            Logger.info("Checked for new likes: found \(newLikeIds.count) new likes")
        } catch {
            Logger.error("Failed to check for new likes: \(error)")
        }
    }
    
    func loadFeed() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await feedService.fetchFeed(pageSize: pageSize, feedType: selectedFeedType)
            var itemsWithUserDetails = response.items
            
            // Fetch user details and like status for all items
            for i in 0..<itemsWithUserDetails.count {
                let item = itemsWithUserDetails[i]
                
                // Get user details
                if let userDetails: User = try? await APIClient.shared.get(endpoint: APIConstants.getUserDetailsPath(userId: item.userId)) {
                    itemsWithUserDetails[i].userName = userDetails.displayName
                    itemsWithUserDetails[i].userProfilePicture = userDetails.profilePicture
                }
                
                if let relatedUserId = item.relatedUserId {
                    if let relatedUserDetails: User = try? await APIClient.shared.get(endpoint: APIConstants.getUserDetailsPath(userId: relatedUserId)) {
                        itemsWithUserDetails[i].relatedUserName = relatedUserDetails.displayName
                        itemsWithUserDetails[i].relatedUserProfilePicture = relatedUserDetails.profilePicture
                    }
                }
            }
            
            // Deduplicate friend accepted items
            itemsWithUserDetails = deduplicateFriendFeedItems(itemsWithUserDetails)
            
            feedItems = itemsWithUserDetails
            currentCursor = response.nextCursor
            hasMoreItems = response.nextCursor != nil
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            Logger.error("Failed to load feed: \(error)")
        }
    }
    
    func loadMoreFeed() async {
        guard hasMoreItems, !isLoadingMore else { return }
        
        isLoadingMore = true
        defer { isLoadingMore = false }
        
        do {
            let response = try await feedService.fetchFeed(pageSize: pageSize, cursor: currentCursor, feedType: selectedFeedType)
            var newItems = response.items
            
            // Fetch user details and like status for new items
            for i in 0..<newItems.count {
                let item = newItems[i]
                
                // Get user details
                if let userDetails: User = try? await APIClient.shared.get(endpoint: APIConstants.getUserDetailsPath(userId: item.userId)) {
                    newItems[i].userName = userDetails.displayName
                    newItems[i].userProfilePicture = userDetails.profilePicture
                }
                
                if let relatedUserId = item.relatedUserId {
                    if let relatedUserDetails: User = try? await APIClient.shared.get(endpoint: APIConstants.getUserDetailsPath(userId: relatedUserId)) {
                        newItems[i].relatedUserName = relatedUserDetails.displayName
                        newItems[i].relatedUserProfilePicture = relatedUserDetails.profilePicture
                    }
                }
            }
            
            feedItems.append(contentsOf: newItems)
            currentCursor = response.nextCursor
            hasMoreItems = response.nextCursor != nil && !response.nextCursor!.isEmpty
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            Logger.error("Failed to load more feed items: \(error)")
        }
    }
    
    func loadReceivedLikes() async {
        guard let currentUserId = UserManager.shared.currentUser?.id else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await likeService.getUserReceivedLikes(userId: currentUserId, pageSize: pageSize)
            receivedLikes = response.items
            likeCursor = response.nextCursor
            hasMoreLikes = response.nextCursor != nil
            
            // Store the current like IDs
            let currentLikeIds = response.items.prefix(maxStoredLikeIds).map { $0.id }
            UserDefaults.standard.set(Array(currentLikeIds), forKey: lastLikeIdsKey)
            UserDefaults.standard.synchronize()
            
            // Reset new likes count when viewing likes tab
            newLikesCount = 0
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            Logger.error("Failed to load received likes: \(error)")
        }
    }
    
    func loadMoreReceivedLikes() async {
        guard let currentUserId = UserManager.shared.currentUser?.id,
              hasMoreLikes, !isLoadingMore else { return }
        
        isLoadingMore = true
        defer { isLoadingMore = false }
        
        do {
            let response = try await likeService.getUserReceivedLikes(
                userId: currentUserId,
                pageSize: pageSize,
                cursor: likeCursor
            )
            receivedLikes.append(contentsOf: response.items)
            likeCursor = response.nextCursor
            hasMoreLikes = response.nextCursor != nil
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            Logger.error("Failed to load more received likes: \(error)")
        }
    }
    
    func toggleLike(for feedItem: FeedItem) async -> Bool {
        do {
            // Regular feed item like
            if feedItem.isLikedByCurrentUser {
                try await likeService.unlikeFeedItem(feedItem.id)
            } else {
                _ = try await likeService.likeFeedItem(feedItem.id)
            }
            
            // Update the UI state regardless of the like type
            if let index = feedItems.firstIndex(where: { $0.id == feedItem.id }) {
                feedItems[index].isLikedByCurrentUser = !feedItem.isLikedByCurrentUser
                feedItems[index].likeCount += feedItem.isLikedByCurrentUser ? -1 : 1
            }
            
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }
    
    private func deduplicateFriendFeedItems(_ items: [FeedItem]) -> [FeedItem] {
        var seen = Set<String>()
        return items.filter { item in
            guard item.type == .friendAccepted else { return true }
            
            // Create a unique key for the friendship pair
            let ids = [item.userId, item.relatedUserId ?? 0].sorted()
            let key = "friend_\(ids[0])_\(ids[1])"
            
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }
    }
    
    func getCar(for feedItem: FeedItem) async -> Car? {
        guard feedItem.type == .carScanned else { return nil }
        do {
            let cars = try await carService.fetchSpecificUserCars(userCarIds: [feedItem.referenceId])
            return cars.first
        } catch {
            Logger.error("Failed to fetch car for feed item: \(error)")
            return nil
        }
    }
    
    func getTrade(for feedItem: FeedItem) async -> Trade? {
        guard feedItem.type == .tradeCompleted else { return nil }
        do {
            return try await TradeService.shared.fetchTradeById(feedItem.referenceId)
        } catch {
            Logger.error("Failed to fetch trade for feed item: \(error)")
            return nil
        }
    }
}
