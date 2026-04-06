import 'dart:io';
import 'dart:math';

import '../errors/sdk_tpl_error.dart';

/// Handles retry logic with exponential backoff and jitter.
class RetryHandler {
  /// Maximum number of retry attempts.
  final int maxRetries;

  /// Initial delay before the first retry.
  final Duration initialDelay;

  /// Maximum delay between retries.
  final Duration maxDelay;

  /// Multiplier applied to the delay after each retry.
  final double backoffMultiplier;

  final Random _random = Random();

  /// Creates a new [RetryHandler].
  RetryHandler({
    required this.maxRetries,
    required this.initialDelay,
    required this.maxDelay,
    required this.backoffMultiplier,
  });

  /// Executes [operation] with retry logic.
  ///
  /// Only recoverable errors trigger a retry. Non-recoverable errors are
  /// rethrown immediately.
  Future<T> execute<T>(Future<T> Function() operation) async {
    SdkTplError? lastError;

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await operation();
      } on SdkTplError catch (e) {
        lastError = e;

        if (!e.isRecoverable || attempt == maxRetries) {
          rethrow;
        }

        final delay = calculateDelay(attempt);
        await Future<void>.delayed(delay);
      } catch (e) {
        // Wrap non-SdkTplError exceptions (e.g. from the circuit breaker)
        // into a recoverable SdkTplError so they participate in retry logic.
        final wrapped = SdkTplError.network(
          message: 'Unexpected error: $e',
          cause: e,
        );
        lastError = wrapped;

        if (attempt == maxRetries) {
          throw wrapped;
        }

        final delay = calculateDelay(attempt);
        await Future<void>.delayed(delay);
      }
    }

    // Should be unreachable, but satisfies the type checker.
    throw lastError ??
        SdkTplError.network(message: 'Retry loop exited without result');
  }

  /// Calculates the retry delay for the given [attempt] number.
  ///
  /// Uses exponential backoff with +/-25% multiplicative jitter,
  /// capped at [maxDelay].
  Duration calculateDelay(int attempt) {
    final exponential = pow(backoffMultiplier, attempt.clamp(0, 30));
    final rawMs = initialDelay.inMilliseconds * exponential;
    final baseMs = rawMs.clamp(0, maxDelay.inMilliseconds).toInt();
    final cappedMs = min(baseMs, maxDelay.inMilliseconds);

    // Apply +/-25% multiplicative jitter (matching TypeScript SDK).
    const jitterMin = 0.75;
    const jitterMax = 1.25;
    final jitterFactor =
        jitterMin + _random.nextDouble() * (jitterMax - jitterMin);

    return Duration(milliseconds: (cappedMs * jitterFactor).toInt());
  }

  /// Parses a `Retry-After` header value into a [Duration].
  ///
  /// Supports both delta-seconds format (e.g., `"120"`) and HTTP-date format
  /// (RFC 7231). Returns `null` for unparseable values or dates in the past.
  static Duration? parseRetryAfter(String value) {
    final trimmed = value.trim();
    final seconds = int.tryParse(trimmed);
    if (seconds != null) {
      return Duration(seconds: seconds);
    }

    // Try HTTP-date format (RFC 7231).
    try {
      final date = HttpDate.parse(trimmed);
      final difference = date.difference(DateTime.now());
      if (difference.isNegative) return null;
      return difference;
    } catch (_) {
      return null;
    }
  }
}
