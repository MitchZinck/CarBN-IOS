import SwiftUI
import Combine
import Foundation

enum Sheet: Identifiable {
    case friendsList(userId: Int, userName: String)
    
    var id: String {
        switch self {
        case .friendsList(let userId, _):
            return "friendsList-\(userId)"
        }
    }
}

// MARK: - AppState

/// Global application state that holds authentication status and triggers refreshes.
@Observable
@MainActor
final class AppState {
    private static var _shared: AppState?
    
    static var shared: AppState {
        guard let instance = _shared else {
            let instance = AppState()
            _shared = instance
            // Initialize async state
            Task {
                await instance.initialize()
            }
            Logger.info("AppState singleton instance created and initialized")
            return instance
        }
        Logger.info("Returning existing AppState singleton instance")
        return instance
    }
    
    // User details
    var currentUser: User?
    var isAuthenticated = false
    var authToken: String?
    
    // Subscription details
    var subscription: SubscriptionInfo?
    
    // App state
    var isOnboarding = false
    var activeAlert: AlertType?
    var activeSheet: Sheet?
    
    // View models - appState is the sole owner of all view models
    private(set) var friendsViewModel = FriendsViewModel()
    private(set) var tradesViewModel = TradesViewModel()
    private(set) var homeViewModel: HomeViewModel?
    
    // Last data refresh timestamp
    private var lastRefreshTime = Date(timeIntervalSince1970: 0)
    private let defaultRefreshInterval: TimeInterval = 30 // 30 seconds default refresh interval
    
    // Settings
    var notificationsEnabled: Bool = true
    var darkModeEnabled: Bool = true
    var hapticFeedbackEnabled: Bool = true

    // Initialize with system language or saved preference
    var currentLanguage: String = UserDefaults.standard.string(forKey: "app_language") ?? 
        LocalizationManager.shared.getCurrentLanguage()
    
    enum AlertType: Identifiable {
        case error(message: String)
        case success(message: String)
        case confirmation(title: String, message: String, confirmAction: () -> Void)
        
        var id: String {
            switch self {
            case .error(let message):
                return "error-\(message)"
            case .success(let message):
                return "success-\(message)"
            case .confirmation(let title, _, _):
                return "confirmation-\(title)"
            }
        }
    }
    
    // Check if user has an active subscription
    var hasActiveSubscription: Bool {
        return subscription?.isActive ?? false
    }
    
    // Get current subscription tier
    var currentSubscriptionTier: SubscriptionTier {
        return subscription?.tier ?? .none
    }
    
    // Get remaining scan credits
    var scanCreditsRemaining: Int {
        return subscription?.scanCreditsRemaining ?? 0
    }
    
    private init() {
        Logger.info("Initializing AppState instance")
    }
    
    private var isRefreshingToken = false

    private func initialize() async {
        Logger.info("Starting async AppState initialization")
        self.isAuthenticated = AuthenticationManager.shared.isLoggedIn()
        Logger.info("Initial authentication status: \(isAuthenticated)")
        
        if isAuthenticated {
            Logger.info("User is authenticated during initialization, triggering data refresh")
            await refreshLocalData()
        } else {
            Logger.info("No authenticated user found during initialization")
            await attemptTokenRefresh()
        }
        Logger.info("AppState initialization completed")
    }

    private func attemptTokenRefresh() async {
        if isRefreshingToken {
            return // Prevent concurrent refresh attempts
        }
        
        isRefreshingToken = true
        defer { isRefreshingToken = false }
        
        Logger.info("Attempting refresh of authentication token")
        do {
            let success = try await AuthService.shared.refreshToken()
            if success {
                Logger.info("Token refresh successful, updating authenticated state to true")
                await setAuthenticated(success)
            } else {
                Logger.info("Token refresh failed, user remains unauthenticated")
            }
        } catch {
            Logger.info("Token refresh failed with error: \(error.localizedDescription)")
        }
    }

    func validateAuthStatus() {
        Logger.info("Validating authentication status")
        Task {
            // Check if we have valid tokens
            if let token = try? AuthenticationManager.shared.getAccessToken() {
                Logger.info("Valid access token found: \(String(token.prefix(8)))...")
                await setAuthenticated(true)
            } else {
                Logger.info("No valid access token found, attempting refresh")
                await attemptTokenRefresh()
            }
        }
    }
    
    /// Call all refresh functions once authenticated.
    func refreshLocalData() async {
        Logger.info("Starting data refresh process")
        do {
            // Always fetch fresh data from server, no caching
            Logger.info("Refreshing user details from server")
            try await UserManager.shared.fetchAndUpdateUserDetails()
            
            Logger.info("Refreshing user cars data from server")
            try await CarService.shared.fetchAndStoreUsersCars(limit: 10)
            
            // Initialize HomeViewModel if needed
            await initializeHomeViewModelIfNeeded()
            
            Logger.info("Data refresh completed successfully")
        } catch let error as APIError {
            if (error == .maxRetriesExceeded) {
                Logger.info("Authentication expired during data refresh, logging out user")
                // User is no longer authenticated, update state and clear data
                await setAuthenticated(false)
            } else {
                Logger.error("Failed to refresh data: \(error)", file: #file, line: #line)
            }
        } catch {
            Logger.error("Failed to refresh data with unknown error: \(error)", file: #file, line: #line)
        }
    }
    
    /// Update the authentication state and refresh data if necessary.
    func setAuthenticated(_ value: Bool) async {
        // Skip if state isn't changing
        guard isAuthenticated != value else {
            Logger.info("Authentication state unchanged (\(value)), no action required")
            return
        }
        
        Logger.info("Setting authentication state from \(isAuthenticated) to: \(value)")
        isAuthenticated = value
        if value {
            Logger.info("User authenticated, initiating data refresh")
            await refreshLocalData()
        } else {
            Logger.info("User logged out, clearing application state")
            await clearState()
        }
    }
    
    /// Update authentication state without triggering data refresh - used during logout to prevent cascading effects
    func setAuthenticatedWithoutRefresh(_ value: Bool) async {
        // Skip if state isn't changing
        guard isAuthenticated != value else {
            Logger.info("Authentication state unchanged (\(value)), no action required")
            return
        }
        
        Logger.info("Setting authentication state from \(isAuthenticated) to: \(value) without refresh")
        isAuthenticated = value
    }
    
    func clearState() async {
        Logger.info("Clearing application state")
        
        // Clear view model states
        Logger.info("Clearing friends view model state")
        friendsViewModel.clearState()
        
        Logger.info("Clearing trades view model state")
        tradesViewModel.clearTrades()
        
        // Clear home view model
        Logger.info("Clearing home view model")
        homeViewModel = nil
        
        // Clear subscription data
        Logger.info("Clearing subscription data")
        subscription = nil
        
        // Clear all caches except image cache
        Logger.info("Clearing subscription service cache")
        SubscriptionService.shared.clearCache()
        
        // Clear car data
        Logger.info("Clearing car service data")
        try? await CarService.shared.fetchAndStoreUsersCars(limit: 0)
        
        // Reset refresh time
        lastRefreshTime = Date(timeIntervalSince1970: 0)
        
        // Clear stored like IDs when logging out
        UserDefaults.standard.removeObject(forKey: "last_received_like_ids")
        UserDefaults.standard.synchronize()
        
        Logger.info("Application state cleared successfully")
    }
    
    // MARK: - Unified Data Refresh System
    
    /// Check if a refresh is needed based on the time since last refresh
    func refreshIfNeeded() async {
        let currentTime = Date()
        let timeSinceLastRefresh = currentTime.timeIntervalSince(lastRefreshTime)
        
        // Only refresh if it's been more than the refresh interval
        if isAuthenticated && timeSinceLastRefresh >= defaultRefreshInterval {
            Logger.info("Time since last refresh: \(timeSinceLastRefresh)s - refreshing data")
            await refreshAllData()
        } else {
            Logger.info("Skipping refresh - time since last refresh: \(timeSinceLastRefresh)s")
        }
    }
    
    /// Force a refresh of all data regardless of time interval
    func refreshAllData() async {
        guard isAuthenticated else {
            Logger.info("Refresh skipped - user not authenticated")
            return
        }
        
        Logger.info("Starting comprehensive data refresh")
        
        // Refresh common data in parallel
        async let friendsTask: Void = friendsViewModel.loadPendingRequests()
        async let tradesTask: Void = tradesViewModel.refreshTrades()
        async let subscriptionTask: Void = refreshSubscription()
        
        // Wait for common tasks to complete
        _ = await (friendsTask, tradesTask, subscriptionTask)
        
        // Check for new likes using the ID-based approach
        await checkForNewLikes()
        
        // Update last refresh time
        lastRefreshTime = Date()
        Logger.info("Comprehensive data refresh completed at \(lastRefreshTime)")
    }
    
    // MARK: - View Model Management
    
    /// Initialize HomeViewModel if it doesn't exist
    private func initializeHomeViewModelIfNeeded() async {
        if homeViewModel == nil && isAuthenticated {
            Logger.info("Initializing HomeViewModel")
            homeViewModel = await HomeViewModel()
        }
    }
    
    func refreshSubscription() async {
        Logger.info("Refreshing subscription info")
        do {
            // Always fetch fresh subscription data from server
            subscription = try await SubscriptionService.shared.getSubscriptionInfo()
            Logger.info("Subscription refresh completed successfully")
        } catch {
            Logger.error("Failed to refresh subscription info: \(error)")
        }
    }
    
    func checkForNewLikes() async {
        await initializeHomeViewModelIfNeeded()
        
        if let homeViewModel = homeViewModel {
            Logger.info("Checking for new likes using ID comparison")
            await homeViewModel.checkForNewLikes()
        }
    }
    
    func showSheet(_ sheet: Sheet) {
        switch sheet {
        case .friendsList(let userId, let userName):
            Logger.info("Showing friends list sheet for user: \(userName) (ID: \(userId))")
        }
        activeSheet = sheet
    }
    
    // Load initial subscription information
    func loadSubscriptionInfo() async {
        do {
            subscription = try await SubscriptionService.shared.getSubscriptionInfo()
            Logger.info("Loaded subscription info: \(String(describing: subscription))")
        } catch {
            Logger.error("Failed to load subscription info: \(error.localizedDescription)")
        }
    }
    
    // Check if a specific user can trade (has active subscription)
    func canTradeWithUser(_ userId: Int) async -> Bool {
        guard hasActiveSubscription else { return false }
        
        do {
            return try await SubscriptionService.shared.getUserSubscriptionStatus(userId: userId)
        } catch {
            Logger.error("Failed to check user subscription status: \(error.localizedDescription)")
            return false
        }
    }
    
    // Consume scan credits (returns true if successful)
    func consumeScanCredit() async -> Bool {
        guard let currentCredits = subscription?.scanCreditsRemaining, currentCredits > 0 else {
            return false
        }
        
        // This would ideally call an API endpoint to consume a credit
        // For now, we'll just update the local state
        subscription?.scanCreditsRemaining = currentCredits - 1
        return true
    }
}
