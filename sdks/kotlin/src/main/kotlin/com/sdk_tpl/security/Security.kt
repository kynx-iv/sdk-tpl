package com.sdk_tpl.security

import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import java.security.SecureRandom
import java.util.Base64

/**
 * Security utilities for the {{SDK_NAME}} SDK.
 *
 * Provides PII detection, HMAC request signing, and API key helpers.
 */
object Security {

    private val EMAIL_PATTERN = Regex(
        "[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}"
    )
    private val PHONE_PATTERN = Regex(
        "\\+?[1-9]\\d{1,14}"
    )
    private val SSN_PATTERN = Regex(
        "\\b\\d{3}-\\d{2}-\\d{4}\\b"
    )
    private val CREDIT_CARD_PATTERN = Regex(
        "\\b(?:\\d{4}[\\s-]?){3}\\d{4}\\b"
    )

    private const val HMAC_ALGORITHM = "HmacSHA256"

    /**
     * Detects whether the given text contains PII patterns.
     *
     * @param text The text to scan.
     * @return A list of detected PII types (e.g., "email", "phone").
     */
    fun detectPii(text: String): List<String> {
        val detected = mutableListOf<String>()
        if (EMAIL_PATTERN.containsMatchIn(text)) detected.add("email")
        if (PHONE_PATTERN.containsMatchIn(text)) detected.add("phone")
        if (SSN_PATTERN.containsMatchIn(text)) detected.add("ssn")
        if (CREDIT_CARD_PATTERN.containsMatchIn(text)) detected.add("credit_card")
        return detected
    }

    /**
     * Generates an HMAC-SHA256 signature for request signing.
     *
     * @param payload The request payload to sign.
     * @param secret The signing secret.
     * @return The hex-encoded HMAC signature.
     */
    fun hmacSign(payload: String, secret: String): String {
        val mac = Mac.getInstance(HMAC_ALGORITHM)
        val keySpec = SecretKeySpec(secret.toByteArray(Charsets.UTF_8), HMAC_ALGORITHM)
        mac.init(keySpec)
        val hash = mac.doFinal(payload.toByteArray(Charsets.UTF_8))
        return hash.joinToString("") { "%02x".format(it) }
    }

    /**
     * Verifies an HMAC-SHA256 signature.
     *
     * @param payload The original payload.
     * @param signature The signature to verify (hex-encoded).
     * @param secret The signing secret.
     * @return `true` if the signature is valid.
     */
    fun hmacVerify(payload: String, signature: String, secret: String): Boolean {
        val expected = hmacSign(payload, secret)
        return constantTimeEquals(expected, signature)
    }

    /**
     * Masks an API key for safe display in logs.
     *
     * Shows only the first 4 and last 4 characters.
     *
     * @param apiKey The API key to mask.
     * @return The masked API key string.
     */
    fun maskApiKey(apiKey: String): String {
        if (apiKey.length <= 8) return "****"
        val prefix = apiKey.take(4)
        val suffix = apiKey.takeLast(4)
        val masked = "*".repeat(apiKey.length - 8)
        return "$prefix$masked$suffix"
    }

    /**
     * Validates that an API key meets minimum format requirements.
     *
     * @param apiKey The API key to validate.
     * @return `true` if the key appears valid.
     */
    fun validateApiKeyFormat(apiKey: String): Boolean {
        return apiKey.isNotBlank() && apiKey.length >= 16 && apiKey.all { it.isLetterOrDigit() || it in "-_." }
    }

    /**
     * Generates a cryptographically secure random string suitable for nonces.
     *
     * @param length The length of the random string.
     * @return A Base64-encoded random string.
     */
    fun generateNonce(length: Int = 32): String {
        val bytes = ByteArray(length)
        SecureRandom().nextBytes(bytes)
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)
    }

    /**
     * Constant-time string comparison to prevent timing attacks.
     */
    private fun constantTimeEquals(a: String, b: String): Boolean {
        if (a.length != b.length) return false
        var result = 0
        for (i in a.indices) {
            result = result or (a[i].code xor b[i].code)
        }
        return result == 0
    }
}
