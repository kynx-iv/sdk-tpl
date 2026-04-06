import Foundation

/// Internal HTTP client that wraps `URLSession` with retry logic and
/// circuit breaking for the SdkTpl Swift SDK.
final class HttpClient: @unchecked Sendable {

    private let apiKey: String
    private let baseUrl: String
    private let timeout: TimeInterval
    private let retryHandler: RetryHandler
    private let circuitBreaker: CircuitBreaker
    private let session: URLSession
    private let config: SdkTplConfig

    // MARK: - Initialisation

    init(apiKey: String, config: SdkTplConfig) {
        self.apiKey = apiKey
        self.baseUrl = config.baseUrl.hasSuffix("/")
            ? String(config.baseUrl.dropLast())
            : config.baseUrl
        self.timeout = config.timeout
        self.config = config

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = config.timeout
        sessionConfig.timeoutIntervalForResource = config.timeout * 2
        self.session = URLSession(configuration: sessionConfig)

        self.retryHandler = RetryHandler(config: config.retryConfig)
        self.circuitBreaker = CircuitBreaker(config: config.circuitBreakerConfig)
    }

    // MARK: - Public API

    /// Sends an HTTP request to the API, wrapped with circuit breaker and
    /// retry logic.
    ///
    /// - Parameters:
    ///   - method: HTTP method (GET, POST, PUT, PATCH, DELETE).
    ///   - path: API path relative to the base URL.
    ///   - body: Optional request body data.
    ///   - headers: Additional headers to include.
    /// - Returns: The raw response data.
    /// - Throws: ``SdkTplError`` on failure.
    func request(
        method: String,
        path: String,
        body: Data? = nil,
        headers: [String: String] = [:]
    ) async throws -> Data {
        let fullPath = path.hasPrefix("/") ? path : "/\(path)"
        let urlString = "\(baseUrl)\(fullPath)"

        guard let url = URL(string: urlString) else {
            throw SdkTplError(
                code: .configInvalidUrl,
                message: "Invalid URL: \(urlString)"
            )
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.timeoutInterval = timeout

        // Standard headers
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue(sdkVersion, forHTTPHeaderField: "X-SDK-Version")
        urlRequest.setValue(
            "sdk_tpl-swift/\(sdkVersion)",
            forHTTPHeaderField: "User-Agent"
        )
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        // Request signing
        if config.enableRequestSigning {
            let timestamp = String(Int(Date().timeIntervalSince1970 * 1000))
            urlRequest.setValue(timestamp, forHTTPHeaderField: "X-Timestamp")
            urlRequest.setValue(
                String(apiKey.prefix(8)),
                forHTTPHeaderField: "X-Key-Id"
            )
            let bodyString = body.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let message = "\(timestamp).\(bodyString)"
            let signature = Security.generateHMACSHA256(message: message, key: apiKey)
            urlRequest.setValue(signature, forHTTPHeaderField: "X-Signature")
        }

        // Merge caller-supplied headers
        for (key, value) in headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        if let body = body {
            urlRequest.httpBody = body
        }

        // Capture as immutable for Sendable closure
        let finalRequest = urlRequest

        // Execute with retry + circuit breaker
        return try await retryHandler.execute { [self] in
            try await circuitBreaker.execute {
                try await self.performRequest(finalRequest, method: method, path: fullPath)
            }
        }
    }

    /// Resets the circuit breaker to its initial closed state.
    func close() {
        Task {
            await circuitBreaker.reset()
        }
    }

    // MARK: - Private

    /// Sanitises an error message if error sanitisation is enabled in the config.
    private func sanitize(_ message: String) -> String {
        guard config.enableErrorSanitization else { return message }
        return sanitizeErrorMessage(message)
    }

    private func performRequest(
        _ request: URLRequest,
        method: String,
        path: String
    ) async throws -> Data {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw SdkTplError.timeoutError(
                    sanitize("Request to \(method) \(path) timed out after \(Int(timeout))s")
                )
            case .notConnectedToInternet, .networkConnectionLost:
                throw SdkTplError.networkError(
                    sanitize("Network error during \(method) \(path)"),
                    cause: error
                )
            default:
                throw SdkTplError.networkError(
                    sanitize("Request failed: \(error.localizedDescription)"),
                    cause: error
                )
            }
        } catch {
            throw SdkTplError.networkError(
                sanitize("Unexpected error during \(method) \(path)"),
                cause: error
            )
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SdkTplError(
                code: .networkError,
                message: sanitize("Invalid response type")
            )
        }

        let statusCode = httpResponse.statusCode

        guard (200...299).contains(statusCode) else {
            let bodyString = String(data: data, encoding: .utf8)
            let rawError = SdkTplError.fromResponse(statusCode: statusCode, body: bodyString)
            if config.enableErrorSanitization {
                throw SdkTplError(
                    code: rawError.code,
                    message: sanitizeErrorMessage(rawError.message),
                    cause: rawError.cause,
                    statusCode: rawError.statusCode,
                    retryAfter: rawError.retryAfter,
                    requestId: rawError.requestId,
                    details: rawError.details
                )
            }
            throw rawError
        }

        // 204 No Content
        if statusCode == 204 {
            return Data("{}".utf8)
        }

        return data
    }
}
