"""{{SDK_NAME}} SDK error types and utilities."""

from sdk_tpl.errors.error_codes import ErrorCode, NUMERIC_CODE_MAP, is_recoverable_code
from sdk_tpl.errors.sdk_tpl_error import SdkTplError
from sdk_tpl.errors.sanitizer import (
    ErrorSanitizationConfig,
    sanitize_error_message,
)

__all__ = [
    # Core error
    "SdkTplError",
    # Error codes
    "ErrorCode",
    "NUMERIC_CODE_MAP",
    "is_recoverable_code",
    # Sanitizer
    "ErrorSanitizationConfig",
    "sanitize_error_message",
]
