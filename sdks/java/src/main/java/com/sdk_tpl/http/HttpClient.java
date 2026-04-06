package com.sdk_tpl.http;

import com.sdk_tpl.config.SdkTplConfig;
import com.sdk_tpl.errors.ErrorCode;
import com.sdk_tpl.errors.ErrorSanitizer;
import com.sdk_tpl.errors.SdkTplException;
import com.sdk_tpl.security.Security;
import com.sdk_tpl.utils.Version;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.net.URI;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Objects;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * HTTP client for the SdkTpl SDK.
 *
 * <p>Handles request execution with retry logic, circuit breaking,
 * key rotation on 401 responses, and optional HMAC request signing.</p>
 */
public class HttpClient {

    private static final Logger logger = LoggerFactory.getLogger(HttpClient.class);
    private static final String USER_AGENT = "sdk_tpl-java/" + Version.SDK_VERSION;

    private final SdkTplConfig config;
    private final java.net.http.HttpClient httpClient;
    private final RetryHandler retryHandler;
    private final CircuitBreaker circuitBreaker;
    private volatile String currentApiKey;
    private final AtomicBoolean rotatedToSecondary = new AtomicBoolean(false);
    private final Object rotationLock = new Object();

    /**
     * Creates a new HTTP client with the given configuration.
     *
     * @param config the SDK configuration
     */
    public HttpClient(SdkTplConfig config) {
        this.config = Objects.requireNonNull(config, "Config must not be null");
        this.currentApiKey = config.getApiKey();
        this.httpClient = java.net.http.HttpClient.newBuilder()
                .connectTimeout(Duration.ofMillis(config.getTimeout()))
                .followRedirects(java.net.http.HttpClient.Redirect.NORMAL)
                .build();
        this.retryHandler = new RetryHandler(config.getRetryConfig());
        this.circuitBreaker = new CircuitBreaker(config.getCircuitBreakerConfig());
    }

    /**
     * Sends an HTTP request with retry and circuit breaker support.
     *
     * @param method the HTTP method (GET, POST, PUT, DELETE)
     * @param path   the request path (appended to base URL)
     * @param body   the request body (may be null for GET/DELETE)
     * @return the response body as a string
     * @throws SdkTplException if the request fails after all retries
     */
    public String request(String method, String path, String body) {
        circuitBreaker.ensureClosed();

        return retryHandler.execute(() -> {
            try {
                HttpResponse<String> response = executeRequest(method, path, body);
                int statusCode = response.statusCode();

                if (statusCode >= 200 && statusCode < 300) {
                    circuitBreaker.recordSuccess();
                    return response.body();
                }

                // Handle 401 with key rotation — only one thread performs the rotation
                if (statusCode == 401 && !rotatedToSecondary.get() && config.getSecondaryApiKey() != null) {
                    synchronized (rotationLock) {
                        if (!rotatedToSecondary.get()) {
                            logger.warn("Primary API key rejected, rotating to secondary key");
                            currentApiKey = config.getSecondaryApiKey();
                            rotatedToSecondary.set(true);
                        }
                    }

                    // Retry with secondary key
                    HttpResponse<String> retryResponse = executeRequest(method, path, body);
                    if (retryResponse.statusCode() >= 200 && retryResponse.statusCode() < 300) {
                        circuitBreaker.recordSuccess();
                        return retryResponse.body();
                    }
                    statusCode = retryResponse.statusCode();
                    response = retryResponse;
                }

                circuitBreaker.recordFailure();

                String responseBody = response.body();
                String requestId = response.headers()
                        .firstValue("X-Request-Id")
                        .orElse(null);
                String retryAfterHeader = response.headers()
                        .firstValue("Retry-After")
                        .orElse(null);

                if (config.isEnableErrorSanitization() && responseBody != null) {
                    responseBody = ErrorSanitizer.sanitize(responseBody);
                }

                throw SdkTplException.fromResponse(statusCode, responseBody, requestId, retryAfterHeader);

            } catch (SdkTplException e) {
                throw e;
            } catch (java.net.http.HttpTimeoutException e) {
                circuitBreaker.recordFailure();
                throw new SdkTplException(
                        "Request timed out after " + config.getTimeout() + "ms",
                        ErrorCode.TIMEOUT_ERROR,
                        null,
                        true,
                        null,
                        null,
                        e
                );
            } catch (java.net.ConnectException e) {
                circuitBreaker.recordFailure();
                throw new SdkTplException(
                        "Connection refused: " + config.getBaseUrl(),
                        ErrorCode.CONNECTION_REFUSED,
                        null,
                        true,
                        null,
                        null,
                        e
                );
            } catch (Exception e) {
                circuitBreaker.recordFailure();
                throw SdkTplException.networkError(
                        "Request failed: " + e.getMessage(), e
                );
            }
        });
    }

    /**
     * Closes the underlying HTTP client resources.
     */
    public void close() {
        // java.net.http.HttpClient does not require explicit closing,
        // but this method exists for future resource cleanup
        logger.debug("HTTP client closed");
    }

    private HttpResponse<String> executeRequest(String method, String path, String body)
            throws Exception {

        String url = config.getBaseUrl() + path;
        String timestamp = String.valueOf(System.currentTimeMillis());

        HttpRequest.Builder requestBuilder = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .timeout(Duration.ofMillis(config.getTimeout()))
                .header("Content-Type", "application/json")
                .header("Accept", "application/json")
                .header("User-Agent", USER_AGENT)
                .header("X-API-Key", currentApiKey)
                .header("X-SDK-Version", Version.SDK_VERSION)
                .header("X-Timestamp", timestamp);

        // Serialize body once for both signing and sending
        String bodyString = body != null ? body : "";

        // Add HMAC signature if request signing is enabled
        if (config.isEnableRequestSigning()) {
            String message = timestamp + "." + bodyString;
            String signature = Security.generateHmacSignature(message, currentApiKey);
            requestBuilder.header("X-Signature", signature);
            requestBuilder.header("X-Signature-Algorithm", "HMAC-SHA256");
        }

        // Set method and body using the same string used for signing
        HttpRequest.BodyPublisher bodyPublisher = body != null
                ? HttpRequest.BodyPublishers.ofString(bodyString)
                : HttpRequest.BodyPublishers.noBody();

        requestBuilder.method(method.toUpperCase(), bodyPublisher);

        HttpRequest httpRequest = requestBuilder.build();
        logger.debug("{} {}", method.toUpperCase(), url);

        return httpClient.send(httpRequest, HttpResponse.BodyHandlers.ofString());
    }
}
