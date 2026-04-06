import 'dart:convert';

import 'package:crypto/crypto.dart';

// ---------------------------------------------------------------------------
// PII Detection
// ---------------------------------------------------------------------------

/// Compiled regex patterns for field names that commonly contain PII.
final List<RegExp> _piiFieldPatterns = [
  RegExp(r'^(email|e[-_]?mail)$', caseSensitive: false),
  RegExp(r'^(phone|mobile|cell|fax)', caseSensitive: false),
  RegExp(r'(first|last|full)[_-]?name', caseSensitive: false),
  RegExp(r'^(ssn|social[_-]?security)', caseSensitive: false),
  RegExp(r'^(address|street|city|zip|postal)', caseSensitive: false),
  RegExp(r'(date[_-]?of[_-]?birth|dob|birthday)', caseSensitive: false),
  RegExp(r'^(passport|driver[_-]?license|national[_-]?id)', caseSensitive: false),
  RegExp(r'(credit[_-]?card|card[_-]?number|cvv|ccn)', caseSensitive: false),
  RegExp(r'^(ip[_-]?address|user[_-]?agent)$', caseSensitive: false),
];

/// Value-level patterns that look like PII regardless of the field name.
final List<_PiiValuePattern> _piiValuePatterns = [
  _PiiValuePattern(
    RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
    'email address',
  ),
  _PiiValuePattern(
    RegExp(r'\b\d{3}[-.]?\d{2}[-.]?\d{4}\b'),
    'SSN',
  ),
  _PiiValuePattern(
    RegExp(r'\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b'),
    'credit card number',
  ),
  _PiiValuePattern(
    RegExp(r'\b\+?1?[-.\s]?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b'),
    'phone number',
  ),
];

class _PiiValuePattern {
  final RegExp pattern;
  final String type;

  const _PiiValuePattern(this.pattern, this.type);
}

/// A single PII detection result.
class PiiDetection {
  /// The type of PII detected (e.g., "email address", "SSN").
  final String piiType;

  /// The field in which the PII was found, if applicable.
  final String? field;

  const PiiDetection({required this.piiType, this.field});

  @override
  String toString() => 'PiiDetection(type: $piiType, field: $field)';
}

/// Checks whether [fieldName] is likely to contain PII.
bool isPotentialPiiField(String fieldName) {
  return _piiFieldPatterns.any((pattern) => pattern.hasMatch(fieldName));
}

/// Scans a map of key-value pairs for potential PII.
///
/// Returns a list of [PiiDetection] entries describing each finding.
List<PiiDetection> detectPotentialPii(Map<String, String> fields) {
  final detections = <PiiDetection>[];

  for (final entry in fields.entries) {
    // Check field name.
    if (isPotentialPiiField(entry.key)) {
      detections.add(PiiDetection(
        piiType: 'PII field name: ${entry.key}',
        field: entry.key,
      ));
    }

    // Check value patterns.
    for (final vp in _piiValuePatterns) {
      if (vp.pattern.hasMatch(entry.value)) {
        detections.add(PiiDetection(
          piiType: vp.type,
          field: entry.key,
        ));
      }
    }
  }

  return detections;
}

// ---------------------------------------------------------------------------
// HMAC-SHA256 Signing
// ---------------------------------------------------------------------------

/// Signs [payload] with [secret] using HMAC-SHA256 and returns the
/// hex-encoded digest.
///
/// Throws [ArgumentError] if [secret] or [payload] is empty.
String signPayload(String secret, String payload) {
  if (secret.isEmpty) throw ArgumentError('secret cannot be empty');
  if (payload.isEmpty) throw ArgumentError('payload cannot be empty');

  final key = utf8.encode(secret);
  final data = utf8.encode(payload);
  final hmacSha256 = Hmac(sha256, key);
  final digest = hmacSha256.convert(data);
  return digest.toString();
}

/// Creates a composite request signature from the body and timestamp.
///
/// The canonical string is `"$timestamp.$body"`.
String createRequestSignature(
  String secret,
  String body,
  int timestamp,
) {
  final canonical = '$timestamp.$body';
  return signPayload(secret, canonical);
}

/// Verifies that [signature] matches the HMAC-SHA256 of [payload] under
/// [secret].
///
/// Uses constant-time comparison to prevent timing attacks.
bool verifySignature(String secret, String payload, String signature) {
  final expected = signPayload(secret, payload);
  return _constantTimeEquals(expected, signature);
}

/// Constant-time string comparison to prevent timing attacks.
bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;

  var result = 0;
  for (var i = 0; i < a.length; i++) {
    result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return result == 0;
}
