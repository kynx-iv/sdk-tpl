package com.sdk_tpl;

import com.sdk_tpl.security.Security;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Tests for the {@link Security} class.
 */
class SecurityTest {

    @Nested
    @DisplayName("PII Detection")
    class PiiDetection {

        @Test
        @DisplayName("should detect email addresses")
        void shouldDetectEmail() {
            List<String> detected = Security.detectPii("Contact us at user@example.com for info");
            assertTrue(detected.contains("email"));
        }

        @Test
        @DisplayName("should detect credit card numbers")
        void shouldDetectCreditCard() {
            List<String> detected = Security.detectPii("Card: 4111-1111-1111-1111");
            assertTrue(detected.contains("credit_card"));
        }

        @Test
        @DisplayName("should detect SSN")
        void shouldDetectSsn() {
            List<String> detected = Security.detectPii("SSN: 123-45-6789");
            assertTrue(detected.contains("ssn"));
        }

        @Test
        @DisplayName("should detect phone numbers")
        void shouldDetectPhone() {
            List<String> detected = Security.detectPii("Call (555) 123-4567");
            assertTrue(detected.contains("phone"));
        }

        @Test
        @DisplayName("should detect IP addresses")
        void shouldDetectIpAddress() {
            List<String> detected = Security.detectPii("Server at 192.168.1.100");
            assertTrue(detected.contains("ip_address"));
        }

        @Test
        @DisplayName("should detect multiple PII types")
        void shouldDetectMultiplePii() {
            String text = "Email: user@example.com, SSN: 123-45-6789, IP: 10.0.0.1";
            List<String> detected = Security.detectPii(text);
            assertTrue(detected.size() >= 3);
            assertTrue(detected.contains("email"));
            assertTrue(detected.contains("ssn"));
            assertTrue(detected.contains("ip_address"));
        }

        @Test
        @DisplayName("should return empty list for clean text")
        void shouldReturnEmptyForCleanText() {
            List<String> detected = Security.detectPii("This is a clean text with no PII");
            assertTrue(detected.isEmpty());
        }

        @Test
        @DisplayName("should handle null input")
        void shouldHandleNull() {
            List<String> detected = Security.detectPii(null);
            assertTrue(detected.isEmpty());
        }

        @Test
        @DisplayName("should handle empty input")
        void shouldHandleEmpty() {
            List<String> detected = Security.detectPii("");
            assertTrue(detected.isEmpty());
        }

        @Test
        @DisplayName("containsPii should return true when PII is found")
        void containsPiiShouldReturnTrue() {
            assertTrue(Security.containsPii("user@example.com"));
        }

        @Test
        @DisplayName("containsPii should return false for clean text")
        void containsPiiShouldReturnFalse() {
            assertFalse(Security.containsPii("no pii here"));
        }
    }

    @Nested
    @DisplayName("HMAC Signature")
    class HmacSignature {

        @Test
        @DisplayName("should generate consistent signatures")
        void shouldGenerateConsistentSignatures() {
            String sig1 = Security.generateHmacSignature("payload", "secret");
            String sig2 = Security.generateHmacSignature("payload", "secret");
            assertEquals(sig1, sig2);
        }

        @Test
        @DisplayName("should generate different signatures for different payloads")
        void shouldDifferForDifferentPayloads() {
            String sig1 = Security.generateHmacSignature("payload1", "secret");
            String sig2 = Security.generateHmacSignature("payload2", "secret");
            assertNotEquals(sig1, sig2);
        }

        @Test
        @DisplayName("should generate different signatures for different secrets")
        void shouldDifferForDifferentSecrets() {
            String sig1 = Security.generateHmacSignature("payload", "secret1");
            String sig2 = Security.generateHmacSignature("payload", "secret2");
            assertNotEquals(sig1, sig2);
        }

        @Test
        @DisplayName("should generate hex-encoded output")
        void shouldGenerateHexOutput() {
            String signature = Security.generateHmacSignature("test", "key");
            assertNotNull(signature);
            assertTrue(signature.matches("[0-9a-f]+"));
            assertEquals(64, signature.length()); // SHA-256 produces 32 bytes = 64 hex chars
        }

        @Test
        @DisplayName("should handle empty payload")
        void shouldHandleEmptyPayload() {
            String signature = Security.generateHmacSignature("", "secret");
            assertNotNull(signature);
            assertEquals(64, signature.length());
        }

        @Test
        @DisplayName("should throw on null payload")
        void shouldThrowOnNullPayload() {
            assertThrows(IllegalArgumentException.class,
                    () -> Security.generateHmacSignature(null, "secret"));
        }

        @Test
        @DisplayName("should throw on null secret")
        void shouldThrowOnNullSecret() {
            assertThrows(IllegalArgumentException.class,
                    () -> Security.generateHmacSignature("payload", null));
        }

        @Test
        @DisplayName("should verify valid signature")
        void shouldVerifyValidSignature() {
            String signature = Security.generateHmacSignature("payload", "secret");
            assertTrue(Security.verifyHmacSignature("payload", "secret", signature));
        }

        @Test
        @DisplayName("should reject invalid signature")
        void shouldRejectInvalidSignature() {
            assertFalse(Security.verifyHmacSignature("payload", "secret", "invalidsignature"));
        }

        @Test
        @DisplayName("should reject null signature")
        void shouldRejectNullSignature() {
            assertFalse(Security.verifyHmacSignature("payload", "secret", null));
        }

        @Test
        @DisplayName("should reject tampered payload")
        void shouldRejectTamperedPayload() {
            String signature = Security.generateHmacSignature("original", "secret");
            assertFalse(Security.verifyHmacSignature("tampered", "secret", signature));
        }
    }

    @Nested
    @DisplayName("API Key Helpers")
    class ApiKeyHelpers {

        @Test
        @DisplayName("should validate proper API key format")
        void shouldValidateProperFormat() {
            assertTrue(Security.isValidApiKeyFormat("abcdef1234567890abcdef"));
        }

        @Test
        @DisplayName("should reject short API keys")
        void shouldRejectShortKeys() {
            assertFalse(Security.isValidApiKeyFormat("short"));
        }

        @Test
        @DisplayName("should reject null API keys")
        void shouldRejectNull() {
            assertFalse(Security.isValidApiKeyFormat(null));
        }

        @Test
        @DisplayName("should reject API keys with invalid characters")
        void shouldRejectInvalidChars() {
            assertFalse(Security.isValidApiKeyFormat("abcdef!@#$%^&*()abcdef"));
        }

        @Test
        @DisplayName("should mask API key showing first 4 and last 4 chars")
        void shouldMaskApiKey() {
            String masked = Security.maskApiKey("abcdefghijklmnopqrstuvwxyz");
            assertEquals("abcd****wxyz", masked);
        }

        @Test
        @DisplayName("should mask short keys completely")
        void shouldMaskShortKeys() {
            assertEquals("****", Security.maskApiKey("short"));
        }

        @Test
        @DisplayName("should mask null keys")
        void shouldMaskNull() {
            assertEquals("****", Security.maskApiKey(null));
        }
    }
}
