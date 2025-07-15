struct APIConstants {
    // Base URL for the API (using localhost for now)
    // static let baseURL = "http://localhost:8080"
    static let baseURL = "https://carbn-test-01.mzinck.com"
    
    // Endpoint paths
    static let loginPath = "/login"
    static let logoutPath = "/auth/logout"
    static let refreshPath = "/auth/refresh"
    static let googleAuthPath = "/auth/google"
    static let registerPath = "/register"
    static let authStatusPath = "/auth/status"
    static let userDetailsPath = "/user/{id}/details"
    static let uploadProfilePicturePath = "/user/profile/picture"
    static func getUserDetailsPath(userId: Int) -> String {
        return "/user/\(userId)/details"
    }
    
    // OAuth Client IDs (loaded from Info.plist)
    static var googleClientId: String {
        Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String ?? ""
    }
    static var googleServerClientId: String {
        Bundle.main.object(forInfoDictionaryKey: "GIDServerClientID") as? String ?? ""
    }
    
    // HTTP Headers
    struct Headers {
        static let authorization = "Authorization"
        static let contentType = "Content-Type"
        static let json = "application/json"
    }
    
    // Image Constants
    struct Image {
        static let profilePictureSize = 512
    }
}
