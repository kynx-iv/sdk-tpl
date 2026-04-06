package com.sdk_tpl.http

import com.sdk_tpl.config.RetryConfig
import com.sdk_tpl.errors.SdkTplException
import kotlinx.coroutines.delay
import kotlin.math.min
import kotlin.random.Random

/**
 * Handles retry logic with exponential backoff and jitter.
 *
 * Uses Kotlin coroutine [delay] for non-blocking waits between attempts.
 */
class RetryHandler(private val config: RetryConfig) {

    /**
     * Executes [block] with retry logic.
     *
     * On retryable failures, waits with exponential backoff plus jitter
     * before the next attempt. Non-retryable failures are thrown immediately.
     *
     * @param block The suspend function to execute.
     * @return The result of [block] if it succeeds within the allowed attempts.
     * @throws SdkTplException after all retry attempts are exhausted.
     */
    suspend fun <T> executeWithRetry(block: suspend () -> T): T {
        var lastException: SdkTplException? = null

        for (attempt in 0..config.maxRetries) {
            try {
                return block()
            } catch (e: SdkTplException) {
                lastException = e

                if (!e.recoverable || attempt >= config.maxRetries) {
                    throw e
                }

                if (e.statusCode != null && e.statusCode !in config.retryableStatusCodes) {
                    throw e
                }

                val delayMs = calculateDelay(attempt)
                delay(delayMs)
            } catch (e: Exception) {
                // Wrap raw Ktor/network exceptions (ConnectTimeoutException,
                // SocketTimeoutException, IOException, etc.) as recoverable errors
                // so the retry loop can handle them.
                val wrapped = SdkTplException.networkError(
                    "Request failed: ${e.message}",
                    e
                )
                lastException = wrapped

                if (attempt >= config.maxRetries) {
                    throw wrapped
                }

                val delayMs = calculateDelay(attempt)
                delay(delayMs)
            }
        }

        throw lastException ?: SdkTplException.networkError("All retry attempts exhausted")
    }

    /**
     * Calculates the delay for a given attempt using exponential backoff with
     * full jitter.
     *
     * Formula: `random(0, min(maxDelay, baseDelay * 2^attempt))`
     *
     * @param attempt The zero-based attempt number.
     * @return The delay in milliseconds.
     */
    internal fun calculateDelay(attempt: Int): Long {
        val exponentialDelay = config.baseDelayMs * (1L shl attempt.coerceAtMost(30))
        val cappedDelay = min(exponentialDelay, config.maxDelayMs)
        val jitterFactor = 0.75 + Random.nextDouble() * 0.5
        return (cappedDelay * jitterFactor).toLong()
    }
}
