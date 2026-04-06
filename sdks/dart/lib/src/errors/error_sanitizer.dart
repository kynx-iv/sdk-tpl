/// Compiled regex patterns for detecting sensitive data in error messages.
final List<_SanitizeRule> _sanitizeRules = [
  // API keys
  _SanitizeRule(
    RegExp(r'(?i)(api[_-]?key|apikey|x-api-key)[=:\s]+\S+'),
    r'$1=[REDACTED]',
  ),
  // Bearer tokens
  _SanitizeRule(
    RegExp(r'(?i)(bearer\s+)\S+'),
    r'$1[REDACTED]',
  ),
  // Authorization headers
  _SanitizeRule(
    RegExp(r'(?i)(authorization)[=:\s]+\S+'),
    r'$1=[REDACTED]',
  ),
  // Email addresses
  _SanitizeRule(
    RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
    '[EMAIL_REDACTED]',
  ),
  // Generic secret / password / token fields
  _SanitizeRule(
    RegExp(r'(?i)(password|secret|token|credential)[=:\s]+\S+'),
    r'$1=[REDACTED]',
  ),
];

class _SanitizeRule {
  final RegExp pattern;
  final String replacement;

  const _SanitizeRule(this.pattern, this.replacement);
}

/// Redacts sensitive information from an error message.
///
/// Applies a set of regex replacements to strip API keys, bearer tokens,
/// emails, passwords, and similar secrets from [message].
String sanitizeErrorMessage(String message) {
  var result = message;
  for (final rule in _sanitizeRules) {
    result = result.replaceAllMapped(rule.pattern, (match) {
      // If the replacement contains $1, substitute the first capture group.
      if (rule.replacement.contains(r'$1') && match.groupCount >= 1) {
        return rule.replacement.replaceAll(r'$1', match.group(1) ?? '');
      }
      return rule.replacement;
    });
  }
  return result;
}
