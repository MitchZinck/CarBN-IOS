import XCTest
@testable import CarBN

final class CarServiceIntegrationTests: XCTestCase {
    // Test Constants
    private enum TestConstants {
        static let testTimeout: TimeInterval = 10
    }

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        APIClient.shared.setSession(URLSession.shared)
    }

    @MainActor
    override func tearDown() async throws {
        try await super.tearDown()
    }
    
    @MainActor
    func testFetchAndStoreUserCars() async throws {
        // First ensure we're logged in
        try await AuthService.shared.login(
            email: "test@carbn.com",
            password: "TestPassword123!"
        )
        
        try await UserManager.shared.fetchAndUpdateUserDetails()
        // Test fetching and storing cars
        try await CarService.shared.fetchAndStoreUserCars()
        
        // Verify cars were stored locally
        // let localCars = CarService.shared.getLocalCars()
        // XCTAssertNotNil(localCars, "Local cars should not be nil after fetching")
    }
}
