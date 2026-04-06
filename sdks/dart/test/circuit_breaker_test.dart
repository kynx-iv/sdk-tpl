import 'package:test/test.dart';
import 'package:sdk_tpl/sdk_tpl.dart';

void main() {
  group('CircuitBreaker', () {
    test('starts in closed state', () {
      final cb = CircuitBreaker(
        failureThreshold: 5,
        resetTimeout: const Duration(seconds: 30),
        halfOpenMaxRequests: 1,
      );

      expect(cb.state, equals(CircuitState.closed));
    });

    test('allows requests when closed', () async {
      final cb = CircuitBreaker(
        failureThreshold: 5,
        resetTimeout: const Duration(seconds: 30),
        halfOpenMaxRequests: 1,
      );

      final result = await cb.execute(() async => 42);
      expect(result, equals(42));
      expect(cb.state, equals(CircuitState.closed));
    });

    test('opens after failure threshold is reached', () async {
      final cb = CircuitBreaker(
        failureThreshold: 3,
        resetTimeout: const Duration(seconds: 30),
        halfOpenMaxRequests: 1,
      );

      for (var i = 0; i < 3; i++) {
        try {
          await cb.execute(() async {
            throw SdkTplError.network(message: 'connection refused');
          });
        } on SdkTplError {
          // expected
        }
      }

      expect(cb.state, equals(CircuitState.open));
    });

    test('rejects requests when open', () async {
      final cb = CircuitBreaker(
        failureThreshold: 1,
        resetTimeout: const Duration(seconds: 60),
        halfOpenMaxRequests: 1,
      );

      // Trip the circuit.
      try {
        await cb.execute(() async {
          throw SdkTplError.network(message: 'fail');
        });
      } on SdkTplError {
        // expected
      }

      expect(cb.state, equals(CircuitState.open));

      // Next request should be rejected immediately.
      expect(
        () => cb.execute(() async => 'should not run'),
        throwsA(isA<SdkTplError>()),
      );
    });

    test('non-recoverable errors do not trip the breaker', () async {
      final cb = CircuitBreaker(
        failureThreshold: 1,
        resetTimeout: const Duration(seconds: 30),
        halfOpenMaxRequests: 1,
      );

      try {
        await cb.execute(() async {
          throw SdkTplError.auth();
        });
      } on SdkTplError {
        // expected
      }

      // Auth errors are not recoverable, so the breaker stays closed.
      expect(cb.state, equals(CircuitState.closed));
    });

    test('transitions from half-open to closed on success', () async {
      final cb = CircuitBreaker(
        failureThreshold: 1,
        resetTimeout: const Duration(milliseconds: 50),
        halfOpenMaxRequests: 1,
      );

      // Trip the circuit.
      try {
        await cb.execute(() async {
          throw SdkTplError.network(message: 'fail');
        });
      } on SdkTplError {
        // expected
      }

      expect(cb.state, equals(CircuitState.open));

      // Wait for reset timeout.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(cb.state, equals(CircuitState.halfOpen));

      // Successful probe should close the circuit.
      final result = await cb.execute(() async => 'recovered');
      expect(result, equals('recovered'));
      expect(cb.state, equals(CircuitState.closed));
    });

    test('resets state correctly', () async {
      final cb = CircuitBreaker(
        failureThreshold: 1,
        resetTimeout: const Duration(seconds: 30),
        halfOpenMaxRequests: 1,
      );

      // Trip the circuit.
      try {
        await cb.execute(() async {
          throw SdkTplError.network(message: 'fail');
        });
      } on SdkTplError {
        // expected
      }

      expect(cb.state, equals(CircuitState.open));

      cb.reset();
      expect(cb.state, equals(CircuitState.closed));
    });
  });
}
