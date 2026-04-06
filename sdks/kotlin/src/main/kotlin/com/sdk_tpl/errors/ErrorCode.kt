package com.sdk_tpl.errors

/**
 * Enumeration of all error codes used by the {{SDK_NAME}} SDK.
 *
 * Each error code has a unique [numericCode] for programmatic handling
 * and logging.
 *
 * @property numericCode A unique integer identifier for the error.
 */
enum class ErrorCode(val numericCode: Int) {

    /** An unknown or unexpected error occurred. */
    UNKNOWN_ERROR(1000),

    /** A network-level error occurred (DNS, connection, etc.). */
    NETWORK_ERROR(1001),

    /** The request timed out. */
    TIMEOUT_ERROR(1002),

    /** Authentication failed (invalid or missing API key). */
    AUTHENTICATION_ERROR(2001),

    /** Access to the resource is forbidden. */
    FORBIDDEN_ERROR(2002),

    /** The requested resource was not found. */
    NOT_FOUND_ERROR(2003),

    /** Request validation failed. */
    VALIDATION_ERROR(3001),

    /** The API rate limit has been exceeded. */
    RATE_LIMIT_ERROR(3002),

    /** A server-side error occurred. */
    SERVER_ERROR(4001),

    /** The circuit breaker is open and rejecting requests. */
    CIRCUIT_BREAKER_OPEN(5001),

    /** Request signing failed. */
    SIGNING_ERROR(6001),

    /** A security-related error occurred. */
    SECURITY_ERROR(6002);

    companion object {
        /**
         * Finds an [ErrorCode] by its numeric code.
         *
         * @param code The numeric code to search for.
         * @return The matching [ErrorCode], or [UNKNOWN_ERROR] if not found.
         */
        fun fromNumericCode(code: Int): ErrorCode {
            return entries.find { it.numericCode == code } ?: UNKNOWN_ERROR
        }
    }
}
