import Foundation

/// Possible states of the circuit breaker.
public enum CircuitState: String, Sendable {
    case closed = "CLOSED"
    case open = "OPEN"
    case halfOpen = "HALF_OPEN"
}

/// Statistics snapshot for the circuit breaker.
public struct CircuitBreakerStats: Sendable {
    public let state: CircuitState
    public let failures: Int
    public let successes: Int
    public let lastFailure: Date?
    public let lastSuccess: Date?
}

/// Actor-based circuit breaker for concurrency-safe request gating.
///
/// - **CLOSED** -- requests flow normally. Consecutive failures increment a
///   counter; once the threshold is reached the circuit opens.
/// - **OPEN** -- requests are rejected immediately with a circuit-open error
///   until ``CircuitBreakerConfig/resetTimeout`` has elapsed, at which point
///   the circuit transitions to half-open.
/// - **HALF_OPEN** -- a limited number of probe requests are allowed through.
///   Success closes the circuit; failure re-opens it.
public actor CircuitBreaker {

    private let config: CircuitBreakerConfig
    private var state: CircuitState = .closed
    private var failures: Int = 0
    private var successes: Int = 0
    private var halfOpenAttempts: Int = 0
    private var lastFailureTime: Date?
    private var lastSuccessTime: Date?

    // MARK: - Initialisation

    public init(config: CircuitBreakerConfig = CircuitBreakerConfig()) {
        self.config = config
    }

    // MARK: - Public API

    /// Wraps an asynchronous operation with circuit breaker semantics.
    ///
    /// - Parameter operation: The async throwing closure to execute.
    /// - Returns: The result of `operation`.
    /// - Throws: ``SdkTplError`` with code ``ErrorCode/circuitOpen`` when the
    ///   circuit is open, or re-throws the operation's error.
    public func execute<T: Sendable>(
        _ operation: @Sendable () async throws -> T
    ) async throws -> T {
        switch state {
        case .open:
            return try await handleOpen(operation)
        case .halfOpen:
            return try await handleHalfOpen(operation)
        case .closed:
            return try await handleClosed(operation)
        }
    }

    /// Returns the current circuit state.
    public func getState() -> CircuitState {
        // Check for automatic transition from open to half-open.
        if state == .open, let lastFailure = lastFailureTime {
            let elapsed = Date().timeIntervalSince(lastFailure)
            if elapsed >= config.resetTimeout {
                return .halfOpen
            }
        }
        return state
    }

    /// Resets the circuit breaker to a pristine closed state.
    public func reset() {
        state = .closed
        failures = 0
        successes = 0
        halfOpenAttempts = 0
        lastFailureTime = nil
        lastSuccessTime = nil
    }

    /// Returns a snapshot of the circuit breaker statistics.
    public func getStats() -> CircuitBreakerStats {
        CircuitBreakerStats(
            state: state,
            failures: failures,
            successes: successes,
            lastFailure: lastFailureTime,
            lastSuccess: lastSuccessTime
        )
    }

    // MARK: - Private Handlers

    private func handleClosed<T: Sendable>(
        _ operation: @Sendable () async throws -> T
    ) async throws -> T {
        do {
            let result = try await operation()
            onSuccess()
            return result
        } catch {
            onFailure()
            if failures >= config.failureThreshold {
                transitionTo(.open)
            }
            throw error
        }
    }

    private func handleOpen<T: Sendable>(
        _ operation: @Sendable () async throws -> T
    ) async throws -> T {
        guard let lastFailure = lastFailureTime else {
            transitionTo(.closed)
            return try await handleClosed(operation)
        }

        let elapsed = Date().timeIntervalSince(lastFailure)

        if elapsed >= config.resetTimeout {
            transitionTo(.halfOpen)
            halfOpenAttempts = 0
            return try await handleHalfOpen(operation)
        }

        let retryAfter = config.resetTimeout - elapsed
        throw SdkTplError.circuitOpenError(retryAfter: retryAfter)
    }

    private func handleHalfOpen<T: Sendable>(
        _ operation: @Sendable () async throws -> T
    ) async throws -> T {
        guard halfOpenAttempts < config.halfOpenRequests else {
            throw SdkTplError.circuitOpenError(retryAfter: config.resetTimeout)
        }

        halfOpenAttempts += 1

        do {
            let result = try await operation()
            onSuccess()
            transitionTo(.closed)
            return result
        } catch {
            onFailure()
            transitionTo(.open)
            throw error
        }
    }

    // MARK: - Private Helpers

    private func onSuccess() {
        successes += 1
        lastSuccessTime = Date()
        if state == .closed {
            failures = 0
        }
    }

    private func onFailure() {
        failures += 1
        lastFailureTime = Date()
    }

    private func transitionTo(_ newState: CircuitState) {
        state = newState
        if newState == .closed {
            failures = 0
            halfOpenAttempts = 0
        }
    }
}
