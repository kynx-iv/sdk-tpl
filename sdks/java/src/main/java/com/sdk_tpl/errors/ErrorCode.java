package com.sdk_tpl.errors;

/**
 * Error codes for the {{SDK_NAME}} SDK.
 *
 * <p>Each code has a unique numeric identifier for programmatic handling.</p>
 */
public enum ErrorCode {

    // Network errors (1xxx)
    NETWORK_ERROR(1000, "Network error"),
    TIMEOUT_ERROR(1001, "Request timed out"),
    CONNECTION_REFUSED(1002, "Connection refused"),
    DNS_RESOLUTION_FAILED(1003, "DNS resolution failed"),

    // Authentication errors (2xxx)
    AUTHENTICATION_ERROR(2000, "Authentication failed"),
    INVALID_API_KEY(2001, "Invalid API key"),
    EXPIRED_API_KEY(2002, "API key has expired"),
    INSUFFICIENT_PERMISSIONS(2003, "Insufficient permissions"),

    // Validation errors (3xxx)
    VALIDATION_ERROR(3000, "Validation error"),
    INVALID_PARAMETER(3001, "Invalid parameter"),
    MISSING_REQUIRED_FIELD(3002, "Missing required field"),
    INVALID_FORMAT(3003, "Invalid format"),

    // Rate limiting errors (4xxx)
    RATE_LIMIT_ERROR(4000, "Rate limit exceeded"),
    QUOTA_EXCEEDED(4001, "Quota exceeded"),

    // Server errors (5xxx)
    SERVER_ERROR(5000, "Server error"),
    SERVICE_UNAVAILABLE(5001, "Service unavailable"),
    INTERNAL_SERVER_ERROR(5002, "Internal server error"),

    // Circuit breaker errors (6xxx)
    CIRCUIT_OPEN(6000, "Circuit breaker is open"),

    // Security errors (7xxx)
    SECURITY_ERROR(7000, "Security error"),
    SIGNATURE_MISMATCH(7001, "Request signature mismatch"),
    PII_DETECTED(7002, "PII detected in request"),

    // Unknown errors (9xxx)
    UNKNOWN_ERROR(9000, "Unknown error");

    private final int numericCode;
    private final String description;

    ErrorCode(int numericCode, String description) {
        this.numericCode = numericCode;
        this.description = description;
    }

    /**
     * Returns the numeric code for this error.
     *
     * @return the numeric code
     */
    public int getNumericCode() {
        return numericCode;
    }

    /**
     * Returns a human-readable description of this error.
     *
     * @return the description
     */
    public String getDescription() {
        return description;
    }

    /**
     * Finds an ErrorCode by its numeric code.
     *
     * @param numericCode the numeric code to look up
     * @return the matching ErrorCode, or {@link #UNKNOWN_ERROR} if not found
     */
    public static ErrorCode fromNumericCode(int numericCode) {
        for (ErrorCode code : values()) {
            if (code.numericCode == numericCode) {
                return code;
            }
        }
        return UNKNOWN_ERROR;
    }

    /**
     * Determines an ErrorCode from an HTTP status code.
     *
     * @param statusCode the HTTP status code
     * @return the corresponding ErrorCode
     */
    public static ErrorCode fromHttpStatus(int statusCode) {
        return switch (statusCode) {
            case 401 -> AUTHENTICATION_ERROR;
            case 403 -> INSUFFICIENT_PERMISSIONS;
            case 404 -> VALIDATION_ERROR;
            case 408 -> TIMEOUT_ERROR;
            case 422 -> INVALID_PARAMETER;
            case 429 -> RATE_LIMIT_ERROR;
            case 500 -> INTERNAL_SERVER_ERROR;
            case 502, 503 -> SERVICE_UNAVAILABLE;
            default -> {
                if (statusCode >= 400 && statusCode < 500) {
                    yield VALIDATION_ERROR;
                } else if (statusCode >= 500) {
                    yield SERVER_ERROR;
                }
                yield UNKNOWN_ERROR;
            }
        };
    }
}
