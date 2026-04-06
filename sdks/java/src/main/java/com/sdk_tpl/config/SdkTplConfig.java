package com.sdk_tpl.config;

import com.sdk_tpl.utils.Logger;
import com.sdk_tpl.utils.NoopLogger;

import java.util.Objects;

/**
 * Configuration for the {{SDK_NAME}} SDK.
 *
 * <p>Use the {@link Builder} to create instances:</p>
 * <pre>{@code
 * var config = SdkTplConfig.builder()
 *     .apiKey("your-api-key")
 *     .baseUrl("{{API_BASE_URL}}")
 *     .timeout(60000)
 *     .retryConfig(new RetryConfig(5, 2000, 60000))
 *     .build();
 * }</pre>
 */
public final class SdkTplConfig {

    private static final String DEFAULT_BASE_URL = "{{API_BASE_URL}}";
    private static final String LOCAL_BASE_URL = "{{API_LOCAL_URL}}";
    private static final long DEFAULT_TIMEOUT = 30000;

    private final String apiKey;
    private final String baseUrl;
    private final long timeout;
    private final RetryConfig retryConfig;
    private final CircuitBreakerConfig circuitBreakerConfig;
    private final String secondaryApiKey;
    private final boolean enableRequestSigning;
    private final boolean enableErrorSanitization;
    private final Logger logger;

    private SdkTplConfig(Builder builder) {
        this.apiKey = Objects.requireNonNull(builder.apiKey, "API key must not be null");
        if (builder.apiKey.isBlank()) {
            throw new IllegalArgumentException("API key must not be blank");
        }
        this.baseUrl = builder.baseUrl != null ? builder.baseUrl : resolveBaseUrl();
        this.timeout = builder.timeout;
        this.retryConfig = builder.retryConfig != null ? builder.retryConfig : new RetryConfig();
        this.circuitBreakerConfig = builder.circuitBreakerConfig != null
                ? builder.circuitBreakerConfig : new CircuitBreakerConfig();
        this.secondaryApiKey = builder.secondaryApiKey;
        this.enableRequestSigning = builder.enableRequestSigning;
        this.enableErrorSanitization = builder.enableErrorSanitization;
        this.logger = builder.logger != null ? builder.logger : new NoopLogger();
    }

    /**
     * Creates a new configuration builder.
     *
     * @return a new builder instance
     */
    public static Builder builder() {
        return new Builder();
    }

    public String getApiKey() {
        return apiKey;
    }

    public String getBaseUrl() {
        return baseUrl;
    }

    public long getTimeout() {
        return timeout;
    }

    public RetryConfig getRetryConfig() {
        return retryConfig;
    }

    public CircuitBreakerConfig getCircuitBreakerConfig() {
        return circuitBreakerConfig;
    }

    public String getSecondaryApiKey() {
        return secondaryApiKey;
    }

    public boolean isEnableRequestSigning() {
        return enableRequestSigning;
    }

    public boolean isEnableErrorSanitization() {
        return enableErrorSanitization;
    }

    public Logger getLogger() {
        return logger;
    }

    private static String resolveBaseUrl() {
        String mode = System.getenv("{{ENV_MODE_VAR}}");
        if ("local".equalsIgnoreCase(mode)) {
            return LOCAL_BASE_URL;
        }
        return DEFAULT_BASE_URL;
    }

    /**
     * Retry configuration for failed requests.
     */
    public static final class RetryConfig {

        private final int maxRetries;
        private final long baseDelay;
        private final long maxDelay;

        /**
         * Creates a retry config with default values.
         */
        public RetryConfig() {
            this(3, 1000, 30000);
        }

        /**
         * Creates a retry config with the specified values.
         *
         * @param maxRetries maximum number of retries
         * @param baseDelay  base delay in milliseconds between retries
         * @param maxDelay   maximum delay in milliseconds between retries
         */
        public RetryConfig(int maxRetries, long baseDelay, long maxDelay) {
            if (maxRetries < 0) {
                throw new IllegalArgumentException("maxRetries must be >= 0");
            }
            if (baseDelay <= 0) {
                throw new IllegalArgumentException("baseDelay must be positive");
            }
            if (maxDelay < baseDelay) {
                throw new IllegalArgumentException("maxDelay must be >= baseDelay");
            }
            this.maxRetries = maxRetries;
            this.baseDelay = baseDelay;
            this.maxDelay = maxDelay;
        }

        public int getMaxRetries() {
            return maxRetries;
        }

        public long getBaseDelay() {
            return baseDelay;
        }

        public long getMaxDelay() {
            return maxDelay;
        }
    }

    /**
     * Circuit breaker configuration for fault tolerance.
     */
    public static final class CircuitBreakerConfig {

        private final int failureThreshold;
        private final long resetTimeout;
        private final int halfOpenRequests;

        /**
         * Creates a circuit breaker config with default values.
         */
        public CircuitBreakerConfig() {
            this(5, 30000, 1);
        }

        /**
         * Creates a circuit breaker config with the specified values.
         *
         * @param failureThreshold number of failures before opening the circuit
         * @param resetTimeout     time in milliseconds before attempting to close the circuit
         */
        public CircuitBreakerConfig(int failureThreshold, long resetTimeout) {
            this(failureThreshold, resetTimeout, 1);
        }

        /**
         * Creates a circuit breaker config with the specified values.
         *
         * @param failureThreshold number of failures before opening the circuit
         * @param resetTimeout     time in milliseconds before attempting to close the circuit
         * @param halfOpenRequests  maximum requests allowed in half-open state
         */
        public CircuitBreakerConfig(int failureThreshold, long resetTimeout, int halfOpenRequests) {
            if (failureThreshold < 1) {
                throw new IllegalArgumentException("failureThreshold must be >= 1");
            }
            if (resetTimeout <= 0) {
                throw new IllegalArgumentException("resetTimeout must be positive");
            }
            if (halfOpenRequests <= 0) {
                throw new IllegalArgumentException("halfOpenRequests must be positive");
            }
            this.failureThreshold = failureThreshold;
            this.resetTimeout = resetTimeout;
            this.halfOpenRequests = halfOpenRequests;
        }

        public int getFailureThreshold() {
            return failureThreshold;
        }

        public long getResetTimeout() {
            return resetTimeout;
        }

        public int getHalfOpenRequests() {
            return halfOpenRequests;
        }
    }

    /**
     * Builder for creating {@link SdkTplConfig} instances.
     */
    public static final class Builder {

        private String apiKey;
        private String baseUrl;
        private long timeout = DEFAULT_TIMEOUT;
        private RetryConfig retryConfig;
        private CircuitBreakerConfig circuitBreakerConfig;
        private String secondaryApiKey;
        private boolean enableRequestSigning = false;
        private boolean enableErrorSanitization = true;
        private Logger logger;

        private Builder() {}

        public Builder apiKey(String apiKey) {
            this.apiKey = apiKey;
            return this;
        }

        public Builder baseUrl(String baseUrl) {
            this.baseUrl = baseUrl;
            return this;
        }

        public Builder timeout(long timeout) {
            if (timeout <= 0) {
                throw new IllegalArgumentException("Timeout must be positive");
            }
            this.timeout = timeout;
            return this;
        }

        public Builder retryConfig(RetryConfig retryConfig) {
            this.retryConfig = retryConfig;
            return this;
        }

        public Builder circuitBreakerConfig(CircuitBreakerConfig circuitBreakerConfig) {
            this.circuitBreakerConfig = circuitBreakerConfig;
            return this;
        }

        public Builder secondaryApiKey(String secondaryApiKey) {
            this.secondaryApiKey = secondaryApiKey;
            return this;
        }

        public Builder enableRequestSigning(boolean enableRequestSigning) {
            this.enableRequestSigning = enableRequestSigning;
            return this;
        }

        public Builder enableErrorSanitization(boolean enableErrorSanitization) {
            this.enableErrorSanitization = enableErrorSanitization;
            return this;
        }

        public Builder logger(Logger logger) {
            this.logger = logger;
            return this;
        }

        /**
         * Builds the configuration.
         *
         * @return a new {@link SdkTplConfig} instance
         * @throws NullPointerException     if apiKey is null
         * @throws IllegalArgumentException if apiKey is blank
         */
        public SdkTplConfig build() {
            return new SdkTplConfig(this);
        }
    }
}
