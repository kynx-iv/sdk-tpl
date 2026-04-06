import '../errors/error_code.dart';
import '../errors/sdk_tpl_error.dart';

/// The state of the circuit breaker.
enum CircuitState {
  /// All requests are allowed through.
  closed,

  /// Requests are blocked; the circuit tripped after too many failures.
  open,

  /// A limited number of probe requests are allowed to test recovery.
  halfOpen,
}

/// A circuit breaker that monitors outbound request failures and temporarily
/// halts traffic when a failure threshold is reached.
class CircuitBreaker {
  final int failureThreshold;
  final Duration resetTimeout;
  final int halfOpenMaxRequests;

  CircuitState _state = CircuitState.closed;
  int _failureCount = 0;
  int _successCount = 0;
  DateTime? _lastFailureTime;

  /// Creates a new [CircuitBreaker].
  CircuitBreaker({
    required this.failureThreshold,
    required this.resetTimeout,
    required this.halfOpenMaxRequests,
  });

  /// Returns the current effective [CircuitState].
  CircuitState get state {
    if (_state == CircuitState.open && _lastFailureTime != null) {
      final elapsed = DateTime.now().difference(_lastFailureTime!);
      if (elapsed >= resetTimeout) {
        return CircuitState.halfOpen;
      }
    }
    return _state;
  }

  /// Executes [operation] if the circuit allows it, updating internal state
  /// based on the outcome.
  ///
  /// Throws [SdkTplError] with [ErrorCode.circuitBreakerOpen] if the
  /// circuit is open.
  Future<T> execute<T>(Future<T> Function() operation) async {
    final currentState = state;

    if (currentState == CircuitState.open) {
      throw SdkTplError.circuitBreakerOpen();
    }

    try {
      final result = await operation();
      _onSuccess();
      return result;
    } on SdkTplError catch (e) {
      if (e.isRecoverable) {
        _onFailure();
      }
      rethrow;
    } catch (e) {
      _onFailure();
      rethrow;
    }
  }

  void _onSuccess() {
    final currentState = state;
    if (currentState == CircuitState.halfOpen) {
      _successCount++;
      if (_successCount >= halfOpenMaxRequests) {
        _state = CircuitState.closed;
        _failureCount = 0;
        _successCount = 0;
        _lastFailureTime = null;
      }
    } else {
      _failureCount = 0;
    }
  }

  void _onFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    final currentState = state;
    if (currentState == CircuitState.halfOpen) {
      // Probe failed -- reopen.
      _state = CircuitState.open;
      _successCount = 0;
    } else if (_failureCount >= failureThreshold) {
      _state = CircuitState.open;
      _successCount = 0;
    }
  }

  /// Resets the circuit breaker to its initial closed state.
  void reset() {
    _state = CircuitState.closed;
    _failureCount = 0;
    _successCount = 0;
    _lastFailureTime = null;
  }
}
