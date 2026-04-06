package com.sdk_tpl.http

import com.sdk_tpl.config.SdkTplConfig
import com.sdk_tpl.errors.ErrorCode
import com.sdk_tpl.errors.ErrorSanitizer
import com.sdk_tpl.errors.SdkTplException
import com.sdk_tpl.security.Security
import com.sdk_tpl.utils.Version
import io.ktor.client.*
import io.ktor.client.engine.cio.*
import io.ktor.client.request.*
import io.ktor.client.statement.*
import io.ktor.http.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject

/**
 * HTTP client for making API requests with retry and circuit breaker support.
 *
 * Uses Ktor CIO engine for non-blocking, coroutine-friendly HTTP.
 */
class HttpClient(private val config: SdkTplConfig) {

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    private val client = io.ktor.client.HttpClient(CIO) {
        engine {
            requestTimeout = config.timeout
        }
    }

    private val retryHandler = RetryHandler(config.retryConfig)
    private val circuitBreaker = CircuitBreaker(config.circuitBreakerConfig)

    @Volatile
    private var currentApiKey: String = config.apiKey

    @Volatile
    private var rotatedToSecondary: Boolean = false

    private val keyRotationMutex = Mutex()

    /**
     * Performs a GET request.
     *
     * @param path API endpoint path.
     * @return Parsed JSON response.
     */
    suspend fun get(path: String): JsonObject {
        return executeWithResilience {
            val response = client.get(buildUrl(path)) {
                applyHeaders()
            }
            handleResponse(response)
        }
    }

    /**
     * Performs a POST request.
     *
     * @param path API endpoint path.
     * @param body Optional JSON body.
     * @return Parsed JSON response.
     */
    suspend fun post(path: String, body: JsonObject? = null): JsonObject {
        return executeWithResilience {
            // Serialize body once; use the same string for both signing and sending
            val bodyString = body?.let { json.encodeToString(JsonObject.serializer(), it) } ?: ""
            val response = client.post(buildUrl(path)) {
                applyHeaders(bodyString)
                if (body != null) {
                    contentType(ContentType.Application.Json)
                    setBody(bodyString)
                }
            }
            handleResponse(response)
        }
    }

    /**
     * Performs a PUT request.
     *
     * @param path API endpoint path.
     * @param body Optional JSON body.
     * @return Parsed JSON response.
     */
    suspend fun put(path: String, body: JsonObject? = null): JsonObject {
        return executeWithResilience {
            // Serialize body once; use the same string for both signing and sending
            val bodyString = body?.let { json.encodeToString(JsonObject.serializer(), it) } ?: ""
            val response = client.put(buildUrl(path)) {
                applyHeaders(bodyString)
                if (body != null) {
                    contentType(ContentType.Application.Json)
                    setBody(bodyString)
                }
            }
            handleResponse(response)
        }
    }

    /**
     * Performs a DELETE request.
     *
     * @param path API endpoint path.
     * @return Parsed JSON response.
     */
    suspend fun delete(path: String): JsonObject {
        return executeWithResilience {
            val response = client.delete(buildUrl(path)) {
                applyHeaders()
            }
            handleResponse(response)
        }
    }

    /**
     * Closes the underlying Ktor HTTP client.
     */
    fun close() {
        client.close()
    }

    private fun buildUrl(path: String): String {
        val base = config.resolvedBaseUrl().trimEnd('/')
        val cleanPath = path.trimStart('/')
        return "$base/$cleanPath"
    }

    private fun HttpRequestBuilder.applyHeaders(bodyString: String = "") {
        header("X-API-Key", currentApiKey)
        header("User-Agent", "sdk_tpl-kotlin/${Version.SDK_VERSION}")
        header("Accept", "application/json")

        // Add HMAC signing headers when request signing is enabled
        if (config.enableRequestSigning) {
            val timestamp = System.currentTimeMillis().toString()
            val message = "$timestamp.$bodyString"
            val signature = Security.hmacSign(message, currentApiKey)
            header("X-Timestamp", timestamp)
            header("X-Signature", signature)
            header("X-Key-Id", currentApiKey.take(8))
        }
    }

    private suspend fun handleResponse(response: HttpResponse): JsonObject {
        val bodyText = response.bodyAsText()
        val statusCode = response.status.value
        val requestId = response.headers["X-Request-Id"]

        if (statusCode in 200..299) {
            return try {
                json.decodeFromString<JsonObject>(bodyText)
            } catch (e: Exception) {
                throw SdkTplException.serverError(
                    "Failed to parse response body: ${e.message}",
                    statusCode
                )
            }
        }

        // Handle 401 with key rotation: only the first coroutine rotates the key.
        if (statusCode == 401
            && !rotatedToSecondary
            && !config.secondaryApiKey.isNullOrEmpty()
        ) {
            keyRotationMutex.withLock {
                if (!rotatedToSecondary) {
                    rotatedToSecondary = true
                    currentApiKey = config.secondaryApiKey!!
                }
            }
            // Throw a new recoverable exception so the retry handler re-executes
            // the request with the rotated key. statusCode is intentionally omitted
            // so the retry handler does not reject it as a non-retryable status.
            throw SdkTplException(
                message = "Primary API key rejected, rotating to secondary key",
                errorCode = ErrorCode.AUTHENTICATION_ERROR,
                recoverable = true,
                requestId = requestId
            )
        }

        val message = if (config.enableErrorSanitization) {
            ErrorSanitizer.sanitize(bodyText)
        } else {
            bodyText
        }

        throw SdkTplException.fromStatusCode(statusCode, message, requestId)
    }

    private suspend fun <T> executeWithResilience(block: suspend () -> T): T {
        return retryHandler.executeWithRetry {
            circuitBreaker.execute { block() }
        }
    }
}
