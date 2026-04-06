import Foundation

/// Response returned by the health check endpoint.
public struct HealthResponse: Codable, Sendable {
    public let status: String
    public let timestamp: String
    public let version: String?
}

/// Main client for the {{SDK_NAME}} Swift SDK.
///
/// Create an instance with a ``SdkTplConfig`` and use it to interact with
/// the {{SDK_NAME}} API.
///
/// ```swift
/// let client = SdkTplClient(config: SdkTplConfig(apiKey: "your-api-key"))
/// let health = try await client.healthCheck()
/// print(health.status)
/// client.close()
/// ```
public final class SdkTplClient: @unchecked Sendable {

    private let httpClient: HttpClient
    private let config: SdkTplConfig

    // MARK: - Initialisation

    /// Creates a new {{SDK_NAME}} API client.
    ///
    /// - Parameter config: The client configuration including the API key.
    /// - Throws: A ``SdkTplError`` with code ``ErrorCode/authMissingKey``
    ///   when the API key is empty.
    public init(config: SdkTplConfig) throws {
        guard !config.apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw SdkTplError(
                code: .authMissingKey,
                message: "API key is required"
            )
        }

        self.config = config
        self.httpClient = HttpClient(apiKey: config.apiKey, config: config)
    }

    // MARK: - Public API

    /// Performs a health check against the {{SDK_NAME}} API.
    ///
    /// Use this to verify connectivity and that the API key is valid before
    /// issuing business requests.
    ///
    /// - Returns: A ``HealthResponse`` describing the API status.
    /// - Throws: A ``SdkTplError`` on network or authentication failures.
    public func healthCheck() async throws -> HealthResponse {
        let data = try await httpClient.request(method: "GET", path: "/health")
        let decoder = JSONDecoder()
        return try decoder.decode(HealthResponse.self, from: data)
    }

    /// Returns a read-only snapshot of the current configuration with
    /// sensitive fields (API keys) omitted.
    public func getConfig() -> [String: Any] {
        return [
            "baseUrl": config.baseUrl,
            "timeout": config.timeout,
            "maxRetries": config.retryConfig.maxRetries,
            "failureThreshold": config.circuitBreakerConfig.failureThreshold,
            "enableRequestSigning": config.enableRequestSigning,
            "enableErrorSanitization": config.enableErrorSanitization,
        ]
    }

    /// Releases any resources held by the client.
    ///
    /// Call this when the client is no longer needed.
    public func close() {
        httpClient.close()
    }
}
