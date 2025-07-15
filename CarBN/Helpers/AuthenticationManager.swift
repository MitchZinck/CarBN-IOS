// MARK: - AuthenticationManager.swift
import Foundation
import Security

enum KeychainError: Error {
    case saveFailure
    case itemNotFound
    case invalidData
    case invalidToken
    case tokenExpired
}

@MainActor
final class AuthenticationManager {
    static let shared = AuthenticationManager()
    private init() {}
    
    private let tokenKey = "authToken"
    private let refreshTokenKey = "refreshToken"
    private let tokenExpiryKey = "tokenExpiry"
    private let queue = DispatchQueue(label: "com.carbn.keychain", qos: .userInitiated)
    
    func saveTokens(accessToken: String, refreshToken: String, expiresIn: Int) async throws {
        Logger.info("Saving new authentication tokens")
        guard !accessToken.isEmpty, !refreshToken.isEmpty else {
            Logger.error("Invalid tokens provided")
            throw KeychainError.invalidToken
        }
        
        // Calculate expiry date
        let expiryDate = Date().addingTimeInterval(TimeInterval(expiresIn))
        Logger.info("Token expiry set to: \(expiryDate.formattedForDisplay())")
        
        try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                do {
                    try await self.save(token: accessToken, key: self.tokenKey)
                    try await self.save(token: refreshToken, key: self.refreshTokenKey)
                    UserDefaults.standard.set(expiryDate.timeIntervalSince1970, forKey: self.tokenExpiryKey)
                    Logger.info("Authentication tokens saved successfully")
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func getAccessToken() throws -> String {
        // Skip expiry check if token doesn't exist
        guard let token = try? getToken(key: tokenKey) else {
            throw KeychainError.itemNotFound
        }
        
        if isTokenExpired() {
            throw KeychainError.tokenExpired
        }
        return token
    }
    
    func getRefreshToken() throws -> String {
        Logger.info("Retrieving refresh token")
        return try getToken(key: refreshTokenKey)
    }
    
    func isLoggedIn() -> Bool {
        Logger.info("Checking authentication status")
        guard let token = try? getToken(key: tokenKey),
              !token.isEmpty,
              !isTokenExpired() else {
            Logger.info("User is not authenticated")
            return false
        }
        Logger.info("User is authenticated with valid token")
        return true
    }
    
    func clearTokens() async {
        Logger.info("Clearing authentication tokens")
        // Clear expiry first to prevent token checks during cleanup
        UserDefaults.standard.removeObject(forKey: self.tokenExpiryKey)
        await delete(key: self.tokenKey)
        await delete(key: self.refreshTokenKey)
        Logger.info("Authentication tokens successfully cleared")
    }
    
    private func isTokenExpired() -> Bool {
        let expiryTimeInterval = UserDefaults.standard.double(forKey: tokenExpiryKey)
        let expiryDate = Date(timeIntervalSince1970: expiryTimeInterval)
        let isExpired = Date() >= expiryDate
        Logger.info("Token expiration check - Expires: \(expiryDate.formattedForDisplay()), Expired: \(isExpired)")
        return isExpired
    }
    
    private func save(token: String, key: String) async throws {
        Logger.info("Saving token to keychain: \(key)")
        let data = Data(token.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        var status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            Logger.info("Updating existing token in keychain")
            let updateQuery = [kSecValueData: data] as CFDictionary
            status = SecItemUpdate(query as CFDictionary, updateQuery)
        } else if status == errSecItemNotFound {
            Logger.info("Creating new token entry in keychain")
            status = SecItemAdd(query as CFDictionary, nil)
        }
        
        guard status == errSecSuccess else {
            Logger.error("Failed to save token to keychain: \(status)")
            throw KeychainError.saveFailure
        }
        Logger.info("Token saved successfully to keychain")
    }
    
    private func getToken(key: String) throws -> String {
        Logger.info("Retrieving token from keychain: \(key)")
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: kCFBooleanTrue!,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess else {
            Logger.error("Failed to retrieve token from keychain: \(status)")
            throw KeychainError.itemNotFound
        }
        
        guard let data = item as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else {
            Logger.error("Retrieved invalid token data from keychain")
            throw KeychainError.invalidData
        }
        
        Logger.info("Token retrieved successfully from keychain")
        return token
    }
    
    private func delete(key: String) async {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            Logger.error("Failed to delete token from keychain: \(status)")
        }
    }
}