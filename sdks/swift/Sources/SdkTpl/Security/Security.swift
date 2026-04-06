import Foundation
import CommonCrypto

/// Security utilities for the SdkTpl Swift SDK.
///
/// Provides PII detection, HMAC-SHA256 signing, and key classification helpers.
public enum Security {

    // MARK: - PII Detection

    /// Field name patterns that commonly indicate PII.
    private static let piiPatterns: [String] = [
        "email", "phone", "telephone", "mobile",
        "ssn", "socialsecurity",
        "creditcard", "cardnumber", "cvv",
        "password", "passwd", "secret",
        "token", "apikey",
        "privatekey",
        "accesstoken",
        "refreshtoken",
        "authtoken",
        "address", "street", "zipcode", "postalcode",
        "dateofbirth", "dob", "birthdate",
        "passport", "driverlicense",
        "nationalid",
        "bankaccount",
        "routingnumber",
        "iban", "swift",
    ]

    /// Normalises a field name by lowercasing and stripping hyphens/underscores.
    private static func normalize(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
    }

    /// Returns `true` when `fieldName` looks like it could contain PII.
    ///
    /// Matching is case-insensitive and ignores hyphens/underscores.
    public static func isPotentialPIIField(_ fieldName: String) -> Bool {
        let normalized = normalize(fieldName)
        return piiPatterns.contains { normalized.contains($0) }
    }

    /// Represents a detected PII field with its dot-delimited path.
    public struct PIIDetection: Sendable {
        public let path: String
        public let field: String
    }

    /// Recursively inspects `data` and returns the paths of any keys that
    /// look like PII fields.
    public static func detectPotentialPII(
        _ data: [String: Any],
        prefix: String? = nil
    ) -> [PIIDetection] {
        var results: [PIIDetection] = []

        for (key, value) in data {
            let path = prefix != nil ? "\(prefix!).\(key)" : key

            if isPotentialPIIField(key) {
                results.append(PIIDetection(path: path, field: key))
            }

            if let nested = value as? [String: Any] {
                results.append(contentsOf: detectPotentialPII(nested, prefix: path))
            }
        }

        return results
    }

    /// Logs a warning when `data` contains fields that look like PII.
    public static func warnIfPotentialPII(
        _ data: [String: Any],
        dataType: String,
        logger: (@Sendable (String) -> Void)? = nil
    ) {
        let detections = detectPotentialPII(data)
        guard !detections.isEmpty else { return }

        let fields = detections.map(\.path).joined(separator: ", ")
        let message = "Potential PII detected in \(dataType) data. " +
            "Fields: [\(fields)]. " +
            "Please review whether this data should be transmitted and ensure " +
            "compliance with your data protection policies."

        if let logger = logger {
            logger(message)
        } else {
            print("[WARNING] \(message)")
        }
    }

    // MARK: - Key Helpers

    /// Returns the first 8 characters of an API key, suitable for logging
    /// without exposing the full secret.
    public static func getKeyId(_ apiKey: String) -> String {
        String(apiKey.prefix(8))
    }

    /// Returns `true` when the key is a server-side key (prefixed with `srv_`).
    public static func isServerKey(_ apiKey: String) -> Bool {
        apiKey.hasPrefix("srv_")
    }

    /// Returns `true` when the key is a client-side key (prefixed with `sdk_` or `cli_`).
    public static func isClientKey(_ apiKey: String) -> Bool {
        apiKey.hasPrefix("sdk_") || apiKey.hasPrefix("cli_")
    }

    // MARK: - HMAC-SHA256

    /// Generates an HMAC-SHA256 hex digest of `message` using `key`.
    ///
    /// Uses CommonCrypto for the underlying cryptographic operation.
    ///
    /// - Parameters:
    ///   - message: The message to sign.
    ///   - key: The secret key.
    /// - Returns: A lowercase hex string of the HMAC digest.
    public static func generateHMACSHA256(message: String, key: String) -> String {
        let keyData = Data(key.utf8)
        let messageData = Data(message.utf8)

        var hmac = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))

        keyData.withUnsafeBytes { keyBytes in
            messageData.withUnsafeBytes { messageBytes in
                CCHmac(
                    CCHmacAlgorithm(kCCHmacAlgSHA256),
                    keyBytes.baseAddress,
                    keyData.count,
                    messageBytes.baseAddress,
                    messageData.count,
                    &hmac
                )
            }
        }

        return hmac.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Payload Signing

    /// Signed payload containing data, signature, timestamp, and key identifier.
    public struct SignedPayload: @unchecked Sendable {
        public let data: Any
        public let signature: String
        public let timestamp: Int
        public let keyId: String
    }

    /// Signs arbitrary data with an HMAC-SHA256 signature.
    ///
    /// - Parameters:
    ///   - data: The data to sign (must be JSON-serialisable).
    ///   - apiKey: The secret key used for signing.
    ///   - timestamp: Optional epoch timestamp; defaults to current time.
    /// - Returns: A ``SignedPayload``.
    public static func signPayload(
        data: Any,
        apiKey: String,
        timestamp: Int? = nil
    ) -> SignedPayload? {
        let ts = timestamp ?? Int(Date().timeIntervalSince1970 * 1000)

        guard let jsonData = try? JSONSerialization.data(
            withJSONObject: ["data": data, "timestamp": ts]
        ),
        let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }

        let signature = generateHMACSHA256(message: jsonString, key: apiKey)

        return SignedPayload(
            data: data,
            signature: signature,
            timestamp: ts,
            keyId: getKeyId(apiKey)
        )
    }

    /// Request signature containing the hex signature, timestamp, and key ID.
    public struct RequestSignature: Sendable {
        public let signature: String
        public let timestamp: Int
        public let keyId: String
    }

    /// Creates an HMAC-SHA256 signature for an HTTP request body.
    ///
    /// The signed message has the form `<timestamp>.<body>` so that the
    /// timestamp is bound to the payload.
    public static func createRequestSignature(
        body: String,
        apiKey: String
    ) -> RequestSignature {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let message = "\(timestamp).\(body)"
        let signature = generateHMACSHA256(message: message, key: apiKey)

        return RequestSignature(
            signature: signature,
            timestamp: timestamp,
            keyId: getKeyId(apiKey)
        )
    }

    /// Verifies an HMAC-SHA256 request signature.
    ///
    /// - Parameters:
    ///   - body: The raw request body that was signed.
    ///   - signature: The hex signature to verify.
    ///   - timestamp: The epoch-millisecond timestamp bound to the signature.
    ///   - apiKey: The shared secret used to produce the signature.
    ///   - maxAgeMs: Maximum acceptable age of the signature in milliseconds.
    ///               Defaults to 5 minutes (300,000 ms).
    /// - Returns: `true` when the signature is valid and within the age window.
    public static func verifyRequestSignature(
        body: String,
        signature: String,
        timestamp: Int,
        apiKey: String,
        maxAgeMs: Int = 5 * 60 * 1000
    ) -> Bool {
        // Reject if the signature is too old (or from the future).
        let now = Int(Date().timeIntervalSince1970 * 1000)
        let age = abs(now - timestamp)
        guard age <= maxAgeMs else { return false }

        let message = "\(timestamp).\(body)"
        let expected = generateHMACSHA256(message: message, key: apiKey)

        // Constant-time comparison to avoid timing attacks.
        guard expected.count == signature.count else { return false }

        var mismatch: UInt8 = 0
        for (a, b) in zip(expected.utf8, signature.utf8) {
            mismatch |= a ^ b
        }

        return mismatch == 0
    }
}
