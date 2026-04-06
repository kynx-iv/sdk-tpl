import 'dart:convert';

import 'config.dart';
import 'errors/sdk_tpl_error.dart';
import 'http/http_client.dart';

/// Response from the health check endpoint.
class HealthResponse {
  /// The status of the API (e.g., "ok").
  final String status;

  /// The API version string.
  final String version;

  /// Server timestamp in milliseconds.
  final int timestamp;

  HealthResponse({
    required this.status,
    required this.version,
    required this.timestamp,
  });

  factory HealthResponse.fromJson(Map<String, dynamic> json) {
    return HealthResponse(
      status: json['status'] as String,
      version: json['version'] as String,
      timestamp: json['timestamp'] as int,
    );
  }
}

/// The main SDK client for interacting with the {{SDK_NAME}} API.
///
/// Create an instance with a [{{SDK_SLUG_PASCAL}}Config] and use it to make
/// authenticated requests.
///
/// ```dart
/// final client = {{SDK_SLUG_PASCAL}}Client(
///   {{SDK_SLUG_PASCAL}}Config(apiKey: 'your-api-key'),
/// );
/// ```
class {{SDK_SLUG_PASCAL}}Client {
  final {{SDK_SLUG_PASCAL}}Config _config;
  late final SdkHttpClient _http;
  bool _closed = false;

  /// Creates a new [{{SDK_SLUG_PASCAL}}Client] with the given configuration.
  ///
  /// Throws [{{SDK_SLUG_PASCAL}}Error] if the configuration is invalid.
  {{SDK_SLUG_PASCAL}}Client(this._config) {
    if (_config.apiKey.isEmpty) {
      throw {{SDK_SLUG_PASCAL}}Error.validation(
        message: 'API key is required',
        field: 'apiKey',
      );
    }
    _http = SdkHttpClient(config: _config);
  }

  /// Performs a health check against the API.
  ///
  /// Returns a [HealthResponse] if the API is reachable and healthy.
  ///
  /// Throws [{{SDK_SLUG_PASCAL}}Error] on failure.
  Future<HealthResponse> healthCheck() async {
    _ensureNotClosed();
    final response = await _http.request('GET', '/health');
    final json = jsonDecode(response) as Map<String, dynamic>;
    return HealthResponse.fromJson(json);
  }

  /// Closes the client and releases resources.
  ///
  /// After calling [close], no further requests should be made.
  void close() {
    _closed = true;
    _http.close();
  }

  void _ensureNotClosed() {
    if (_closed) {
      throw {{SDK_SLUG_PASCAL}}Error.validation(
        message: 'Client has been closed',
        field: null,
      );
    }
  }
}
