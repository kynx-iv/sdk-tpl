package com.sdk_tpl.client

import com.sdk_tpl.config.SdkTplConfig
import com.sdk_tpl.errors.ErrorCode
import com.sdk_tpl.errors.SdkTplException
import com.sdk_tpl.http.HttpClient
import com.sdk_tpl.utils.Version
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonObject

/**
 * Main client for the {{SDK_NAME}} SDK.
 *
 * Usage:
 * ```kotlin
 * val client = SdkTplClient(
 *     SdkTplConfig(apiKey = "your-api-key")
 * )
 * val health = client.healthCheck()
 * client.close()
 * ```
 */
open class SdkTplClient(private val config: SdkTplConfig) : java.io.Closeable {

    private val httpClient: HttpClient = HttpClient(config)

    @Volatile
    private var closed = false

    /**
     * Performs a health check against the API.
     *
     * @return [HealthResponse] containing status and version information.
     * @throws SdkTplException if the request fails.
     */
    suspend fun healthCheck(): HealthResponse {
        check(!closed) { "Client has been closed" }
        return try {
            withTimeout(config.timeout) {
                val response = httpClient.get("/health")
                HealthResponse(
                    status = response["status"]?.toString()?.trim('"') ?: "unknown",
                    version = response["version"]?.toString()?.trim('"') ?: "unknown",
                    apiVersion = response["apiVersion"]?.toString()?.trim('"') ?: "unknown"
                )
            }
        } catch (e: SdkTplException) {
            throw e
        } catch (e: Exception) {
            throw SdkTplException.networkError("Health check failed: ${e.message}", e)
        }
    }

    /**
     * Sends a request to the API.
     *
     * @param method HTTP method (GET, POST, PUT, DELETE).
     * @param path API endpoint path.
     * @param body Optional request body.
     * @return Parsed JSON response as [JsonObject].
     * @throws SdkTplException if the request fails.
     */
    suspend fun request(
        method: String,
        path: String,
        body: JsonObject? = null
    ): JsonObject {
        check(!closed) { "Client has been closed" }
        return withTimeout(config.timeout) {
            when (method.uppercase()) {
                "GET" -> httpClient.get(path)
                "POST" -> httpClient.post(path, body)
                "PUT" -> httpClient.put(path, body)
                "DELETE" -> httpClient.delete(path)
                else -> throw SdkTplException(
                    message = "Unsupported HTTP method: $method",
                    errorCode = ErrorCode.VALIDATION_ERROR
                )
            }
        }
    }

    /**
     * Closes the underlying HTTP client and releases resources.
     */
    override fun close() {
        closed = true
        httpClient.close()
    }
}

@Serializable
data class HealthResponse(
    val status: String,
    val version: String,
    val apiVersion: String
)
