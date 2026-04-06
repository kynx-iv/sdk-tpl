/// Log level used by SDK loggers.
enum LogLevel {
  debug,
  info,
  warn,
  error;

  /// Returns the human-readable label for this log level.
  String get label {
    switch (this) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warn:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
    }
  }

  @override
  String toString() => label;
}

/// Abstract interface for SDK logging implementations.
abstract class Logger {
  /// Logs a message at the given [level].
  void log(LogLevel level, String message);

  /// Convenience method for debug-level messages.
  void debug(String message) => log(LogLevel.debug, message);

  /// Convenience method for info-level messages.
  void info(String message) => log(LogLevel.info, message);

  /// Convenience method for warn-level messages.
  void warn(String message) => log(LogLevel.warn, message);

  /// Convenience method for error-level messages.
  void error(String message) => log(LogLevel.error, message);
}

/// A logger that writes to stderr with level prefixes.
class ConsoleLogger extends Logger {
  /// Minimum level to emit. Messages below this level are discarded.
  final LogLevel? minLevel;

  /// Creates a new [ConsoleLogger] that emits all levels.
  ConsoleLogger({this.minLevel});

  @override
  void log(LogLevel level, String message) {
    if (minLevel != null && level.index < minLevel!.index) {
      return;
    }
    // ignore: avoid_print
    print('[{{SDK_SLUG}}] [${level.label}] $message');
  }
}

/// A logger that silently discards all messages.
class NoopLogger extends Logger {
  @override
  void log(LogLevel level, String message) {
    // intentionally empty
  }
}
