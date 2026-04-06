import Foundation

/// Categorised error codes used throughout the SdkTpl Swift SDK.
public enum ErrorCode: String, Sendable, CaseIterable {
    // Initialisation
    case initFailed = "INIT_FAILED"
    case initTimeout = "INIT_TIMEOUT"

    // Authentication
    case authInvalidKey = "AUTH_INVALID_KEY"
    case authExpiredKey = "AUTH_EXPIRED_KEY"
    case authMissingKey = "AUTH_MISSING_KEY"
    case authUnauthorized = "AUTH_UNAUTHORIZED"

    // Network
    case networkError = "NETWORK_ERROR"
    case networkTimeout = "NETWORK_TIMEOUT"
    case networkRetryLimit = "NETWORK_RETRY_LIMIT"
    case networkServiceUnavailable = "NETWORK_SERVICE_UNAVAILABLE"

    // Circuit breaker
    case circuitOpen = "CIRCUIT_OPEN"

    // Configuration
    case configInvalidUrl = "CONFIG_INVALID_URL"
    case configMissingRequired = "CONFIG_MISSING_REQUIRED"

    // Security
    case securityPiiDetected = "SECURITY_PII_DETECTED"
    case securitySignatureInvalid = "SECURITY_SIGNATURE_INVALID"

    // Validation
    case validationError = "VALIDATION_ERROR"

    /// Stable numeric identifier for this error code.
    public var numericCode: Int {
        switch self {
        case .initFailed:                return 1000
        case .initTimeout:               return 1001
        case .authInvalidKey:            return 1100
        case .authExpiredKey:            return 1101
        case .authMissingKey:            return 1102
        case .authUnauthorized:          return 1103
        case .networkError:              return 1200
        case .networkTimeout:            return 1201
        case .networkRetryLimit:         return 1202
        case .networkServiceUnavailable: return 1203
        case .circuitOpen:               return 1300
        case .configInvalidUrl:          return 1400
        case .configMissingRequired:     return 1401
        case .securityPiiDetected:       return 1500
        case .securitySignatureInvalid:  return 1501
        case .validationError:           return 1600
        }
    }

    /// Whether errors with this code represent transient failures that may
    /// succeed on retry.
    public var isRecoverable: Bool {
        switch self {
        case .networkError,
             .networkTimeout,
             .networkRetryLimit,
             .networkServiceUnavailable,
             .circuitOpen:
            return true
        default:
            return false
        }
    }
}

/// The primary error type returned by the SdkTpl Swift SDK.
///
/// Carries structured information about the error including its category,
/// recoverability, and optional details.
public struct SdkTplError: Error, Sendable, CustomStringConvertible {

    /// Categorised error code.
    public let code: ErrorCode

    /// Human-readable error message.
    public let message: String

    /// Underlying error that caused this error, if any.
    public let cause: Error?

    /// HTTP status code, if applicable.
    public let statusCode: Int?

    /// Suggested duration to wait before retrying.
    public let retryAfter: TimeInterval?

    /// Request ID returned by the server, if available.
    public let requestId: String?

    /// Time the error was created.
    public let timestamp: Date

    /// Additional structured error details.
    public let details: [String: String]

    // MARK: - Initialisation

    public init(
        code: ErrorCode,
        message: String,
        cause: Error? = nil,
        statusCode: Int? = nil,
        retryAfter: TimeInterval? = nil,
        requestId: String? = nil,
        details: [String: String] = [:]
    ) {
        self.code = code
        self.message = message
        self.cause = cause
        self.statusCode = statusCode
        self.retryAfter = retryAfter
        self.requestId = requestId
        self.timestamp = Date()
        self.details = details
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        if let cause = cause {
            return "[\(code.rawValue)] \(message): \(cause.localizedDescription)"
        }
        return "[\(code.rawValue)] \(message)"
    }

    // MARK: - Convenience

    /// Whether this error is recoverable (i.e., the operation may succeed if retried).
    public var isRecoverable: Bool {
        code.isRecoverable
    }

    /// Returns a copy of this error with additional details merged in.
    public func withDetails(_ extra: [String: String]) -> SdkTplError {
        var merged = details
        for (key, value) in extra {
            merged[key] = value
        }
        return SdkTplError(
            code: code,
            message: message,
            cause: cause,
            statusCode: statusCode,
            retryAfter: retryAfter,
            requestId: requestId,
            details: merged
        )
    }

    // MARK: - Factory Methods

    /// Creates a recoverable network error.
    public static func networkError(_ message: String, cause: Error? = nil) -> SdkTplError {
        SdkTplError(code: .networkError, message: message, cause: cause)
    }

    /// Creates a non-recoverable timeout error.
    public static func timeoutError(_ message: String) -> SdkTplError {
        SdkTplError(code: .networkTimeout, message: message)
    }

    /// Creates a non-recoverable authentication error.
    public static func authenticationError(_ message: String) -> SdkTplError {
        SdkTplError(code: .authUnauthorized, message: message, statusCode: 401)
    }

    /// Creates a non-recoverable security error.
    public static func securityError(_ message: String) -> SdkTplError {
        SdkTplError(code: .securityPiiDetected, message: message)
    }

    /// Creates a circuit-open error with a retry-after hint.
    public static func circuitOpenError(retryAfter: TimeInterval) -> SdkTplError {
        SdkTplError(
            code: .circuitOpen,
            message: "Circuit breaker is open. Retry after \(Int(retryAfter))s.",
            retryAfter: retryAfter
        )
    }

    /// Creates an error from an HTTP response status code and body.
    public static func fromResponse(statusCode: Int, body: String?) -> SdkTplError {
        switch statusCode {
        case 401:
            return SdkTplError(code: .authUnauthorized, message: body ?? "Unauthorized", statusCode: 401)
        case 403:
            return SdkTplError(code: .authInvalidKey, message: body ?? "Forbidden", statusCode: 403)
        case 408:
            return SdkTplError(code: .networkTimeout, message: body ?? "Request timeout", statusCode: 408)
        case 429:
            return SdkTplError(code: .networkRetryLimit, message: body ?? "Rate limited", statusCode: 429)
        case 500...599:
            return SdkTplError(code: .networkServiceUnavailable, message: body ?? "Server error", statusCode: statusCode)
        default:
            return SdkTplError(code: .networkError, message: body ?? "HTTP \(statusCode)", statusCode: statusCode)
        }
    }
}
