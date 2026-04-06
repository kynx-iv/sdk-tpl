package com.sdk_tpl.security;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.InvalidKeyException;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.List;
import java.util.regex.Pattern;

/**
 * Security utilities for the {{SDK_NAME}} SDK.
 *
 * <p>Provides PII detection, HMAC-SHA256 signature generation,
 * and API key validation helpers.</p>
 */
public final class Security {

    private static final Logger logger = LoggerFactory.getLogger(Security.class);
    private static final String HMAC_ALGORITHM = "HmacSHA256";

    private static final List<PiiPattern> PII_PATTERNS = List.of(
            new PiiPattern(
                    "email",
                    Pattern.compile("[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}")
            ),
            new PiiPattern(
                    "credit_card",
                    Pattern.compile("\\b(?:\\d{4}[\\s\\-]?){3}\\d{4}\\b")
            ),
            new PiiPattern(
                    "ssn",
                    Pattern.compile("\\b\\d{3}-\\d{2}-\\d{4}\\b")
            ),
            new PiiPattern(
                    "phone",
                    Pattern.compile("(?:\\+?1[\\s\\-.]?)?\\(?\\d{3}\\)?[\\s\\-.]?\\d{3}[\\s\\-.]?\\d{4}")
            ),
            new PiiPattern(
                    "ip_address",
                    Pattern.compile("\\b(?:\\d{1,3}\\.){3}\\d{1,3}\\b")
            )
    );

    private Security() {
        // Utility class
    }

    /**
     * Detects PII in the given text.
     *
     * @param text the text to scan
     * @return a list of detected PII types, empty if none found
     */
    public static List<String> detectPii(String text) {
        if (text == null || text.isEmpty()) {
            return List.of();
        }

        return PII_PATTERNS.stream()
                .filter(p -> p.pattern().matcher(text).find())
                .map(PiiPattern::type)
                .toList();
    }

    /**
     * Checks whether the given text contains any detectable PII.
     *
     * @param text the text to scan
     * @return true if PII is detected
     */
    public static boolean containsPii(String text) {
        return !detectPii(text).isEmpty();
    }

    /**
     * Generates an HMAC-SHA256 signature for the given payload.
     *
     * @param payload the payload to sign
     * @param secret  the secret key
     * @return the hex-encoded HMAC-SHA256 signature
     * @throws IllegalArgumentException if payload or secret is null
     * @throws RuntimeException         if HMAC computation fails
     */
    public static String generateHmacSignature(String payload, String secret) {
        if (payload == null) {
            throw new IllegalArgumentException("Payload must not be null");
        }
        if (secret == null) {
            throw new IllegalArgumentException("Secret must not be null");
        }

        try {
            Mac mac = Mac.getInstance(HMAC_ALGORITHM);
            SecretKeySpec keySpec = new SecretKeySpec(
                    secret.getBytes(StandardCharsets.UTF_8),
                    HMAC_ALGORITHM
            );
            mac.init(keySpec);
            byte[] hash = mac.doFinal(payload.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("HMAC-SHA256 algorithm not available", e);
        } catch (InvalidKeyException e) {
            throw new RuntimeException("Invalid HMAC key", e);
        }
    }

    /**
     * Verifies an HMAC-SHA256 signature against a payload.
     *
     * @param payload           the original payload
     * @param secret            the secret key
     * @param expectedSignature the signature to verify
     * @return true if the signature is valid
     */
    public static boolean verifyHmacSignature(String payload, String secret, String expectedSignature) {
        if (expectedSignature == null) {
            return false;
        }
        String computed = generateHmacSignature(payload, secret);
        return constantTimeEquals(computed, expectedSignature);
    }

    /**
     * Validates an API key format.
     *
     * <p>A valid API key must be at least 20 characters long and contain
     * only alphanumeric characters, hyphens, and underscores.</p>
     *
     * @param apiKey the API key to validate
     * @return true if the API key format is valid
     */
    public static boolean isValidApiKeyFormat(String apiKey) {
        if (apiKey == null || apiKey.length() < 20) {
            return false;
        }
        return apiKey.matches("[a-zA-Z0-9_\\-]+");
    }

    /**
     * Masks an API key for safe logging, showing only the first 4 and last 4 characters.
     *
     * @param apiKey the API key to mask
     * @return the masked API key
     */
    public static String maskApiKey(String apiKey) {
        if (apiKey == null || apiKey.length() <= 8) {
            return "****";
        }
        return apiKey.substring(0, 4) + "****" + apiKey.substring(apiKey.length() - 4);
    }

    /**
     * Constant-time string comparison to prevent timing attacks.
     */
    private static boolean constantTimeEquals(String a, String b) {
        if (a.length() != b.length()) {
            return false;
        }
        int result = 0;
        for (int i = 0; i < a.length(); i++) {
            result |= a.charAt(i) ^ b.charAt(i);
        }
        return result == 0;
    }

    private record PiiPattern(String type, Pattern pattern) {}
}
