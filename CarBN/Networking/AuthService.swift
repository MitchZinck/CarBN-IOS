// MARK: - AuthService.swift
import Foundation

enum AuthError: Error {
    case invalidToken
    case invalidCredentials
    case serverError
    case networkError
    case invalidDisplayName
}

extension AuthError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidToken: return "Invalid authentication token"
        case .invalidCredentials: return "Invalid credentials"
        case .serverError: return "A server error occurred"
        case .networkError: return "A network error occurred"
        case .invalidDisplayName: return "Display name is required and must be at least 2 characters"
        }
    }
}

struct MessageResponse: Decodable {
    let message: String
}

struct ErrorResponse: Decodable {
    let error: String
    let message: String?
    let details: [String: String]?
}

protocol AuthServiceProtocol {
    func logout() async throws
    func refreshToken() async throws -> Bool
    func forceLogout() async
    func signIn(with provider: AuthProvider, idToken: String, displayName: String) async throws -> Bool
}

enum AuthProvider {
    case google
    case apple
    
    var endpoint: String {
        switch self {
        case .google:
            return "/auth/google"
        case .apple:
            return "/auth/apple"
        }
    }
}

@MainActor
final class AuthService: AuthServiceProtocol {
    static let shared: AuthService = {
        let instance = AuthService(apiClient: .shared)
        Logger.info("[AuthService] Singleton instance created")
        return instance
    }()
    
    private let apiClient: APIClient
    
    nonisolated private init(apiClient: APIClient) {
        self.apiClient = apiClient
        Logger.info("[AuthService] Initialized with API client")
    }
    
    struct ThirdPartyAuthRequest: Codable {
        let idToken: String
        let displayName: String
    }
    
    struct RefreshTokenRequest: Codable {
        let refresh_token: String
    }
    
    struct LogoutRequest: Codable {
        let refresh_token: String
    }
    
    struct AuthResponse: Codable {
        let accessToken: String
        let refreshToken: String
        let tokenType: String
        let expiresIn: Int
    }
    
    func logout() async throws {
        Logger.info("[AuthService] Starting logout process")
        
        // Set logout flag early to prevent API requests during logout
        apiClient.setIsLoggingOut(true)
        
        // Try server-side logout if we have a refresh token
        if let refreshToken = try? AuthenticationManager.shared.getRefreshToken() {
            Logger.info("[AuthService] Found refresh token, sending logout request to server")
            let request = LogoutRequest(refresh_token: refreshToken)
            do {
                let _: MessageResponse = try await apiClient.post(
                    endpoint: APIConstants.logoutPath,
                    body: request
                )
                Logger.info("[AuthService] Logout request to server successful")
            } catch {
                Logger.warning("[AuthService] Logout API call failed: \(error)")
                // Continue with logout regardless of server response
            }
        } else {
            Logger.info("[AuthService] No refresh token found for server logout")
        }
        
        // Clean up authentication
        await AuthenticationManager.shared.clearTokens()
        Logger.info("[AuthService] Authentication tokens cleared")
        
        // Clear user data
        UserManager.shared.clearUser()
        Logger.info("[AuthService] User data cleared")
        
        CarService.shared.resetPaginationState()
        Logger.info("[AuthService] Car service data cleared")
        
        // Clear third-party auth providers
        GoogleAuthManager.shared.signOut()
        Logger.info("[AuthService] Google auth signed out")
        
        // Clear all caches in parallel
        async let userCacheTask: () = UserCache.shared.clearCache()
        async let imageCacheTask: () = ImageCache.shared.clear()
        
        // Wait for cache clearing to complete
        _ = await (userCacheTask, imageCacheTask)
        Logger.info("[AuthService] User and image caches cleared")
        
        // Clear service caches
        SubscriptionService.shared.clearCache()
        Logger.info("[AuthService] Subscription service cache cleared")
        
        // Clear friends and trades data
        AppState.shared.friendsViewModel.clearState()
        Logger.info("[AuthService] Friends view model state cleared")
        
        AppState.shared.tradesViewModel.clearTrades()
        Logger.info("[AuthService] Trades view model state cleared")
        
        // Update app state last to avoid rendering issues
        await AppState.shared.setAuthenticatedWithoutRefresh(false)
        Logger.info("[AuthService] App authentication state updated")
        
        // Reset the logging out flag after all cleanup is complete
        apiClient.setIsLoggingOut(false)
        
        Logger.info("[AuthService] Logout completed successfully")
    }
    
    // Simplified forceLogout for error scenarios
    func forceLogout() async {
        // Simply delegate to the regular logout
        do {
            try await logout()
        } catch {
            Logger.error("[AuthService] Force logout error: \(error)")
            // Ensure app state is updated even if other steps fail
            await AppState.shared.setAuthenticatedWithoutRefresh(false)
        }
    }
    
    func refreshToken() async throws -> Bool {
        Logger.info("[AuthService] Attempting to refresh authentication token")
        guard let refreshToken = try? AuthenticationManager.shared.getRefreshToken() else {
            Logger.error("[AuthService] No refresh token available, cannot refresh")
            // Don't call forceLogout here, just return false
            return false
        }
        
        Logger.info("[AuthService] Refresh token found, length: \(refreshToken.count)")
        let request = RefreshTokenRequest(refresh_token: refreshToken)
        
        do {
            Logger.info("[AuthService] Sending refresh token request to server")
            let response: AuthResponse = try await apiClient.post(
                endpoint: APIConstants.refreshPath,
                body: request
            )
            
            Logger.info("[AuthService] Token refresh successful, received new tokens")
            try await AuthenticationManager.shared.saveTokens(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                expiresIn: response.expiresIn
            )
            Logger.info("[AuthService] New tokens saved successfully, expires in \(response.expiresIn) seconds")
            return true
        } catch {
            Logger.error("[AuthService] Token refresh failed: \(error)")
            // Don't call forceLogout here, let the caller handle failure
            return false
        }
    }
    
    func signIn(with provider: AuthProvider, idToken: String, displayName: String) async throws -> Bool {
        Logger.info("[AuthService] Attempting sign in with \(provider) provider")
        Logger.info("[AuthService] Display name: \(displayName), ID token length: \(idToken.count)")
        
        let request = ThirdPartyAuthRequest(idToken: idToken, displayName: displayName)
        
        do {
            Logger.info("[AuthService] Sending authentication request to \(provider.endpoint)")
            let response: AuthResponse = try await apiClient.post(
                endpoint: provider.endpoint,
                body: request
            )
            
            Logger.info("[AuthService] Authentication successful with \(provider) provider")
            try await AuthenticationManager.shared.saveTokens(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                expiresIn: response.expiresIn
            )
            Logger.info("[AuthService] Authentication tokens saved successfully, expires in \(response.expiresIn) seconds")
            
            return true
        } catch {
            Logger.error("[AuthService] \(provider) authentication failed: \(error)")
            throw error
        }
    }
}
