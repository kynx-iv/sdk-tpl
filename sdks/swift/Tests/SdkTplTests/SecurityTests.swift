import XCTest
@testable import SdkTpl

final class SecurityTests: XCTestCase {

    // MARK: - PII Detection

    func testIsPotentialPIIFieldDetectsCommonFields() {
        let piiFields = ["email", "phone", "ssn", "credit_card", "password"]
        for field in piiFields {
            XCTAssertTrue(
                Security.isPotentialPIIField(field),
                "Expected '\(field)' to be detected as PII"
            )
        }
    }

    func testIsPotentialPIIFieldReturnsFalseForSafeFields() {
        let safeFields = ["name", "age", "color", "flagKey"]
        for field in safeFields {
            XCTAssertFalse(
                Security.isPotentialPIIField(field),
                "Expected '\(field)' to NOT be detected as PII"
            )
        }
    }

    func testIsPotentialPIIFieldHandlesCaseAndSeparators() {
        XCTAssertTrue(Security.isPotentialPIIField("EMAIL"))
        XCTAssertTrue(Security.isPotentialPIIField("Email"))
        XCTAssertTrue(Security.isPotentialPIIField("e-mail"))
        XCTAssertTrue(Security.isPotentialPIIField("e_mail"))
        XCTAssertTrue(Security.isPotentialPIIField("Phone"))
        XCTAssertTrue(Security.isPotentialPIIField("PHONE"))
        XCTAssertTrue(Security.isPotentialPIIField("phone_number"))
        XCTAssertTrue(Security.isPotentialPIIField("creditCard"))
    }

    func testDetectPotentialPIIFindsNestedFields() {
        let data: [String: Any] = [
            "user": [
                "name": "John",
                "email": "john@example.com",
                "profile": [
                    "phone": "555-1234",
                    "bio": "Hello",
                ] as [String: Any],
            ] as [String: Any],
        ]

        let results = Security.detectPotentialPII(data)
        XCTAssertGreaterThanOrEqual(results.count, 2)

        let paths = results.map(\.path)
        XCTAssertTrue(paths.contains(where: { $0.contains("email") }))
        XCTAssertTrue(paths.contains(where: { $0.contains("phone") }))
    }

    func testDetectPotentialPIIReturnsEmptyForSafeData() {
        let data: [String: Any] = [
            "id": 123,
            "status": "active",
            "config": [
                "theme": "dark",
                "locale": "en-US",
            ] as [String: Any],
        ]

        let results = Security.detectPotentialPII(data)
        XCTAssertEqual(results.count, 0)
    }

    // MARK: - Key Helpers

    func testGetKeyIdReturnsFirst8Characters() {
        XCTAssertEqual(Security.getKeyId("sdk_abc12345xyz"), "sdk_abc1")
    }

    func testGetKeyIdHandlesShortKeys() {
        XCTAssertEqual(Security.getKeyId("abc"), "abc")
        XCTAssertEqual(Security.getKeyId(""), "")
    }

    func testIsServerKeyClassifiesCorrectly() {
        XCTAssertTrue(Security.isServerKey("srv_abc123"))
        XCTAssertFalse(Security.isServerKey("sdk_abc123"))
        XCTAssertFalse(Security.isServerKey("cli_abc123"))
        XCTAssertFalse(Security.isServerKey("random_key"))
    }

    func testIsClientKeyClassifiesCorrectly() {
        XCTAssertTrue(Security.isClientKey("sdk_abc123"))
        XCTAssertTrue(Security.isClientKey("cli_abc123"))
        XCTAssertFalse(Security.isClientKey("srv_abc123"))
        XCTAssertFalse(Security.isClientKey("random_key"))
    }

    // MARK: - HMAC-SHA256

    func testGenerateHMACSHA256ProducesConsistentOutput() {
        let key = "test-secret-key"
        let message = "hello world"

        let hash1 = Security.generateHMACSHA256(message: message, key: key)
        let hash2 = Security.generateHMACSHA256(message: message, key: key)

        // Same input should produce same output
        XCTAssertEqual(hash1, hash2)

        // Should be a 64-character hex string (SHA-256)
        XCTAssertEqual(hash1.count, 64)
        XCTAssertTrue(hash1.allSatisfy { "0123456789abcdef".contains($0) })
    }

    func testGenerateHMACSHA256ProducesDifferentOutputForDifferentData() {
        let key = "test-secret-key"
        let hash1 = Security.generateHMACSHA256(message: "data-one", key: key)
        let hash2 = Security.generateHMACSHA256(message: "data-two", key: key)

        XCTAssertNotEqual(hash1, hash2)
    }

    func testGenerateHMACSHA256ProducesDifferentOutputForDifferentKeys() {
        let message = "same-data"
        let hash1 = Security.generateHMACSHA256(message: message, key: "key-one")
        let hash2 = Security.generateHMACSHA256(message: message, key: "key-two")

        XCTAssertNotEqual(hash1, hash2)
    }

    // MARK: - Request Signatures

    func testCreateRequestSignatureReturnsExpectedFields() {
        let apiKey = "sdk_abc12345xyz"
        let body = "{\"to\":\"user@example.com\",\"subject\":\"Hello\"}"

        let result = Security.createRequestSignature(body: body, apiKey: apiKey)

        XCTAssertFalse(result.signature.isEmpty)
        XCTAssertGreaterThan(result.timestamp, 0)
        XCTAssertEqual(result.keyId, "sdk_abc1")
    }

    func testVerifyRequestSignatureValidatesCorrectSignatures() {
        let apiKey = "sdk_abc12345xyz"
        let body = "{\"to\":\"user@example.com\",\"subject\":\"Test\"}"

        let sig = Security.createRequestSignature(body: body, apiKey: apiKey)
        let isValid = Security.verifyRequestSignature(
            body: body,
            signature: sig.signature,
            timestamp: sig.timestamp,
            apiKey: apiKey
        )

        XCTAssertTrue(isValid)
    }

    func testVerifyRequestSignatureRejectsTamperedBody() {
        let apiKey = "sdk_abc12345xyz"
        let originalBody = "{\"to\":\"user@example.com\",\"subject\":\"Test\"}"
        let tamperedBody = "{\"to\":\"attacker@evil.com\",\"subject\":\"Test\"}"

        let sig = Security.createRequestSignature(body: originalBody, apiKey: apiKey)
        let isValid = Security.verifyRequestSignature(
            body: tamperedBody,
            signature: sig.signature,
            timestamp: sig.timestamp,
            apiKey: apiKey
        )

        XCTAssertFalse(isValid)
    }

    func testVerifyRequestSignatureRejectsExpiredSignatures() {
        let apiKey = "sdk_abc12345xyz"
        let body = "{\"to\":\"user@example.com\",\"subject\":\"Test\"}"

        let sig = Security.createRequestSignature(body: body, apiKey: apiKey)

        // Use a timestamp far in the past (10 minutes ago)
        let expiredTimestamp = Int(Date().timeIntervalSince1970 * 1000) - (10 * 60 * 1000)

        let isValid = Security.verifyRequestSignature(
            body: body,
            signature: sig.signature,
            timestamp: expiredTimestamp,
            apiKey: apiKey,
            maxAgeMs: 300_000 // 5 minute max age
        )

        XCTAssertFalse(isValid)
    }
}
