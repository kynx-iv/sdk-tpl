import 'package:test/test.dart';
import 'package:sdk_tpl/sdk_tpl.dart';

void main() {
  // -------------------------------------------------------------------------
  // PII Detection Tests
  // -------------------------------------------------------------------------
  group('PII Detection', () {
    group('isPotentialPiiField', () {
      test('detects known PII field names', () {
        expect(isPotentialPiiField('email'), isTrue);
        expect(isPotentialPiiField('Email'), isTrue);
        expect(isPotentialPiiField('e_mail'), isTrue);
        expect(isPotentialPiiField('first_name'), isTrue);
        expect(isPotentialPiiField('lastName'), isTrue);
        expect(isPotentialPiiField('phone'), isTrue);
        expect(isPotentialPiiField('ssn'), isTrue);
        expect(isPotentialPiiField('address'), isTrue);
        expect(isPotentialPiiField('credit_card'), isTrue);
        expect(isPotentialPiiField('date_of_birth'), isTrue);
      });

      test('does not flag non-PII field names', () {
        expect(isPotentialPiiField('status'), isFalse);
        expect(isPotentialPiiField('count'), isFalse);
        expect(isPotentialPiiField('created_at'), isFalse);
        expect(isPotentialPiiField('id'), isFalse);
        expect(isPotentialPiiField('type'), isFalse);
      });
    });

    group('detectPotentialPii', () {
      test('detects email address in value', () {
        final detections = detectPotentialPii({
          'notes': 'Contact user@example.com for details',
        });

        expect(
          detections.any((d) => d.piiType == 'email address'),
          isTrue,
        );
      });

      test('detects phone number in value', () {
        final detections = detectPotentialPii({
          'message': 'Call me at 555-123-4567',
        });

        expect(
          detections.any((d) => d.piiType == 'phone number'),
          isTrue,
        );
      });

      test('detects SSN in value', () {
        final detections = detectPotentialPii({
          'data': 'SSN is 123-45-6789',
        });

        expect(
          detections.any((d) => d.piiType == 'SSN'),
          isTrue,
        );
      });

      test('returns empty list for clean data', () {
        final detections = detectPotentialPii({
          'status': 'active',
          'count': '42',
          'message': 'Hello world',
        });

        expect(detections, isEmpty);
      });

      test('detects PII in field name and value simultaneously', () {
        final detections = detectPotentialPii({
          'email': 'user@example.com',
        });

        // Should detect both: PII field name AND email in value.
        expect(detections.length, greaterThanOrEqualTo(2));
      });
    });
  });

  // -------------------------------------------------------------------------
  // HMAC Signature Tests
  // -------------------------------------------------------------------------
  group('HMAC Signing', () {
    test('signPayload produces a hex string', () {
      final signature = signPayload('test-secret', 'test-payload');
      expect(signature, isNotEmpty);
      // Verify it is valid hex (only hex chars).
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(signature), isTrue);
    });

    test('signPayload is deterministic', () {
      final sig1 = signPayload('test-secret', 'test-payload');
      final sig2 = signPayload('test-secret', 'test-payload');
      expect(sig1, equals(sig2));
    });

    test('different inputs produce different signatures', () {
      final sig1 = signPayload('test-secret', 'payload-a');
      final sig2 = signPayload('test-secret', 'payload-b');
      expect(sig1, isNot(equals(sig2)));
    });

    test('verifySignature accepts valid signature', () {
      final signature = signPayload('my-secret', 'important data');
      expect(verifySignature('my-secret', 'important data', signature), isTrue);
    });

    test('verifySignature rejects tampered payload', () {
      final signature = signPayload('my-secret', 'original');
      expect(verifySignature('my-secret', 'tampered', signature), isFalse);
    });

    test('verifySignature rejects wrong secret', () {
      final signature = signPayload('secret-a', 'data');
      expect(verifySignature('secret-b', 'data', signature), isFalse);
    });

    test('verifySignature rejects malformed signature', () {
      expect(
        verifySignature('secret', 'data', 'not-a-valid-signature'),
        isFalse,
      );
    });

    test('createRequestSignature is deterministic', () {
      final sig1 = createRequestSignature(
        'webhook-secret',
        '{"to":"a"}',
        1000,
      );
      final sig2 = createRequestSignature(
        'webhook-secret',
        '{"to":"a"}',
        1000,
      );
      expect(sig1, equals(sig2));
    });

    test('createRequestSignature varies with body', () {
      final sig1 = createRequestSignature(
        'webhook-secret',
        '{"to":"a"}',
        1,
      );
      final sig2 = createRequestSignature(
        'webhook-secret',
        '{"to":"b"}',
        1,
      );
      expect(sig1, isNot(equals(sig2)));
    });

    test('createRequestSignature varies with timestamp', () {
      final sig1 = createRequestSignature(
        'secret',
        '{}',
        1000,
      );
      final sig2 = createRequestSignature(
        'secret',
        '{}',
        2000,
      );
      expect(sig1, isNot(equals(sig2)));
    });
  });
}
