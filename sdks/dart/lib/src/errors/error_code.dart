/// Numeric error codes used to categorize SDK errors.
enum ErrorCode {
  /// Network-level failure (DNS, TCP, TLS).
  network(1000),

  /// Request timed out.
  timeout(1001),

  /// Authentication failure (invalid or expired API key).
  authentication(2000),

  /// Authorization failure (insufficient permissions).
  authorization(2001),

  /// Request validation error (bad parameters).
  validation(3000),

  /// Requested resource not found.
  notFound(3001),

  /// Rate limit exceeded.
  rateLimited(3002),

  /// Server-side error.
  serverError(4000),

  /// Service unavailable (maintenance, overload).
  serviceUnavailable(4001),

  /// Circuit breaker is open; requests are being rejected.
  circuitBreakerOpen(5000),

  /// An unknown or unexpected error occurred.
  unknown(9999);

  /// The numeric code for this error variant.
  final int code;

  const ErrorCode(this.code);

  /// Returns `true` if the error is potentially recoverable via retry.
  bool get isRecoverable {
    switch (this) {
      case ErrorCode.network:
      case ErrorCode.timeout:
      case ErrorCode.rateLimited:
      case ErrorCode.serverError:
      case ErrorCode.serviceUnavailable:
        return true;
      default:
        return false;
    }
  }

  /// Returns the human-readable label for this error code.
  String get label {
    switch (this) {
      case ErrorCode.network:
        return 'NETWORK_ERROR';
      case ErrorCode.timeout:
        return 'TIMEOUT_ERROR';
      case ErrorCode.authentication:
        return 'AUTHENTICATION_ERROR';
      case ErrorCode.authorization:
        return 'AUTHORIZATION_ERROR';
      case ErrorCode.validation:
        return 'VALIDATION_ERROR';
      case ErrorCode.notFound:
        return 'NOT_FOUND';
      case ErrorCode.rateLimited:
        return 'RATE_LIMITED';
      case ErrorCode.serverError:
        return 'SERVER_ERROR';
      case ErrorCode.serviceUnavailable:
        return 'SERVICE_UNAVAILABLE';
      case ErrorCode.circuitBreakerOpen:
        return 'CIRCUIT_BREAKER_OPEN';
      case ErrorCode.unknown:
        return 'UNKNOWN_ERROR';
    }
  }

  @override
  String toString() => label;
}
