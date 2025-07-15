// filepath: /Users/mitchell.zinck/Documents/CarBN/CarBNTests/ProfilePictureServiceTests.swift
import XCTest
@testable import CarBN

final class ProfilePictureServiceIntegrationTests: XCTestCase {
    private enum TestConstants {
        static let testTimeout: TimeInterval = 10
    }

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        APIClient.shared.setSession(URLSession.shared)
        // Ensure we're logged in before each test
        try await AuthService.shared.login(
            email: "test@carbn.com",
            password: "TestPassword123!"
        )
    }

    @MainActor
    override func tearDown() async throws {
        try await super.tearDown()
    }
    
    @MainActor
    func testUploadProfilePicture() async throws {
        // Create a test image
        let size = CGSize(width: APIConstants.Image.profilePictureSize, height: APIConstants.Image.profilePictureSize)
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.red.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        guard let testImage = UIGraphicsGetImageFromCurrentImageContext() else {
            XCTFail("Failed to create test image")
            return
        }
        
        // Test uploading the image
        try await ProfilePictureService.shared.uploadProfilePicture(testImage)
        
        // Verify the upload by checking user details
        try await UserManager.shared.fetchAndUpdateUserDetails()
        let user = UserManager.shared.currentUser
        XCTAssertNotNil(user?.profilePicture, "Profile picture should be set after upload")
    }
}