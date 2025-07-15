import Combine
import SwiftUI
import Foundation
import AuthenticationServices

@Observable
@MainActor
final class AuthViewModel: NSObject, ASAuthorizationControllerDelegate {
    var isLoading = false
    var error: String?
    
    private let authService: AuthServiceProtocol
    private var pendingDisplayName: String?
    
    init(authService: AuthServiceProtocol? = nil) {
        self.authService = authService ?? AuthService.shared
        super.init()
        Logger.info("[AuthViewModel] Initialized with auth service")
    }
    
    func signInWithGoogle() async {
        Logger.info("[AuthViewModel] Starting Google sign-in process")
        await AuthenticationManager.shared.clearTokens()
        Logger.info("[AuthViewModel] Cleared existing authentication tokens")
        
        UserManager.shared.clearUser()
        Logger.info("[AuthViewModel] Cleared existing user data")
        
        Task {
            Logger.info("[AuthViewModel] Clearing user cache")
            await UserCache.shared.clearCache()
        }
        
        isLoading = true
        error = nil
        
        do {
            Logger.info("[AuthViewModel] Requesting Google authentication")
            let (idToken, displayName) = try await GoogleAuthManager.shared.signIn()
            Logger.info("[AuthViewModel] Google authentication successful for user: \(displayName)")
            
            Logger.info("[AuthViewModel] Initiating backend sign-in with Google credentials")
            let success = try await AuthService.shared.signIn(
                with: .google,
                idToken: idToken,
                displayName: displayName
            )
            
            if success {
                Logger.info("[AuthViewModel] Backend sign-in successful, updating app state")
                await AppState.shared.setAuthenticated(true)
            } else {
                Logger.warning("[AuthViewModel] Backend sign-in returned false")
            }
        } catch {
            Logger.error("[AuthViewModel] Google sign-in failed: \(error)")
            self.error = error.localizedDescription
        }
        
        isLoading = false
        Logger.info("[AuthViewModel] Google sign-in process completed, isLoading set to false")
    }
    
    func signInWithApple() async {
        Logger.info("[AuthViewModel] Starting Apple sign-in process")
        await AuthenticationManager.shared.clearTokens()
        Logger.info("[AuthViewModel] Cleared existing authentication tokens")
        
        UserManager.shared.clearUser()
        Logger.info("[AuthViewModel] Cleared existing user data")
        
        Task {
            Logger.info("[AuthViewModel] Clearing user cache")
            await UserCache.shared.clearCache()
        }
        
        isLoading = true
        error = nil
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName]
        
        Logger.info("[AuthViewModel] Configuring Apple authorization controller")
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        Logger.info("[AuthViewModel] Presenting Apple authentication dialog")
        controller.performRequests()
    }
    
    // MARK: - ASAuthorizationControllerDelegate
    
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Logger.info("[AuthViewModel] Apple authorization completed")
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = appleIDCredential.identityToken,
              let idToken = String(data: identityToken, encoding: .utf8) else {
            Logger.error("[AuthViewModel] Failed to extract Apple credentials")
            Task { @MainActor in
                self.error = "Failed to get Apple ID credentials"
                self.isLoading = false
            }
            return
        }
        
        // Get display name from credential or use existing one
        let displayName: String
        if let firstName = appleIDCredential.fullName?.givenName,
           let lastName = appleIDCredential.fullName?.familyName {
            displayName = "\(firstName) \(lastName)"
            Logger.info("[AuthViewModel] Using provided name from Apple: \(displayName)")
        } else {
            // If no name provided, use a default format
            displayName = "User\(Int.random(in: 1000...9999))"
            Logger.info("[AuthViewModel] No name provided by Apple, using generated name: \(displayName)")
        }
        
        Task { @MainActor in
            Logger.info("[AuthViewModel] Initiating backend sign-in with Apple credentials")
            do {
                let success = try await AuthService.shared.signIn(
                    with: .apple,
                    idToken: idToken,
                    displayName: displayName
                )
                
                if success {
                    Logger.info("[AuthViewModel] Apple backend sign-in successful, updating app state")
                    await AppState.shared.setAuthenticated(true)
                } else {
                    Logger.warning("[AuthViewModel] Apple backend sign-in returned false")
                }
            } catch {
                Logger.error("[AuthViewModel] Apple backend sign-in failed: \(error)")
                self.error = error.localizedDescription
            }
            self.isLoading = false
            Logger.info("[AuthViewModel] Apple sign-in process completed, isLoading set to false")
        }
    }
    
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Logger.error("[AuthViewModel] Apple authorization failed: \(error)")
        Task { @MainActor in
            self.error = error.localizedDescription
            self.isLoading = false
            Logger.info("[AuthViewModel] Apple sign-in error handling completed")
        }
    }
    
    func logout() async {
        Logger.info("[AuthViewModel] Starting logout process")
        isLoading = true
        error = nil
        
        do {
            Logger.info("[AuthViewModel] Requesting logout from AuthService")
            try await AuthService.shared.logout()
            Logger.info("[AuthViewModel] Logout completed successfully")
        } catch {
            Logger.error("[AuthViewModel] Logout failed: \(error)")
            self.error = error.localizedDescription
        }
        
        isLoading = false
        Logger.info("[AuthViewModel] Logout process completed, isLoading set to false")
    }
}
