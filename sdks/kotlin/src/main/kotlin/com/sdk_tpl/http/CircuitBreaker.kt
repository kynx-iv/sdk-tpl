package com.sdk_tpl.http

import com.sdk_tpl.config.CircuitBreakerConfig
import com.sdk_tpl.errors.SdkTplException
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Coroutine-safe circuit breaker implementation.
 *
 * Prevents cascading failures by tracking error rates and temporarily
 * blocking requests when the failure threshold is reached.
 *
 * States:
 * - **CLOSED**: Normal operation, requests pass through.
 * - **OPEN**: Requests are rejected immediately.
 * - **HALF_OPEN**: A limited number of probe requests are allowed through.
 */
class CircuitBreaker(private val config: CircuitBreakerConfig) {

    enum class State {
        CLOSED,
        OPEN,
        HALF_OPEN
    }

    private val mutex = Mutex()
    private var state: State = State.CLOSED
    private var failureCount: Int = 0
    private var lastFailureTime: Long = 0L
    private var halfOpenAttempts: Int = 0

    /**
     * Executes [block] through the circuit breaker.
     *
     * @param block The suspend function to execute.
     * @return The result of [block].
     * @throws SdkTplException if the circuit is open or the operation fails.
     */
    suspend fun <T> execute(block: suspend () -> T): T {
        checkState()

        return try {
            val result = block()
            onSuccess()
            result
        } catch (e: SdkTplException) {
            if (e.recoverable) {
                onFailure()
            }
            throw e
        } catch (e: Exception) {
            // Only count network/IO errors as circuit breaker failures.
            // Non-recoverable errors (e.g., IllegalArgumentException) should not
            // trip the circuit breaker.
            if (e is java.io.IOException || e is kotlinx.coroutines.TimeoutCancellationException) {
                onFailure()
            }
            throw e
        }
    }

    /**
     * Returns the current circuit breaker state.
     */
    suspend fun currentState(): State {
        mutex.withLock { return state }
    }

    /**
     * Returns the current failure count.
     */
    suspend fun currentFailureCount(): Int {
        mutex.withLock { return failureCount }
    }

    /**
     * Resets the circuit breaker to its initial closed state.
     */
    suspend fun reset() {
        mutex.withLock {
            state = State.CLOSED
            failureCount = 0
            lastFailureTime = 0L
            halfOpenAttempts = 0
        }
    }

    private suspend fun checkState() {
        mutex.withLock {
            when (state) {
                State.OPEN -> {
                    val elapsed = System.currentTimeMillis() - lastFailureTime
                    if (elapsed >= config.resetTimeoutMs) {
                        state = State.HALF_OPEN
                        halfOpenAttempts = 0
                    } else {
                        throw SdkTplException.circuitBreakerOpen(
                            "Circuit breaker is open. Retry after ${config.resetTimeoutMs - elapsed}ms."
                        )
                    }
                }
                State.HALF_OPEN -> {
                    if (halfOpenAttempts >= config.halfOpenMaxRequests) {
                        throw SdkTplException.circuitBreakerOpen(
                            "Circuit breaker is half-open. Max probe requests reached."
                        )
                    }
                    halfOpenAttempts++
                }
                State.CLOSED -> { /* allow through */ }
            }
        }
    }

    private suspend fun onSuccess() {
        mutex.withLock {
            failureCount = 0
            halfOpenAttempts = 0
            state = State.CLOSED
        }
    }

    private suspend fun onFailure() {
        mutex.withLock {
            failureCount++
            lastFailureTime = System.currentTimeMillis()
            if (failureCount >= config.failureThreshold) {
                state = State.OPEN
            }
        }
    }
}
