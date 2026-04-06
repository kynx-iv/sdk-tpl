import Foundation

/// Configuration controlling which patterns are sanitised in error messages.
public struct ErrorSanitizationConfig: Sendable {
    /// Master switch -- when `false` messages pass through untouched.
    public var enabled: Bool
    /// When `true` the original unsanitized message is preserved for local debugging.
    public var preserveOriginal: Bool

    public init(enabled: Bool = true, preserveOriginal: Bool = false) {
        self.enabled = enabled
        self.preserveOriginal = preserveOriginal
    }
}

/// A single sanitisation rule consisting of a regex pattern and its replacement.
private struct SanitizationRule {
    let name: String
    let pattern: NSRegularExpression
    let replacement: String
}

/// Ordered list of sanitisation rules. More specific patterns (e.g. connection
/// strings) precede generic ones to avoid partial matches.
private let sanitizationRules: [SanitizationRule] = {
    func rule(_ name: String, _ pattern: String, _ replacement: String) -> SanitizationRule {
        // Force-try is safe here because patterns are compile-time constants.
        let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        return SanitizationRule(name: name, pattern: regex, replacement: replacement)
    }

    return [
        // Database / service connection strings
        rule(
            "connection-string",
            #"\b(?:postgres|postgresql|mysql|mongodb|mongodb\+srv|redis|rediss)://[^\s'",;)\]}\n]+"#,
            "[CONNECTION_STRING]"
        ),
        // SDK keys (sdk_...)
        rule("sdk-key", #"\bsdk_[A-Za-z0-9_\-]+"#, "sdk_[REDACTED]"),
        // Server keys (srv_...)
        rule("server-key", #"\bsrv_[A-Za-z0-9_\-]+"#, "srv_[REDACTED]"),
        // CLI keys (cli_...)
        rule("cli-key", #"\bcli_[A-Za-z0-9_\-]+"#, "cli_[REDACTED]"),
        // Email addresses
        rule(
            "email",
            #"\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\b"#,
            "[EMAIL]"
        ),
        // IPv4 addresses
        rule("ipv4", #"\b(?:\d{1,3}\.){3}\d{1,3}\b"#, "[IP]"),
        // Windows paths
        rule(
            "windows-path",
            #"\b[A-Z]:\\(?:[^\s\\'",;)\]}\n]+\\)*[^\s\\'",;)\]}\n]*"#,
            "[PATH]"
        ),
        // Unix paths (at least two segments)
        rule(
            "unix-path",
            #"(?:/[A-Za-z0-9._\-]+){2,}(?:/[A-Za-z0-9._\-]*)*"#,
            "[PATH]"
        ),
    ]
}()

/// Module-level default sanitisation configuration.
private var _defaultConfig = ErrorSanitizationConfig()
private let _configLock = NSLock()

/// Returns a copy of the current default sanitisation configuration.
public func getDefaultSanitizationConfig() -> ErrorSanitizationConfig {
    _configLock.lock()
    defer { _configLock.unlock() }
    return _defaultConfig
}

/// Replaces the default sanitisation configuration.
public func setDefaultSanitizationConfig(_ config: ErrorSanitizationConfig) {
    _configLock.lock()
    defer { _configLock.unlock() }
    _defaultConfig = config
}

/// Sanitises `message` by applying every rule whose pattern matches.
///
/// When `config.enabled` is `false` the original message is returned as-is.
///
/// - Parameters:
///   - message: The raw error message to sanitise.
///   - config: Optional override configuration. Uses the module default when `nil`.
/// - Returns: The sanitised message string.
public func sanitizeErrorMessage(
    _ message: String,
    config: ErrorSanitizationConfig? = nil
) -> String {
    let cfg = config ?? getDefaultSanitizationConfig()
    guard cfg.enabled else { return message }

    var result = message
    let range = NSRange(result.startIndex..., in: result)

    for rule in sanitizationRules {
        result = rule.pattern.stringByReplacingMatches(
            in: result,
            options: [],
            range: NSRange(result.startIndex..., in: result),
            withTemplate: rule.replacement
        )
    }

    return result
}
