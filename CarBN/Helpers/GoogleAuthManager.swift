import Foundation
import GoogleSignIn
import GoogleSignInSwift

@MainActor
class GoogleAuthManager {
    static let shared = GoogleAuthManager()
    private var clientId: String { APIConstants.googleClientId } // Now dynamic
    
    private init() {}
    
    func signIn() async throws -> (idToken: String, displayName: String) {
        guard let presentingViewController = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController else {
            throw AuthError.invalidCredentials
        }
        
        let gidSignInResult = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: presentingViewController
        )
        
        guard let idToken = gidSignInResult.user.idToken?.tokenString else {
            throw AuthError.invalidToken
        }
        
        let displayName = gidSignInResult.user.profile?.name ?? ""
        return (idToken, displayName)
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }
}