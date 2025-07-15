import XCTest
@testable import CarBN

final class AuthServiceIntegrationTests: XCTestCase {
    // Test Constants
    private enum TestConstants {
        static let validEmail = "test@carbn.com"
        static let validPassword = "TestPassword123!"
        static let validDisplayName = "Test User"
        static let testTimeout: TimeInterval = 10
        
        static func generateUniqueEmail() -> String {
            return "test\(Int(Date().timeIntervalSince1970))@carbn.com"
        }
    }

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        APIClient.shared.setSession(URLSession.shared)
    }

    @MainActor
    override func tearDown() async throws {
        await AuthenticationManager.shared.clearTokens()
        try await super.tearDown()
    }
    
    @MainActor
    func testRegisterIntegration() async throws {
        try await AuthService.shared.register(
            email: TestConstants.validEmail,
            password: TestConstants.validPassword,
            displayName: TestConstants.validDisplayName
        )
    }

    @MainActor
    func testLoginIntegration() async throws {
        try await AuthService.shared.login(
            email: TestConstants.validEmail,
            password: TestConstants.validPassword
        )
        
        let token = try AuthenticationManager.shared.getAccessToken()
        XCTAssertFalse(token.isEmpty)
    }

    @MainActor
    func testRefreshTokenIntegration() async throws {
        // First login to get initial tokens
        try await AuthService.shared.login(
            email: TestConstants.validEmail,
            password: TestConstants.validPassword
        )
        
        // Then try to refresh the token
        try await AuthService.shared.refreshToken()
        
        let token = try AuthenticationManager.shared.getAccessToken()
        XCTAssertFalse(token.isEmpty)
    }

    @MainActor
    func testLogoutIntegration() async throws {
        // First login
        try await AuthService.shared.login(
            email: TestConstants.validEmail,
            password: TestConstants.validPassword
        )
        
        // Then logout
        try await AuthService.shared.logout()
        
        // Verify tokens are cleared
        XCTAssertThrowsError(try AuthenticationManager.shared.getAccessToken())
    }
}
