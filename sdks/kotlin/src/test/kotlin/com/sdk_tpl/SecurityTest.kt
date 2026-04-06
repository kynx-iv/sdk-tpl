package com.sdk_tpl

import com.sdk_tpl.security.Security
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class SecurityTest {

    @Test
    fun `detectPii finds email addresses`() {
        val result = Security.detectPii("Contact us at user@example.com for details")
        assertTrue("email" in result)
    }

    @Test
    fun `detectPii finds phone numbers`() {
        val result = Security.detectPii("Call us at +14155551234")
        assertTrue("phone" in result)
    }

    @Test
    fun `detectPii finds SSN`() {
        val result = Security.detectPii("SSN is 123-45-6789")
        assertTrue("ssn" in result)
    }

    @Test
    fun `detectPii finds credit card numbers`() {
        val result = Security.detectPii("Card: 4111 1111 1111 1111")
        assertTrue("credit_card" in result)
    }

    @Test
    fun `detectPii returns empty list for clean text`() {
        val result = Security.detectPii("This is a normal message with no PII")
        assertTrue(result.isEmpty())
    }

    @Test
    fun `detectPii finds multiple types`() {
        val result = Security.detectPii("Email: a@b.com, SSN: 111-22-3333")
        assertTrue("email" in result)
        assertTrue("ssn" in result)
    }

    @Test
    fun `hmacSign produces consistent signatures`() {
        val sig1 = Security.hmacSign("payload", "secret")
        val sig2 = Security.hmacSign("payload", "secret")
        assertEquals(sig1, sig2)
    }

    @Test
    fun `hmacSign produces different signatures for different payloads`() {
        val sig1 = Security.hmacSign("payload1", "secret")
        val sig2 = Security.hmacSign("payload2", "secret")
        assertTrue(sig1 != sig2)
    }

    @Test
    fun `hmacSign produces different signatures for different secrets`() {
        val sig1 = Security.hmacSign("payload", "secret1")
        val sig2 = Security.hmacSign("payload", "secret2")
        assertTrue(sig1 != sig2)
    }

    @Test
    fun `hmacVerify returns true for valid signature`() {
        val signature = Security.hmacSign("payload", "secret")
        assertTrue(Security.hmacVerify("payload", signature, "secret"))
    }

    @Test
    fun `hmacVerify returns false for invalid signature`() {
        assertFalse(Security.hmacVerify("payload", "invalidsig", "secret"))
    }

    @Test
    fun `hmacVerify returns false for tampered payload`() {
        val signature = Security.hmacSign("original", "secret")
        assertFalse(Security.hmacVerify("tampered", signature, "secret"))
    }

    @Test
    fun `maskApiKey masks middle characters`() {
        val masked = Security.maskApiKey("abcd1234efgh5678ijkl")
        assertEquals("abcd************ijkl", masked)
    }

    @Test
    fun `maskApiKey returns stars for short keys`() {
        assertEquals("****", Security.maskApiKey("short"))
    }

    @Test
    fun `maskApiKey handles exactly 8 character key`() {
        assertEquals("****", Security.maskApiKey("12345678"))
    }

    @Test
    fun `validateApiKeyFormat accepts valid keys`() {
        assertTrue(Security.validateApiKeyFormat("abcdefghijklmnop"))
        assertTrue(Security.validateApiKeyFormat("abc-def_ghi.jklmnop"))
    }

    @Test
    fun `validateApiKeyFormat rejects short keys`() {
        assertFalse(Security.validateApiKeyFormat("short"))
    }

    @Test
    fun `validateApiKeyFormat rejects blank keys`() {
        assertFalse(Security.validateApiKeyFormat(""))
        assertFalse(Security.validateApiKeyFormat("   "))
    }

    @Test
    fun `generateNonce produces unique values`() {
        val nonce1 = Security.generateNonce()
        val nonce2 = Security.generateNonce()
        assertTrue(nonce1 != nonce2)
    }

    @Test
    fun `generateNonce produces non-empty string`() {
        val nonce = Security.generateNonce()
        assertTrue(nonce.isNotBlank())
    }
}
