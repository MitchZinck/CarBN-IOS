// MARK: - UserManager.swift
import Foundation
import UIKit

@Observable
@MainActor
final class UserManager {
    static let shared = UserManager()
    private let profilePictureKey = "cached_profile_picture"
    
    // Make currentUser observable
    private(set) var currentUser: User? = nil
    
    private(set) var cachedProfileImage: UIImage? = nil {
        didSet {
            if let data = cachedProfileImage?.jpegData(compressionQuality: 1.0) {
                UserDefaults.standard.set(data, forKey: profilePictureKey)
                Logger.info("[UserManager] Profile image cached successfully, size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
            } else {
                UserDefaults.standard.removeObject(forKey: profilePictureKey)
                Logger.info("[UserManager] Cached profile image cleared from local storage")
            }
        }
    }
    
    init() {
        Logger.info("[UserManager] Initializing UserManager")
        
        // Only load cached profile image, not user data
        if let data = UserDefaults.standard.data(forKey: profilePictureKey),
           let image = UIImage(data: data) {
            self.cachedProfileImage = image
            Logger.info("[UserManager] Loaded cached profile image, size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
        } else {
            Logger.info("[UserManager] No cached profile image found")
        }
        Logger.info("[UserManager] Initialization completed")
    }
    
    func fetchAndUpdateUserDetails(forceRefresh: Bool = false) async throws {
        // Always fetch from server
        Logger.info("[UserManager] Fetching user details from server")
        do {
            let user: User = try await APIClient.shared.get(endpoint: APIConstants.getUserDetailsPath(userId: -1))
            currentUser = user
            Logger.info("[UserManager] User details for user ID \(user.id) successfully fetched")
            
            // Update profile picture if it exists and we don't have it cached
            if cachedProfileImage == nil || forceRefresh,
               let profilePicturePath = user.profilePicture,
               let url = URL(string: APIConstants.baseURL + "/\(profilePicturePath)") {
                Logger.info("[UserManager] Fetching user profile picture from URL: \(url.absoluteString)")
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let image = UIImage(data: data) {
                    cachedProfileImage = image
                    Logger.info("[UserManager] Profile picture successfully fetched and cached, size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
                } else {
                    Logger.warning("[UserManager] Failed to download or process profile picture")
                }
            }
        } catch {
            Logger.error("[UserManager] Failed to fetch user details: \(error)")
            throw error
        }
    }
    
    func clearUser() {
        Logger.info("[UserManager] Clearing user data and profile picture")
        UserDefaults.standard.removeObject(forKey: profilePictureKey)
        UserDefaults.standard.synchronize()
        currentUser = nil
        cachedProfileImage = nil
        Task {
            Logger.info("[UserManager] Clearing authentication tokens")
            await AuthenticationManager.shared.clearTokens()
            // No longer calling UserCache.shared.clearCache() as we're removing local data caching
            Logger.info("[UserManager] User data cleared")
        }
        Logger.info("[UserManager] User and profile picture cleared from UserDefaults")
    }
    
    func updateCurrentUser(_ user: User) {
        Logger.info("[UserManager] Updating current user data for user ID: \(user.id)")
        currentUser = user
    }
    
    func updateProfileImage(_ image: UIImage) {
        Logger.info("[UserManager] Updating profile image, size: \(image.size.width)x\(image.size.height)")
        cachedProfileImage = image
    }
    
    func updateUserCurrency(_ newAmount: Int) {
        if var updatedUser = currentUser {
            let oldAmount = updatedUser.currency
            updatedUser.currency = newAmount
            currentUser = updatedUser
            Logger.info("[UserManager] Updated user currency from \(oldAmount) to \(newAmount) (change: \(newAmount - oldAmount))")
        } else {
            Logger.warning("[UserManager] Attempted to update currency but no current user exists")
        }
    }
}
