package com.sdk_tpl.http;

import com.sdk_tpl.config.SdkTplConfig;
import com.sdk_tpl.errors.SdkTplException;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.concurrent.ThreadLocalRandom;

/**
 * Retry handler implementing exponential backoff with jitter.
 *
 * <p>Automatically retries recoverable errors up to the configured maximum,
 * with increasing delays between attempts to avoid thundering herd problems.</p>
 */
public class RetryHandler {

    private static final Logger logger = LoggerFactory.getLogger(RetryHandler.class);

    private final int maxRetries;
    private final long baseDelay;
    private final long maxDelay;

    /**
     * Creates a retry handler with the given configuration.
     *
     * @param config the retry configuration
     */
    public RetryHandler(SdkTplConfig.RetryConfig config) {
        this.maxRetries = config.getMaxRetries();
        this.baseDelay = config.getBaseDelay();
        this.maxDelay = config.getMaxDelay();
    }

    /**
     * Executes an operation with retry logic.
     *
     * <p>If the operation throws a recoverable {@link SdkTplException},
     * it will be retried up to {@code maxRetries} times with exponential
     * backoff and jitter between attempts.</p>
     *
     * @param operation the operation to execute
     * @param <T>       the return type
     * @return the result of the operation
     * @throws SdkTplException if all retries are exhausted or a non-recoverable error occurs
     */
    public <T> T execute(RetryableOperation<T> operation) {
        SdkTplException lastException = null;

        for (int attempt = 0; attempt <= maxRetries; attempt++) {
            try {
                return operation.execute();
            } catch (SdkTplException e) {
                lastException = e;

                if (!e.isRecoverable()) {
                    logger.debug("Non-recoverable error, not retrying: {}", e.getMessage());
                    throw e;
                }

                if (attempt >= maxRetries) {
                    logger.warn("All {} retries exhausted", maxRetries);
                    break;
                }

                long delay = calculateDelay(attempt, e.getRetryAfter());
                logger.info("Attempt {}/{} failed ({}), retrying in {}ms",
                        attempt + 1, maxRetries + 1, e.getCode(), delay);

                try {
                    Thread.sleep(delay);
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    throw new SdkTplException(
                            "Retry interrupted",
                            com.sdk_tpl.errors.ErrorCode.UNKNOWN_ERROR,
                            null,
                            false,
                            null,
                            null,
                            ie
                    );
                }
            }
        }

        throw lastException;
    }

    /**
     * Calculates the delay for the next retry attempt using exponential backoff with jitter.
     *
     * @param attempt    the current attempt number (0-based)
     * @param retryAfter server-suggested retry-after in milliseconds (may be null)
     * @return the delay in milliseconds
     */
    long calculateDelay(int attempt, Long retryAfter) {
        // Honor server-suggested retry-after if available
        if (retryAfter != null && retryAfter > 0) {
            return Math.min(retryAfter, maxDelay);
        }

        // Exponential backoff: baseDelay * 2^attempt (capped shift to prevent overflow)
        long exponentialDelay = baseDelay * (1L << Math.min(attempt, 30));
        long cappedDelay = Math.min(exponentialDelay, maxDelay);

        // Multiplicative jitter: random factor between 0.75 and 1.25 (±25% to match TypeScript canonical)
        double jitterFactor = 0.75 + ThreadLocalRandom.current().nextDouble() * 0.5;
        return (long)(cappedDelay * jitterFactor);
    }

    /**
     * Functional interface for retryable operations.
     *
     * @param <T> the return type
     */
    @FunctionalInterface
    public interface RetryableOperation<T> {

        /**
         * Executes the operation.
         *
         * @return the result
         * @throws SdkTplException if the operation fails
         */
        T execute() throws SdkTplException;
    }
}
