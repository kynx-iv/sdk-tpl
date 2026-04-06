# frozen_string_literal: true

require_relative "sdk_tpl/version"
require_relative "sdk_tpl/config"
require_relative "sdk_tpl/client"
require_relative "sdk_tpl/errors/error_codes"
require_relative "sdk_tpl/errors/sdk_tpl_error"
require_relative "sdk_tpl/errors/error_sanitizer"
require_relative "sdk_tpl/http/circuit_breaker"
require_relative "sdk_tpl/http/retry_handler"
require_relative "sdk_tpl/http/http_client"
require_relative "sdk_tpl/security/security"
require_relative "sdk_tpl/models/email_provider"
require_relative "sdk_tpl/models/email"
require_relative "sdk_tpl/validators/email_validators"

# SdkTpl Ruby SDK
#
# Provides a high-level client for interacting with the SdkTpl API,
# with built-in retry logic, circuit breaking, request signing, and error
# sanitization.
#
# @example Basic usage
#   client = SdkTpl::Client.new(api_key: "your-api-key")
#   health = client.health_check
#   puts health["status"]
#   client.close
module SdkTpl
end
