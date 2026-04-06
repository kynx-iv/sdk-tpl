import Foundation

/// Configuration for retry behaviour on failed requests.
public struct RetryConfig: Sendable {
    /// Maximum number of retry attempts. Default: 3.
    public var maxRetries: Int

    /// Base delay between retries in seconds. Default: 1.0.
    public var baseDelay: TimeInterval

    /// Maximum delay between retries in seconds. Default: 30.0.
    public var maxDelay: TimeInterval

    /// HTTP status codes that trigger a retry.
    public var retryableStatusCodes: [Int]

    public init(
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        retryableStatusCodes: [Int] = [408, 429, 500, 502, 503, 504]
    ) {
        precondition(maxRetries >= 0, "maxRetries must be >= 0")
        precondition(baseDelay > 0, "baseDelay must be > 0")
        precondition(maxDelay >= baseDelay, "maxDelay must be >= baseDelay")
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.retryableStatusCodes = retryableStatusCodes
    }
}

/// Configuration for the circuit breaker.
public struct CircuitBreakerConfig: Sendable {
    /// Number of consecutive failures before the circuit opens. Default: 5.
    public var failureThreshold: Int

    /// Duration the circuit stays open before transitioning to half-open. Default: 30s.
    public var resetTimeout: TimeInterval

    /// Number of probe requests allowed in the half-open state. Default: 1.
    public var halfOpenRequests: Int

    public init(
        failureThreshold: Int = 5,
        resetTimeout: TimeInterval = 30.0,
        halfOpenRequests: Int = 1
    ) {
        precondition(failureThreshold >= 1, "failureThreshold must be >= 1")
        precondition(resetTimeout > 0, "resetTimeout must be > 0")
        self.failureThreshold = failureThreshold
        self.resetTimeout = resetTimeout
        self.halfOpenRequests = halfOpenRequests
    }
}

/// Default production base URL.
public let defaultBaseUrl = "{{API_BASE_URL}}"

/// Base URL used when running in local development mode.
public let localBaseUrl = "{{API_LOCAL_URL}}"

/// Resolves the base URL by checking the ``{{ENV_MODE_VAR}}`` environment
/// variable. Returns ``localBaseUrl`` when the value is `"local"`;
/// otherwise returns ``defaultBaseUrl``.
public func resolveBaseUrl() -> String {
    if let mode = ProcessInfo.processInfo.environment["{{ENV_MODE_VAR}}"],
       mode == "local" {
        return localBaseUrl
    }
    return defaultBaseUrl
}

/// Configuration for the SdkTpl client.
public struct SdkTplConfig: Sendable {

    /// Primary API key for authentication.
    public let apiKey: String

    /// Base URL of the SdkTpl API.
    public var baseUrl: String

    /// HTTP request timeout in seconds.
    public var timeout: TimeInterval

    /// Retry configuration.
    public var retryConfig: RetryConfig

    /// Circuit breaker configuration.
    public var circuitBreakerConfig: CircuitBreakerConfig

    /// Optional secondary API key for key rotation.
    public var secondaryApiKey: String?

    /// Enable HMAC request signing.
    public var enableRequestSigning: Bool

    /// Enable sanitisation of sensitive data in error messages.
    public var enableErrorSanitization: Bool

    /// Optional logger for SDK diagnostics. Defaults to `nil` (no logging).
    public var logger: (any SdkTplLogger)?

    public init(
        apiKey: String,
        baseUrl: String? = nil,
        timeout: TimeInterval = 30.0,
        retryConfig: RetryConfig = RetryConfig(),
        circuitBreakerConfig: CircuitBreakerConfig = CircuitBreakerConfig(),
        secondaryApiKey: String? = nil,
        enableRequestSigning: Bool = false,
        enableErrorSanitization: Bool = true,
        logger: (any SdkTplLogger)? = nil
    ) {
        self.apiKey = apiKey
        self.baseUrl = baseUrl ?? resolveBaseUrl()
        self.timeout = timeout
        self.retryConfig = retryConfig
        self.circuitBreakerConfig = circuitBreakerConfig
        self.secondaryApiKey = secondaryApiKey
        self.enableRequestSigning = enableRequestSigning
        self.enableErrorSanitization = enableErrorSanitization
        self.logger = logger
    }
}
