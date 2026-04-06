package com.sdk_tpl.errors;

import java.time.Duration;
import java.time.Instant;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;

/**
 * Exception class for the {{SDK_NAME}} SDK.
 *
 * <p>Provides structured error information including error codes,
 * recoverability hints, and retry-after guidance.</p>
 *
 * <pre>{@code
 * try {
 *     client.healthCheck();
 * } catch (SdkTplException e) {
 *     if (e.isRecoverable()) {
 *         // Retry after suggested delay
 *         Thread.sleep(e.getRetryAfter() != null ? e.getRetryAfter() : 1000);
 *     }
 *     System.err.println("Error " + e.getNumericCode() + ": " + e.getMessage());
 * }
 * }</pre>
 */
public class SdkTplException extends RuntimeException {

    private final ErrorCode code;
    private final int numericCode;
    private final Integer statusCode;
    private final boolean recoverable;
    private final Long retryAfter;
    private final String requestId;
    private final long timestamp;

    /**
     * Creates a new SDK exception.
     *
     * @param message     the error message
     * @param code        the error code
     * @param statusCode  the HTTP status code (may be null)
     * @param recoverable whether the error is recoverable
     */
    public SdkTplException(String message, ErrorCode code, Integer statusCode, boolean recoverable) {
        this(message, code, statusCode, recoverable, null, null, null);
    }

    /**
     * Creates a new SDK exception with full details.
     *
     * @param message     the error message
     * @param code        the error code
     * @param statusCode  the HTTP status code (may be null)
     * @param recoverable whether the error is recoverable
     * @param retryAfter  suggested retry delay in milliseconds (may be null)
     * @param requestId   the request ID for tracing (may be null)
     * @param cause       the underlying cause (may be null)
     */
    public SdkTplException(String message, ErrorCode code, Integer statusCode,
                           boolean recoverable, Long retryAfter, String requestId,
                           Throwable cause) {
        super(message, cause);
        this.code = code;
        this.numericCode = code.getNumericCode();
        this.statusCode = statusCode;
        this.recoverable = recoverable;
        this.retryAfter = retryAfter;
        this.requestId = requestId;
        this.timestamp = Instant.now().toEpochMilli();
    }

    /**
     * Creates a network error exception.
     *
     * @param message the error message
     * @param cause   the underlying cause
     * @return a new SdkTplException
     */
    public static SdkTplException networkError(String message, Throwable cause) {
        return new SdkTplException(
                message,
                ErrorCode.NETWORK_ERROR,
                null,
                true,
                null,
                null,
                cause
        );
    }

    /**
     * Creates an authentication error exception.
     *
     * @param message the error message
     * @return a new SdkTplException
     */
    public static SdkTplException authenticationError(String message) {
        return new SdkTplException(
                message,
                ErrorCode.AUTHENTICATION_ERROR,
                401,
                false,
                null,
                null,
                null
        );
    }

    /**
     * Creates an exception from an HTTP response.
     *
     * @param statusCode   the HTTP status code
     * @param responseBody the response body
     * @param requestId    the request ID (may be null)
     * @return a new SdkTplException
     */
    public static SdkTplException fromResponse(int statusCode, String responseBody, String requestId) {
        return fromResponse(statusCode, responseBody, requestId, null);
    }

    /**
     * Creates an exception from an HTTP response with an optional Retry-After header value.
     *
     * @param statusCode       the HTTP status code
     * @param responseBody     the response body
     * @param requestId        the request ID (may be null)
     * @param retryAfterHeader the value of the Retry-After HTTP header (may be null)
     * @return a new SdkTplException
     */
    public static SdkTplException fromResponse(int statusCode, String responseBody,
                                               String requestId, String retryAfterHeader) {
        ErrorCode errorCode = ErrorCode.fromHttpStatus(statusCode);
        boolean recoverable = isRecoverableStatus(statusCode);
        Long retryAfter = null;

        if (statusCode == 429) {
            // First try the Retry-After HTTP header
            retryAfter = parseRetryAfterHeader(retryAfterHeader);
            // Fall back to parsing from the response body
            if (retryAfter == null) {
                retryAfter = parseRetryAfter(responseBody);
            }
        }

        String message = responseBody != null && !responseBody.isBlank()
                ? responseBody
                : errorCode.getDescription();

        return new SdkTplException(
                message,
                errorCode,
                statusCode,
                recoverable,
                retryAfter,
                requestId,
                null
        );
    }

    public ErrorCode getCode() {
        return code;
    }

    public int getNumericCode() {
        return numericCode;
    }

    public Integer getStatusCode() {
        return statusCode;
    }

    public boolean isRecoverable() {
        return recoverable;
    }

    public Long getRetryAfter() {
        return retryAfter;
    }

    public String getRequestId() {
        return requestId;
    }

    public long getTimestamp() {
        return timestamp;
    }

    @Override
    public String toString() {
        var sb = new StringBuilder("SdkTplException{");
        sb.append("code=").append(code);
        sb.append(", numericCode=").append(numericCode);
        if (statusCode != null) {
            sb.append(", statusCode=").append(statusCode);
        }
        sb.append(", recoverable=").append(recoverable);
        if (retryAfter != null) {
            sb.append(", retryAfter=").append(retryAfter);
        }
        if (requestId != null) {
            sb.append(", requestId='").append(requestId).append('\'');
        }
        sb.append(", message='").append(getMessage()).append('\'');
        sb.append('}');
        return sb.toString();
    }

    private static boolean isRecoverableStatus(int statusCode) {
        return statusCode == 408 || statusCode == 429 || statusCode == 500
                || statusCode == 502 || statusCode == 503 || statusCode == 504;
    }

    private static Long parseRetryAfterHeader(String headerValue) {
        if (headerValue == null || headerValue.isBlank()) {
            return null;
        }
        try {
            // Retry-After header value is in seconds; convert to milliseconds
            long seconds = Long.parseLong(headerValue.trim());
            if (seconds > 0) {
                return seconds * 1000;
            }
        } catch (NumberFormatException ignored) {
            // Header may contain an HTTP-date; attempt to parse it
            try {
                ZonedDateTime date = ZonedDateTime.parse(headerValue.trim(), DateTimeFormatter.RFC_1123_DATE_TIME);
                long diffMs = Duration.between(Instant.now(), date.toInstant()).toMillis();
                return diffMs > 0 ? diffMs : null;
            } catch (Exception alsoIgnored) {
                return null;
            }
        }
        return null;
    }

    private static Long parseRetryAfter(String responseBody) {
        if (responseBody == null) {
            return null;
        }
        try {
            // Attempt to parse a retry-after value from the response
            if (responseBody.contains("retry_after")) {
                int idx = responseBody.indexOf("retry_after");
                String sub = responseBody.substring(idx);
                String[] parts = sub.split("[:\\s,}\"]+");
                for (String part : parts) {
                    try {
                        long value = Long.parseLong(part.trim());
                        if (value > 0) {
                            return value;
                        }
                    } catch (NumberFormatException ignored) {
                        // continue scanning
                    }
                }
            }
        } catch (Exception ignored) {
            // Fall through
        }
        return null;
    }
}
