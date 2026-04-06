import Foundation

/// Handles retry logic with exponential backoff and jitter for the
/// SdkTpl Swift SDK.
struct RetryHandler: Sendable {

    private let config: RetryConfig

    init(config: RetryConfig = RetryConfig()) {
        self.config = config
    }

    // MARK: - Public API

    /// Executes `operation` and retries it up to ``RetryConfig/maxRetries``
    /// times when a retryable error is encountered.
    ///
    /// The delay between attempts uses exponential backoff with +/-25% jitter,
    /// but honours `retryAfter` values carried on ``SdkTplError`` instances.
    ///
    /// - Parameter operation: The async throwing closure to execute.
    /// - Returns: The result of a successful invocation.
    /// - Throws: The last error encountered after all retries are exhausted.
    func execute<T: Sendable>(
        _ operation: @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0...config.maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error

                // If all retries exhausted, break immediately.
                if attempt >= config.maxRetries {
                    break
                }

                // Only retry when the error is eligible.
                guard isRetryable(error) else {
                    break
                }

                // Determine delay -- prefer retryAfter from the error when present.
                let delay: TimeInterval
                if let sdkError = error as? SdkTplError,
                   let retryAfter = sdkError.retryAfter,
                   retryAfter > 0 {
                    delay = min(retryAfter, config.maxDelay)
                } else {
                    delay = calculateDelay(attempt: attempt)
                }

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        throw lastError ?? SdkTplError(
            code: .networkRetryLimit,
            message: "All retry attempts exhausted"
        )
    }

    // MARK: - Helpers

    /// Returns `true` when the error is eligible for retry based on its error
    /// code, recoverability, or HTTP status code.
    func isRetryable(_ error: Error) -> Bool {
        guard let sdkError = error as? SdkTplError else { return false }

        // Network and timeout errors are always retryable
        if sdkError.code == .networkError || sdkError.code == .networkTimeout {
            return true
        }

        // Also retry if explicitly marked recoverable
        if sdkError.isRecoverable {
            return true
        }

        guard let statusCode = sdkError.statusCode else { return false }
        return config.retryableStatusCodes.contains(statusCode)
    }

    /// Calculates the delay for a given retry attempt using exponential
    /// backoff with +/-25% jitter.
    ///
    /// - Parameter attempt: Zero-based attempt index (0 = first retry).
    /// - Returns: Delay in seconds.
    func calculateDelay(attempt: Int) -> TimeInterval {
        let cappedAttempt = min(attempt, 30)
        let exponential = config.baseDelay * pow(2.0, Double(cappedAttempt))
        let capped = min(exponential, config.maxDelay)

        // Apply +/-25% jitter: factor in [0.75, 1.25)
        let jitterFactor = 0.75 + Double.random(in: 0..<0.5)
        return capped * jitterFactor
    }
}
