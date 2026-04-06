package com.sdk_tpl.client;

import com.sdk_tpl.config.SdkTplConfig;
import com.sdk_tpl.errors.SdkTplException;
import com.sdk_tpl.errors.ErrorCode;
import com.sdk_tpl.http.HttpClient;
import com.sdk_tpl.utils.Version;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Map;
import java.util.Objects;

/**
 * Main client for the {{SDK_NAME}} SDK.
 *
 * <p>Provides methods to interact with the SdkTpl API.
 * Use the {@link Builder} for advanced configuration or the
 * simple constructor for quick setup.</p>
 *
 * <pre>{@code
 * // Simple usage
 * var client = new SdkTplClient("your-api-key");
 *
 * // Advanced usage
 * var client = SdkTplClient.builder()
 *     .apiKey("your-api-key")
 *     .baseUrl("{{API_BASE_URL}}")
 *     .timeout(60000)
 *     .build();
 * }</pre>
 */
public class SdkTplClient implements AutoCloseable {

    private static final Logger logger = LoggerFactory.getLogger(SdkTplClient.class);
    private static final ObjectMapper objectMapper = new ObjectMapper();

    private final SdkTplConfig config;
    protected final HttpClient httpClient;
    private volatile boolean closed = false;

    /**
     * Creates a new client with the given API key and default configuration.
     *
     * @param apiKey the API key for authentication
     * @throws IllegalArgumentException if apiKey is null or blank
     */
    public SdkTplClient(String apiKey) {
        this(SdkTplConfig.builder()
                .apiKey(apiKey)
                .build());
    }

    /**
     * Creates a new client with the given configuration.
     *
     * @param config the SDK configuration
     * @throws IllegalArgumentException if config is null
     */
    public SdkTplClient(SdkTplConfig config) {
        Objects.requireNonNull(config, "Config must not be null");
        this.config = config;
        this.httpClient = new HttpClient(config);
        logger.info("{{SDK_NAME}} SDK v{} initialized", Version.SDK_VERSION);
    }

    /**
     * Creates a new {@link Builder} for advanced client configuration.
     *
     * @return a new builder instance
     */
    public static Builder builder() {
        return new Builder();
    }

    /**
     * Performs a health check against the API.
     *
     * @return the health check response
     * @throws SdkTplException if the request fails
     */
    public HealthResponse healthCheck() {
        ensureOpen();
        try {
            String response = httpClient.request("GET", "/health", null);
            JsonNode node = objectMapper.readTree(response);

            return new HealthResponse(
                    node.has("status") ? node.get("status").asText() : "unknown",
                    node.has("version") ? node.get("version").asText() : null,
                    node.has("timestamp") ? node.get("timestamp").asText() : null
            );
        } catch (SdkTplException e) {
            throw e;
        } catch (Exception e) {
            throw SdkTplException.networkError("Health check failed: " + e.getMessage(), e);
        }
    }

    /**
     * Returns the current SDK configuration.
     *
     * @return the configuration
     */
    public SdkTplConfig getConfig() {
        return config;
    }

    /**
     * Returns whether this client has been closed.
     *
     * @return true if closed
     */
    public boolean isClosed() {
        return closed;
    }

    @Override
    public void close() {
        if (!closed) {
            closed = true;
            httpClient.close();
            logger.info("{{SDK_NAME}} SDK client closed");
        }
    }

    private void ensureOpen() {
        if (closed) {
            throw new SdkTplException(
                    "Client has been closed",
                    ErrorCode.UNKNOWN_ERROR,
                    null,
                    false
            );
        }
    }

    /**
     * Health check response record.
     */
    public record HealthResponse(String status, String version, String timestamp) {

        public boolean isHealthy() {
            return "ok".equalsIgnoreCase(status) || "healthy".equalsIgnoreCase(status);
        }
    }

    /**
     * Builder for creating {@link SdkTplClient} instances with advanced configuration.
     */
    public static final class Builder {

        private final SdkTplConfig.Builder configBuilder = SdkTplConfig.builder();

        private Builder() {}

        public Builder apiKey(String apiKey) {
            configBuilder.apiKey(apiKey);
            return this;
        }

        public Builder baseUrl(String baseUrl) {
            configBuilder.baseUrl(baseUrl);
            return this;
        }

        public Builder timeout(long timeout) {
            configBuilder.timeout(timeout);
            return this;
        }

        public Builder secondaryApiKey(String secondaryApiKey) {
            configBuilder.secondaryApiKey(secondaryApiKey);
            return this;
        }

        public Builder enableRequestSigning(boolean enable) {
            configBuilder.enableRequestSigning(enable);
            return this;
        }

        public Builder enableErrorSanitization(boolean enable) {
            configBuilder.enableErrorSanitization(enable);
            return this;
        }

        public Builder retryConfig(SdkTplConfig.RetryConfig retryConfig) {
            configBuilder.retryConfig(retryConfig);
            return this;
        }

        public Builder circuitBreakerConfig(SdkTplConfig.CircuitBreakerConfig circuitBreakerConfig) {
            configBuilder.circuitBreakerConfig(circuitBreakerConfig);
            return this;
        }

        /**
         * Builds the client.
         *
         * @return a new {@link SdkTplClient} instance
         */
        public SdkTplClient build() {
            return new SdkTplClient(configBuilder.build());
        }
    }
}
