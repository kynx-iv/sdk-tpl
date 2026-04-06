/// SdkTpl - Official Dart SDK.
///
/// Provides a type-safe client for interacting with the SdkTpl API.
///
/// ```dart
/// import 'package:sdk_tpl/sdk_tpl.dart';
///
/// final client = SdkTplClient(
///   SdkTplConfig(apiKey: 'your-api-key'),
/// );
///
/// final health = await client.healthCheck();
/// print(health.status);
/// ```
library sdk_tpl;

export 'src/client.dart';
export 'src/config.dart';
export 'src/errors/error_code.dart';
export 'src/errors/sdk_tpl_error.dart';
export 'src/errors/error_sanitizer.dart';
export 'src/http/http_client.dart';
export 'src/http/circuit_breaker.dart';
export 'src/http/retry_handler.dart';
export 'src/models/email_provider.dart';
export 'src/models/email_models.dart';
export 'src/security/security.dart';
export 'src/utils/version.dart';
export 'src/utils/logger.dart';
