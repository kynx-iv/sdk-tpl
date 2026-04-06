package com.sdk_tpl.http;

import com.sdk_tpl.config.SdkTplConfig;
import com.sdk_tpl.errors.ErrorCode;
import com.sdk_tpl.errors.SdkTplException;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.time.Instant;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

/**
 * Circuit breaker implementation for fault tolerance.
 *
 * <p>Implements a state machine with three states:</p>
 * <ul>
 *   <li><strong>CLOSED</strong> - Normal operation, requests pass through</li>
 *   <li><strong>OPEN</strong> - Failing, all requests are immediately rejected</li>
 *   <li><strong>HALF_OPEN</strong> - Testing recovery, one request allowed through</li>
 * </ul>
 */
public class CircuitBreaker {

    private static final Logger logger = LoggerFactory.getLogger(CircuitBreaker.class);

    /**
     * Circuit breaker states.
     */
    public enum State {
        CLOSED,
        OPEN,
        HALF_OPEN
    }

    private final int halfOpenMaxRequests;
    private final int failureThreshold;
    private final long resetTimeout;
    private final AtomicReference<State> state;
    private final AtomicInteger failureCount;
    private final AtomicInteger halfOpenAttempts;
    private volatile long lastFailureTime;

    /**
     * Creates a circuit breaker with the given configuration.
     *
     * @param config the circuit breaker configuration
     */
    public CircuitBreaker(SdkTplConfig.CircuitBreakerConfig config) {
        this.failureThreshold = config.getFailureThreshold();
        this.resetTimeout = config.getResetTimeout();
        this.halfOpenMaxRequests = config.getHalfOpenRequests();
        this.state = new AtomicReference<>(State.CLOSED);
        this.failureCount = new AtomicInteger(0);
        this.halfOpenAttempts = new AtomicInteger(0);
        this.lastFailureTime = 0;
    }

    /**
     * Returns the current state of the circuit breaker.
     *
     * @return the current state
     */
    public synchronized State getState() {
        State current = state.get();

        // Check if we should transition from OPEN to HALF_OPEN
        if (current == State.OPEN && isResetTimeoutExpired()) {
            state.set(State.HALF_OPEN);
            halfOpenAttempts.set(0);
            logger.info("Circuit breaker transitioning from OPEN to HALF_OPEN");
            return State.HALF_OPEN;
        }

        return current;
    }

    /**
     * Ensures the circuit is not open. If the circuit is open and the reset
     * timeout has not expired, an exception is thrown.
     *
     * @throws SdkTplException if the circuit is open
     */
    public synchronized void ensureClosed() {
        State current = getState();
        if (current == State.OPEN) {
            throw new SdkTplException(
                    "Circuit breaker is open. Requests are blocked until " +
                            Instant.ofEpochMilli(lastFailureTime + resetTimeout),
                    ErrorCode.CIRCUIT_OPEN,
                    null,
                    true,
                    resetTimeout - (System.currentTimeMillis() - lastFailureTime),
                    null,
                    null
            );
        }
        if (current == State.HALF_OPEN) {
            int attempts = halfOpenAttempts.incrementAndGet();
            if (attempts > halfOpenMaxRequests) {
                throw new SdkTplException(
                        "Circuit breaker is half-open. Only " + halfOpenMaxRequests +
                                " probe request(s) allowed",
                        ErrorCode.CIRCUIT_OPEN,
                        null,
                        true,
                        resetTimeout / 2,
                        null,
                        null
                );
            }
        }
    }

    /**
     * Records a successful request. Resets the circuit to CLOSED state.
     */
    public synchronized void recordSuccess() {
        State previous = state.getAndSet(State.CLOSED);
        failureCount.set(0);
        halfOpenAttempts.set(0);
        if (previous != State.CLOSED) {
            logger.info("Circuit breaker reset to CLOSED after successful request");
        }
    }

    /**
     * Records a failed request. May transition the circuit to OPEN state
     * if the failure threshold is reached.
     */
    public synchronized void recordFailure() {
        lastFailureTime = System.currentTimeMillis();
        int failures = failureCount.incrementAndGet();
        halfOpenAttempts.set(0);

        if (failures >= failureThreshold) {
            State previous = state.getAndSet(State.OPEN);
            if (previous != State.OPEN) {
                logger.warn("Circuit breaker opened after {} consecutive failures", failures);
            }
        }
    }

    /**
     * Returns the current failure count.
     *
     * @return the number of consecutive failures
     */
    public int getFailureCount() {
        return failureCount.get();
    }

    /**
     * Resets the circuit breaker to its initial CLOSED state.
     */
    public synchronized void reset() {
        state.set(State.CLOSED);
        failureCount.set(0);
        halfOpenAttempts.set(0);
        lastFailureTime = 0;
        logger.info("Circuit breaker manually reset");
    }

    private synchronized boolean isResetTimeoutExpired() {
        return System.currentTimeMillis() - lastFailureTime >= resetTimeout;
    }
}
