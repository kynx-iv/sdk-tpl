package com.sdk_tpl.config

import kotlinx.serialization.Serializable

/**
 * Configuration for the {{SDK_NAME}} SDK client.
 *
 * @property apiKey Primary API key for authentication.
 * @property baseUrl Base URL for the API. Defaults based on {{ENV_MODE_VAR}}.
 * @property timeout Request timeout in milliseconds. Defaults to 30000.
 * @property retryConfig Configuration for retry behavior.
 * @property circuitBreakerConfig Configuration for the circuit breaker.
 * @property secondaryApiKey Optional secondary API key for failover.
 * @property enableRequestSigning Whether to enable HMAC request signing.
 * @property enableErrorSanitization Whether to sanitize PII from error messages.
 */
data class SdkTplConfig(
    val apiKey: String,
    val baseUrl: String? = null,
    val timeout: Long = 30_000L,
    val retryConfig: RetryConfig = RetryConfig(),
    val circuitBreakerConfig: CircuitBreakerConfig = CircuitBreakerConfig(),
    val secondaryApiKey: String? = null,
    val enableRequestSigning: Boolean = false,
    val enableErrorSanitization: Boolean = true
) {
    /**
     * Resolves the effective base URL.
     * Uses [baseUrl] if provided, otherwise falls back to the default API URL.
     */
    fun resolvedBaseUrl(): String {
        if (baseUrl != null) return baseUrl
        val mode = System.getenv("{{ENV_MODE_VAR}}")
        return if (mode == "local") "{{API_LOCAL_URL}}" else "{{API_BASE_URL}}"
    }

    init {
        require(apiKey.isNotBlank()) { "API key must not be blank" }
        require(timeout > 0) { "Timeout must be positive" }
    }
}

/**
 * Configuration for retry behavior on failed requests.
 *
 * @property maxRetries Maximum number of retry attempts. Defaults to 3.
 * @property baseDelayMs Base delay in milliseconds for exponential backoff. Defaults to 1000.
 * @property maxDelayMs Maximum delay in milliseconds between retries. Defaults to 30000.
 * @property retryableStatusCodes HTTP status codes that trigger a retry.
 */
data class RetryConfig(
    val maxRetries: Int = 3,
    val baseDelayMs: Long = 1_000L,
    val maxDelayMs: Long = 30_000L,
    val retryableStatusCodes: Set<Int> = setOf(408, 429, 500, 502, 503, 504)
) {
    init {
        require(maxRetries >= 0) { "maxRetries must be non-negative" }
        require(baseDelayMs > 0) { "baseDelayMs must be positive" }
        require(maxDelayMs >= baseDelayMs) { "maxDelayMs must be >= baseDelayMs" }
    }
}

/**
 * Configuration for the circuit breaker.
 *
 * @property failureThreshold Number of failures before the circuit opens. Defaults to 5.
 * @property resetTimeoutMs Time in milliseconds before attempting to close the circuit. Defaults to 60000.
 * @property halfOpenMaxRequests Maximum requests allowed in half-open state. Defaults to 1.
 */
data class CircuitBreakerConfig(
    val failureThreshold: Int = 5,
    val resetTimeoutMs: Long = 30_000L,
    val halfOpenMaxRequests: Int = 1
) {
    init {
        require(failureThreshold > 0) { "failureThreshold must be positive" }
        require(resetTimeoutMs > 0) { "resetTimeoutMs must be positive" }
        require(halfOpenMaxRequests > 0) { "halfOpenMaxRequests must be positive" }
    }
}
