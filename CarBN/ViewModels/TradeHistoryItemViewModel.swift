import Foundation

@Observable
final class TradeHistoryItemViewModel {
    private(set) var fromUser: User?
    private(set) var toUser: User?
    private(set) var isLoading = false
    var errorMessage: String?
    var showError = false
    
    private var loadTask: Task<Void, Never>?
    private var currentUserId: Int?
    
    deinit {
        loadTask?.cancel()
    }
    
    func loadUsers(trade: Trade) async {
        // Cancel existing task if it's for a different user
        if currentUserId != trade.fromUserId {
            loadTask?.cancel()
            currentUserId = trade.fromUserId
        }
        
        // Check cache first
        if let cachedFromUser = await UserCache.shared.getUser(id: trade.fromUserId),
           let cachedToUser = await UserCache.shared.getUser(id: trade.toUserId) {
            fromUser = cachedFromUser
            toUser = cachedToUser
            return
        }
        
        // Prevent concurrent loads for the same user
        guard loadTask == nil else { return }
        
        isLoading = true
        
        loadTask = Task { [weak self] in
            guard let self else { return }
            
            do {
                async let fromUserResult: User = APIClient.shared.get(
                    endpoint: APIConstants.getUserDetailsPath(userId: trade.fromUserId)
                )
                async let toUserResult: User = APIClient.shared.get(
                    endpoint: APIConstants.getUserDetailsPath(userId: trade.toUserId)
                )
                
                let (fromUser, toUser) = try await (fromUserResult, toUserResult)
                
                if !Task.isCancelled {
                    await UserCache.shared.setUser(fromUser)
                    await UserCache.shared.setUser(toUser)
                    
                    // Only update UI if this is still the current user we're loading
                    if self.currentUserId == trade.fromUserId {
                        self.fromUser = fromUser
                        self.toUser = toUser
                        self.errorMessage = nil
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = "Failed to load user profiles: \(error.localizedDescription)"
                    self.showError = true
                    Logger.error("Failed to load user profiles: \(error)")
                }
            }
            
            if !Task.isCancelled {
                self.isLoading = false
                self.loadTask = nil
            }
        }
    }
}

// Thread-safe cache implementation using actor
public actor UserCache {
    static let shared = UserCache()
    private var cache: [Int: (user: User, timestamp: Date)] = [:]
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    
    func getUser(id: Int) -> User? {
        guard let entry = cache[id] else { return nil }
        
        // Remove expired entries
        if Date().timeIntervalSince(entry.timestamp) > cacheTimeout {
            cache.removeValue(forKey: id)
            return nil
        }
        
        return entry.user
    }
    
    func setUser(_ user: User) {
        cache[user.id] = (user: user, timestamp: Date())
    }
    
    public func clearCache() {
        cache.removeAll()
    }
}
