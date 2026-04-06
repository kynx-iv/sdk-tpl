package com.sdk_tpl.errors

/**
 * Sanitizes error messages and context data to remove PII and sensitive
 * information before logging or returning errors to callers.
 */
object ErrorSanitizer {

    private val EMAIL_PATTERN = Regex(
        "[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}"
    )

    private val PHONE_PATTERN = Regex(
        "\\+?[1-9]\\d{1,14}|\\(\\d{3}\\)\\s?\\d{3}[\\-.]?\\d{4}"
    )

    private val API_KEY_PATTERN = Regex(
        "(?i)(api[_-]?key|token|secret|password|authorization)[\"']?\\s*[:=]\\s*[\"']?([^\\s\"',}{\\]]+)"
    )

    private val IP_ADDRESS_PATTERN = Regex(
        "\\b(?:\\d{1,3}\\.){3}\\d{1,3}\\b"
    )

    private val CREDIT_CARD_PATTERN = Regex(
        "\\b(?:\\d{4}[\\s-]?){3}\\d{4}\\b"
    )

    private const val EMAIL_REPLACEMENT = "[EMAIL_REDACTED]"
    private const val PHONE_REPLACEMENT = "[PHONE_REDACTED]"
    private const val KEY_REPLACEMENT = "[KEY_REDACTED]"
    private const val IP_REPLACEMENT = "[IP_REDACTED]"
    private const val CARD_REPLACEMENT = "[CARD_REDACTED]"

    /**
     * Sanitizes a string by replacing detected PII patterns with redaction
     * placeholders.
     *
     * @param input The string to sanitize.
     * @return The sanitized string with PII removed.
     */
    fun sanitize(input: String): String {
        var result = input
        result = CREDIT_CARD_PATTERN.replace(result, CARD_REPLACEMENT)
        result = API_KEY_PATTERN.replace(result) { match ->
            "${match.groupValues[1]}=$KEY_REPLACEMENT"
        }
        result = EMAIL_PATTERN.replace(result, EMAIL_REPLACEMENT)
        result = PHONE_PATTERN.replace(result, PHONE_REPLACEMENT)
        result = IP_ADDRESS_PATTERN.replace(result, IP_REPLACEMENT)
        return result
    }

    /**
     * Sanitizes all values in a map.
     *
     * @param context The map of context data to sanitize.
     * @return A new map with all values sanitized.
     */
    fun sanitizeContext(context: Map<String, String>): Map<String, String> {
        return context.mapValues { (_, value) -> sanitize(value) }
    }

    /**
     * Checks whether a string contains any detectable PII.
     *
     * @param input The string to check.
     * @return `true` if PII patterns are detected.
     */
    fun containsPii(input: String): Boolean {
        return EMAIL_PATTERN.containsMatchIn(input)
            || PHONE_PATTERN.containsMatchIn(input)
            || API_KEY_PATTERN.containsMatchIn(input)
            || CREDIT_CARD_PATTERN.containsMatchIn(input)
    }
}
