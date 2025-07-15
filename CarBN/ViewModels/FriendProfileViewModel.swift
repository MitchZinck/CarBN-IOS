import SwiftUI

@Observable
@MainActor
final class FriendProfileViewModel{
    var userId: Int
    var user: User?
    var cars: [Car] = []
    var isLoadingUser = false
    var isLoadingCars = false
    var errorMessage: String?
    var isFriend = false
    var isCurrentUser = false
    var friendRequestPending = false
    var currentSort: CarSort = .rarity
    
    // Pagination properties
    private(set) var hasMoreCars: Bool = true
    private(set) var isLoadingMoreCars: Bool = false
    private(set) var currentOffset: Int = 0
    
    // Add debouncing properties
    private var loadMoreTask: Task<Void, Never>?
    private var lastLoadTime: Date = .distantPast
    
    private let carService: CarService
    private let appState: AppState
    private let pageSize = 20 // Number of cars to fetch per page
    
    var isLoading: Bool {
        isLoadingUser || isLoadingCars
    }
    
    @MainActor
    init(userId: Int, appState: AppState) {
        self.userId = userId
        self.carService = CarService.shared
        self.appState = appState
        self.isCurrentUser = UserManager.shared.currentUser?.id == userId
    }
    
    func loadUser() async {
        guard !isLoadingUser else { return }  // Prevent multiple simultaneous loads
        isLoadingUser = true
        defer { isLoadingUser = false }
        
        do {
            user = try await APIClient.shared.get(endpoint: APIConstants.getUserDetailsPath(userId: userId))
            
            // Check if users are friends or if there's a pending request
            if !isCurrentUser {
                await checkFriendshipStatus()
            }
            
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load user profile: \(error.localizedDescription)"
            Logger.error("Failed to load user profile: \(error)")
        }
    }

    private func checkFriendshipStatus() async {
        do {
            isFriend = try await FriendService.shared.checkFriendshipStatus(userId: userId)
            
            if !isFriend {
                let pendingRequests = try await FriendService.shared.getPendingRequests()
                friendRequestPending = checkPendingRequestStatus(requests: pendingRequests)
            }
        } catch {
            errorMessage = "Failed to check friendship status: \(error.localizedDescription)"
            Logger.error("Failed to check friendship status: \(error)")
        }
    }
    
    private func checkPendingRequestStatus(requests: [FriendRequest]) -> Bool {
        for request in requests {
            // Check if we sent the request to this user
            if request.friendId == userId {
                return true
            }
            // Check if this user sent us a request
            if request.userId == userId {
                return true
            }
        }
        return false
    }

    func loadCars() async {
        guard !isLoadingCars else { return }  // Prevent multiple simultaneous loads
        isLoadingCars = true
        defer { isLoadingCars = false }
        
        // Reset pagination state
        resetPaginationState()
        
        do {
            let newCars = try await carService.fetchUsersCars(userId: userId, limit: pageSize, offset: 0, sort: currentSort)
            cars = newCars
            
            // Update pagination state
            currentOffset = newCars.count
            hasMoreCars = newCars.count >= pageSize
            
            errorMessage = nil
        } catch {
            if case APIError.httpError(404, _) = error {
                // No cars found is a valid state
                cars = []
                hasMoreCars = false
            } else {
                errorMessage = "Failed to load car collection: \(error.localizedDescription)"
                Logger.error("Failed to load car collection: \(error)")
            }
        }
    }
    
    // Updated to use server-side sorting
    func loadMoreCars() async {
        // Don't attempt fetch if we're already loading or there are no more cars
        guard !isLoadingMoreCars && hasMoreCars else { return }
        
        let now = Date()
        if now.timeIntervalSince(lastLoadTime) < 0.5 {
            return
        }
        
        // Cancel any existing task
        loadMoreTask?.cancel()
        
        // Create a new task
        loadMoreTask = Task {
            isLoadingMoreCars = true
            defer { isLoadingMoreCars = false }
            
            // Set the last load time
            lastLoadTime = Date()
            
            do {
                let newCars = try await carService.fetchUsersCars(userId: userId, limit: pageSize, offset: currentOffset, sort: currentSort)
                
                // Append new cars to the existing collection
                cars.append(contentsOf: newCars)
                
                // Update pagination state
                hasMoreCars = newCars.count >= pageSize
                currentOffset += newCars.count
                
                errorMessage = nil
            } catch {
                if case APIError.httpError(404, _) = error {
                    // No more cars found
                    hasMoreCars = false
                } else {
                    errorMessage = "Failed to load more cars: \(error.localizedDescription)"
                    Logger.error("Failed to load more cars: \(error)")
                }
            }
            
            loadMoreTask = nil
        }
    }
    
    // Add method to update sort option and reload cars
    func updateSortOption(newSort: CarSort) async {
        guard newSort != currentSort else { return }
        
        currentSort = newSort
        
        // Reset pagination state without clearing cars array
        resetPaginationState()
        
        // Load cars with new sort option
        await loadCars()
    }
    
    private func resetPaginationState() {
        currentOffset = 0
        hasMoreCars = true
    }
    
    func loadData() async {
        // Load data in parallel
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadUser() }
            group.addTask { await self.loadCars() }
        }
    }
    
    func sendFriendRequest() async {
        do {
            try await FriendService.shared.sendFriendRequest(to: userId)
            friendRequestPending = true
            // Update global pending requests list
            await appState.friendsViewModel.loadPendingRequests()
        } catch {
            errorMessage = "Failed to send friend request: \(error.localizedDescription)"
            Logger.error("Failed to send friend request: \(error)")
        }
    }
}
