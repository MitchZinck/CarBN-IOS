// MARK: - APIClient.swift
import Foundation

enum APIError: Error, Equatable {
    case invalidURL
    case network(Error)
    case invalidResponse
    case decoding(Error)
    case httpError(Int, Data?)
    case maxRetriesExceeded
    case tokenExpired
    case unauthorized
    case paymentRequired(String)
    
    var statusCode: Int? {
        guard case let .httpError(code, _) = self else { return nil }
        return code
    }
    
    var responseData: Data? {
        guard case let .httpError(_, data) = self else { return nil }
        return data
    }
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .network(let error):
            return error.localizedDescription
        case .invalidResponse:
            return "Invalid response"
        case .decoding(let error):
            return error.localizedDescription
        case .httpError(let code, _):
            return "HTTP error \(code)"
        case .maxRetriesExceeded:
            return "Max retries exceeded"
        case .tokenExpired:
            return "Token expired"
        case .unauthorized:
            return "Unauthorized"
        case .paymentRequired(let message):
            return message
        }
    }
    
    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.invalidResponse, .invalidResponse),
             (.maxRetriesExceeded, .maxRetriesExceeded),
             (.tokenExpired, .tokenExpired):
            return true
        case let (.httpError(code1, _), .httpError(code2, _)):
            return code1 == code2
        case let (.network(err1), .network(err2)):
            return err1.localizedDescription == err2.localizedDescription
        case let (.decoding(err1), .decoding(err2)):
            return err1.localizedDescription == err2.localizedDescription
        default:
            return false
        }
    }
}

@MainActor
final class APIClient {
    static let shared = APIClient()
    private var isLoggingOut = false
    var session: URLSession = .shared

    private let maxRetries = 1
    private let defaultTimeout: TimeInterval = 240
    private var isRefreshing = false

    // Update refresh token method to use new AuthResponse type
    func refreshToken(token: String) async throws -> AuthService.AuthResponse {
        let url = try makeURL(endpoint: APIConstants.refreshPath)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = defaultTimeout
        request.setValue(APIConstants.Headers.json, forHTTPHeaderField: APIConstants.Headers.contentType)
        
        let refreshRequest = AuthService.RefreshTokenRequest(refresh_token: token)
        request.httpBody = try JSONEncoder().encode(refreshRequest)
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                let decoder = JSONDecoder()
                return try decoder.decode(AuthService.AuthResponse.self, from: data)
            case 401:
                throw APIError.maxRetriesExceeded
            default:
                throw APIError.httpError(httpResponse.statusCode, data)
            }
        } catch {
            throw mapError(error, responseData: nil)
        }
    }
    
    func post<T: Decodable, U: Encodable>(
        endpoint: String,
        body: U,
        retry: Int = 0
    ) async throws -> T {
        // Set isLoggingOut flag before making the logout request
        if endpoint == APIConstants.logoutPath {
            isLoggingOut = true
        }
        
        let url = try makeURL(endpoint: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = defaultTimeout
        request.setValue(APIConstants.Headers.json, forHTTPHeaderField: APIConstants.Headers.contentType)
        
        // Skip auth header for auth-related endpoints and when logging out
        if !endpoint.contains("/auth/") && !isLoggingOut {
            do {
                let token = try AuthenticationManager.shared.getAccessToken()
                request.setValue("Bearer \(token)", forHTTPHeaderField: APIConstants.Headers.authorization)
            } catch KeychainError.tokenExpired {
                if !isRefreshing {
                    return try await handleTokenRefresh(request: request, body: body, retry: retry)
                } else {
                    throw APIError.tokenExpired
                }
            } catch {
                Logger.error("Failed to get access token: \(error)", file: #file, line: #line)
                if !isLoggingOut {
                    await AuthService.shared.forceLogout()
                }
                throw APIError.maxRetriesExceeded
            }
        }
        
        request.httpBody = try JSONEncoder().encode(body)
        Logger.info("POST request to \(url.absoluteString)", file: #file, line: #line)
        
        return try await executeRequest(request: request, retryCount: retry, originalBody: body)
    }
    
    func get<T: Decodable>(
        endpoint: String,
        retry: Int = 0
    ) async throws -> T {
        // Don't attempt API calls if we're logging out
        if isLoggingOut {
            throw APIError.unauthorized
        }
        
        let url = try makeURL(endpoint: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = defaultTimeout
        
        do {
            let token = try AuthenticationManager.shared.getAccessToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: APIConstants.Headers.authorization)
        } catch KeychainError.tokenExpired {
            if !isRefreshing {
                return try await handleTokenRefresh(request: request, retry: retry)
            } else {
                throw APIError.tokenExpired
            }
        } catch {
            Logger.error("Failed to get access token: \(error)", file: #file, line: #line)
            await AuthService.shared.forceLogout()
            throw APIError.maxRetriesExceeded
        }
        
        Logger.info("GET request to \(url.absoluteString)", file: #file, line: #line)
        return try await executeRequest(request: request, retryCount: retry)
    }
    
    /// DELETE request without a request body for endpoints that don't require a JSON payload
    func delete<T: Decodable>(
        endpoint: String,
        retry: Int = 0
    ) async throws -> T {
        // Don't attempt API calls if we're logging out
        if isLoggingOut {
            throw APIError.unauthorized
        }

        let url = try makeURL(endpoint: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = defaultTimeout

        do {
            let token = try AuthenticationManager.shared.getAccessToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: APIConstants.Headers.authorization)
        } catch KeychainError.tokenExpired {
            if !isRefreshing {
                return try await handleTokenRefresh(request: request, retry: retry)
            } else {
                throw APIError.tokenExpired
            }
        } catch {
            Logger.error("Failed to get access token: \(error)", file: #file, line: #line)
            await AuthService.shared.forceLogout()
            throw APIError.maxRetriesExceeded
        }

        Logger.info("DELETE request to \(url.absoluteString)", file: #file, line: #line)
        return try await executeRequest(request: request, retryCount: retry)
    }

    /// DELETE request with a request body support for endpoints requiring a JSON body
    func delete<T: Decodable, U: Encodable>(
        endpoint: String,
        body: U,
        retry: Int = 0
    ) async throws -> T {
        // Don't attempt API calls if we're logging out
        if isLoggingOut {
            throw APIError.unauthorized
        }

        let url = try makeURL(endpoint: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = defaultTimeout

        do {
            let token = try AuthenticationManager.shared.getAccessToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: APIConstants.Headers.authorization)
        } catch KeychainError.tokenExpired {
            if !isRefreshing {
                return try await handleTokenRefresh(request: request, body: body, retry: retry)
            } else {
                throw APIError.tokenExpired
            }
        } catch {
            Logger.error("Failed to get access token: \(error)", file: #file, line: #line)
            await AuthService.shared.forceLogout()
            throw APIError.maxRetriesExceeded
        }

        // Encode body
        request.httpBody = try JSONEncoder().encode(body)
        Logger.info("DELETE request to \(url.absoluteString)", file: #file, line: #line)
        return try await executeRequest(request: request, retryCount: retry, originalBody: body)
    }

    private func handleTokenRefresh<T: Decodable>(
        request: URLRequest,
        body: (any Encodable)? = nil,
        retry: Int
    ) async throws -> T {
        // Don't attempt refresh if we're logging out
        if isLoggingOut {
            throw APIError.maxRetriesExceeded
        }
        
        guard !isRefreshing else {
            // Wait for existing refresh to complete
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            return try await executeRequest(request: request, retryCount: retry, originalBody: body)
        }
        
        isRefreshing = true
        defer { isRefreshing = false }
        
        do {
            let refreshToken = try AuthenticationManager.shared.getRefreshToken()
            let response = try await self.refreshToken(token: refreshToken)
            
            Logger.info("Received new tokens from server, saving...")
            try await AuthenticationManager.shared.saveTokens(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                expiresIn: response.expiresIn
            )
            Logger.info("Tokens refreshed and saved successfully")
            
            var newRequest = request
            if let token = try? AuthenticationManager.shared.getAccessToken() {
                newRequest.setValue("Bearer \(token)", forHTTPHeaderField: APIConstants.Headers.authorization)
            }
            
            // Retry the original request with the new token
            do {
                if let body = body {
                    return try await executeRequest(
                        request: newRequest,
                        retryCount: 0,
                        originalBody: body
                    )
                } else {
                    return try await executeRequest(
                        request: newRequest,
                        retryCount: 0
                    )
                }
            } catch let error as APIError {
                // Don't force logout on business logic errors (400, 404)
                if case .httpError(let code, _) = error, code == 400 || code == 404 {
                    throw error
                }
                Logger.error("Request failed after token refresh: \(error)")
                await AuthService.shared.forceLogout()
                throw APIError.maxRetriesExceeded
            }
        } catch {
            Logger.error("Token refresh failed: \(error)")
            await AuthService.shared.forceLogout()
            throw APIError.maxRetriesExceeded
        }
    }
    
    private func executeRequest<T: Decodable>(
        request: URLRequest,
        retryCount: Int,
        originalBody: (any Encodable)? = nil
    ) async throws -> T {
        do {
            //log request
//            Logger.info("Request: \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")", file: #file, line: #line)
//            if let body = request.httpBody {
//                Logger.info("Request body: \(String(data: body, encoding: .utf8) ?? "")", file: #file, line: #line)
//            }
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                // After successful logout response, reset isLoggingOut
                if request.url?.path == APIConstants.logoutPath {
                    isLoggingOut = false
                }
                
                // Handle empty response when T is EmptyResponse
                if T.self == EmptyResponse.self && data.isEmpty {
                    return EmptyResponse() as! T
                }
                
                // Handle null responses for array types
                if !data.isEmpty {
                    let decoder = JSONDecoder()
                    if let stringValue = String(data: data, encoding: .utf8),
                       stringValue.trimmingCharacters(in: .whitespacesAndNewlines) == "null",
                       let emptyArray = Array<Any>() as? T {
                        return emptyArray
                    }
                    return try decoder.decode(T.self, from: data)
                }
                
                throw APIError.invalidResponse
                
            case 401:
                // Don't retry or refresh token if we're logging out
                if isLoggingOut {
                    throw APIError.unauthorized
                }
                
                // Check if we've exceeded retry attempts
                guard retryCount < maxRetries else {
                    Logger.error("Max retries exceeded", file: #file, line: #line)
                    throw APIError.maxRetriesExceeded
                }
                
                // If this is the refresh token endpoint, don't retry
                if request.url?.path == APIConstants.refreshPath {
                    Logger.error("Refresh token is invalid", file: #file, line: #line)
                    throw APIError.maxRetriesExceeded
                }
                
                // For other endpoints, attempt token refresh
                if originalBody != nil {
                    return try await handleTokenRefresh(
                        request: request,
                        body: originalBody,
                        retry: retryCount
                    )
                } else {
                    return try await handleTokenRefresh(
                        request: request,
                        retry: retryCount
                    )
                }
                
            default:
                throw APIError.httpError(httpResponse.statusCode, data)
            }
        } catch {
            throw mapError(error, responseData: nil)
        }
    }

    
    public func makeURL(endpoint: String) throws -> URL {
        guard let url = URL(string: APIConstants.baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        return url
    }
    
    private func mapError(_ error: Error, responseData: Data?) -> APIError {
        switch error {
        case let apiError as APIError:
            return apiError
        case let urlError as URLError:
            return .network(urlError)
        case let decodingError as DecodingError:
            return .decoding(decodingError)
        default:
            return .network(error)
        }
    }

    public func setIsLoggingOut(_ isLoggingOut: Bool) {
        self.isLoggingOut = isLoggingOut
    }
}

extension APIClient {
    func setSession(_ session: URLSession) {
        self.session = session
        self.isLoggingOut = false
    }
}
