package com.sdk_tpl.errors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.List;
import java.util.regex.Pattern;

/**
 * Sanitizes error messages and request data to prevent leaking sensitive information.
 *
 * <p>Detects and masks API keys, tokens, email addresses, and other PII
 * in error messages before they are logged or returned to callers.</p>
 */
public final class ErrorSanitizer {

    private static final Logger logger = LoggerFactory.getLogger(ErrorSanitizer.class);
    private static final String MASK = "***REDACTED***";

    private static final List<SanitizationRule> RULES = List.of(
            // API keys (various formats)
            new SanitizationRule(
                    Pattern.compile("(?i)(api[_-]?key|apikey|x-api-key)[\"':\\s=]+[\"']?([a-zA-Z0-9_\\-]{20,})[\"']?"),
                    "API key"
            ),
            // Bearer tokens
            new SanitizationRule(
                    Pattern.compile("(?i)(bearer\\s+)([a-zA-Z0-9_\\-\\.]+)"),
                    "Bearer token"
            ),
            // Authorization headers
            new SanitizationRule(
                    Pattern.compile("(?i)(authorization)[\"':\\s=]+[\"']?([^\"'\\s,}{]+)[\"']?"),
                    "Authorization header"
            ),
            // Email addresses
            new SanitizationRule(
                    Pattern.compile("[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}"),
                    "Email address"
            ),
            // Credit card numbers (basic pattern)
            new SanitizationRule(
                    Pattern.compile("\\b(?:\\d{4}[\\s\\-]?){3}\\d{4}\\b"),
                    "Credit card number"
            ),
            // SSN pattern
            new SanitizationRule(
                    Pattern.compile("\\b\\d{3}-\\d{2}-\\d{4}\\b"),
                    "SSN"
            ),
            // Phone numbers (various formats)
            new SanitizationRule(
                    Pattern.compile("(?:\\+?1[\\s\\-.]?)?\\(?\\d{3}\\)?[\\s\\-.]?\\d{3}[\\s\\-.]?\\d{4}"),
                    "Phone number"
            ),
            // Secret/password fields in JSON
            new SanitizationRule(
                    Pattern.compile("(?i)(password|secret|token|credential)[\"':\\s=]+[\"']?([^\"'\\s,}{]+)[\"']?"),
                    "Secret field"
            )
    );

    private ErrorSanitizer() {
        // Utility class
    }

    /**
     * Sanitizes a string by replacing detected sensitive information with redaction markers.
     *
     * @param input the string to sanitize
     * @return the sanitized string, or the original if null/empty
     */
    public static String sanitize(String input) {
        if (input == null || input.isEmpty()) {
            return input;
        }

        String result = input;
        for (SanitizationRule rule : RULES) {
            var matcher = rule.pattern().matcher(result);
            if (matcher.find()) {
                logger.debug("Sanitizing detected {}", rule.description());
                result = matcher.replaceAll(matchResult -> {
                    // For patterns with capture groups, preserve the key name and mask the value
                    if (matchResult.groupCount() >= 2) {
                        return matchResult.group(1) + " " + MASK;
                    }
                    return MASK;
                });
            }
        }

        return result;
    }

    /**
     * Checks whether a string contains any detectable sensitive information.
     *
     * @param input the string to check
     * @return true if sensitive information is detected
     */
    public static boolean containsSensitiveData(String input) {
        if (input == null || input.isEmpty()) {
            return false;
        }

        for (SanitizationRule rule : RULES) {
            if (rule.pattern().matcher(input).find()) {
                return true;
            }
        }
        return false;
    }

    private record SanitizationRule(Pattern pattern, String description) {}
}
