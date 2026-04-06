import 'dart:io' show Platform;

/// Returns the value of the named environment variable, or null if not set.
String? getEnvironmentVariable(String name) => Platform.environment[name];
