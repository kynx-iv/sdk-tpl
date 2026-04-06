package errors

import (
	"fmt"
	"time"
)

// ErrorCode represents a categorized error code from the {{SDK_NAME}} SDK.
type ErrorCode string

const (
	// Initialization errors.
	ErrInitFailed ErrorCode = "INIT_FAILED"

	// Authentication errors.
	ErrAuthFailed       ErrorCode = "AUTH_FAILED"
	ErrAuthExpired      ErrorCode = "AUTH_EXPIRED"
	ErrAuthInvalidKey   ErrorCode = "AUTH_INVALID_KEY"
	ErrAuthMissingKey   ErrorCode = "AUTH_MISSING_KEY"
	ErrAuthKeyRotation  ErrorCode = "AUTH_KEY_ROTATION"

	// Network errors.
	ErrNetworkTimeout    ErrorCode = "NETWORK_TIMEOUT"
	ErrNetworkConnection ErrorCode = "NETWORK_CONNECTION"
	ErrNetworkDNS        ErrorCode = "NETWORK_DNS"
	ErrNetworkSSL        ErrorCode = "NETWORK_SSL"

	// Rate limiting errors.
	ErrRateLimited ErrorCode = "RATE_LIMITED"

	// Server errors.
	ErrServerError ErrorCode = "SERVER_ERROR"

	// Circuit breaker errors.
	ErrCircuitOpen ErrorCode = "CIRCUIT_OPEN"

	// Configuration errors.
	ErrConfigInvalid  ErrorCode = "CONFIG_INVALID"
	ErrConfigMissing  ErrorCode = "CONFIG_MISSING"

	// Security errors.
	ErrSecurityPII            ErrorCode = "SECURITY_PII"
	ErrSecuritySignature      ErrorCode = "SECURITY_SIGNATURE"
	ErrSecuritySignatureExpired ErrorCode = "SECURITY_SIGNATURE_EXPIRED"
	ErrSecurityInvalidKey     ErrorCode = "SECURITY_INVALID_KEY"

	// Validation errors.
	ErrValidationFailed  ErrorCode = "VALIDATION_FAILED"
	ErrValidationFormat  ErrorCode = "VALIDATION_FORMAT"
	ErrValidationRange   ErrorCode = "VALIDATION_RANGE"
	ErrValidationRequired ErrorCode = "VALIDATION_REQUIRED"
)

// NumericCodeMap maps ErrorCode values to numeric codes for structured logging
// and API compatibility.
var NumericCodeMap = map[ErrorCode]int{
	ErrInitFailed:               1000,
	ErrAuthFailed:               2000,
	ErrAuthExpired:              2001,
	ErrAuthInvalidKey:           2002,
	ErrAuthMissingKey:           2003,
	ErrAuthKeyRotation:          2004,
	ErrNetworkTimeout:           3000,
	ErrNetworkConnection:        3001,
	ErrNetworkDNS:               3002,
	ErrNetworkSSL:               3003,
	ErrRateLimited:              3100,
	ErrServerError:              3200,
	ErrCircuitOpen:              4000,
	ErrConfigInvalid:            5000,
	ErrConfigMissing:            5001,
	ErrSecurityPII:              6000,
	ErrSecuritySignature:        6001,
	ErrSecuritySignatureExpired: 6002,
	ErrSecurityInvalidKey:       6003,
	ErrValidationFailed:         7000,
	ErrValidationFormat:         7001,
	ErrValidationRange:          7002,
	ErrValidationRequired:       7003,
}

// SdkTplError is the primary error type returned by the {{SDK_NAME}} SDK.
// It carries structured information about the error including its category,
// recoverability, and optional details.
type SdkTplError struct {
	// Code is the categorized error code.
	Code ErrorCode

	// Message is a human-readable error message.
	Message string

	// Cause is the underlying error that caused this error, if any.
	Cause error

	// Recoverable indicates whether the operation can be retried.
	Recoverable bool

	// StatusCode is the HTTP status code, if applicable.
	StatusCode int

	// RetryAfter is the suggested duration to wait before retrying.
	RetryAfter time.Duration

	// RequestID is the request ID returned by the server, if available.
	RequestID string

	// Timestamp is the time the error was created.
	Timestamp time.Time

	// Details contains additional structured error details.
	Details map[string]any
}

// Error implements the error interface.
func (e *SdkTplError) Error() string {
	if e.Cause != nil {
		return fmt.Sprintf("[%s] %s: %v", e.Code, e.Message, e.Cause)
	}
	return fmt.Sprintf("[%s] %s", e.Code, e.Message)
}

// Unwrap returns the underlying cause error for use with errors.Is and errors.As.
func (e *SdkTplError) Unwrap() error {
	return e.Cause
}

// IsRecoverableErr reports whether this error is recoverable (i.e., the operation
// may succeed if retried).
func (e *SdkTplError) IsRecoverableErr() bool {
	return e.Recoverable
}

// WithDetails returns a copy of the error with additional details merged in.
func (e *SdkTplError) WithDetails(details map[string]any) *SdkTplError {
	merged := make(map[string]any)
	for k, v := range e.Details {
		merged[k] = v
	}
	for k, v := range details {
		merged[k] = v
	}
	cp := *e
	cp.Details = merged
	return &cp
}

// NewError creates a new SdkTplError with the given code and message.
func NewError(code ErrorCode, message string) *SdkTplError {
	return &SdkTplError{
		Code:      code,
		Message:   message,
		Timestamp: time.Now(),
		Details:   make(map[string]any),
	}
}

// NewErrorWithCause creates a new SdkTplError wrapping an underlying cause.
func NewErrorWithCause(code ErrorCode, message string, cause error) *SdkTplError {
	return &SdkTplError{
		Code:      code,
		Message:   message,
		Cause:     cause,
		Timestamp: time.Now(),
		Details:   make(map[string]any),
	}
}

// NetworkError creates a new recoverable network error.
func NetworkError(message string, cause error) *SdkTplError {
	return &SdkTplError{
		Code:        ErrNetworkConnection,
		Message:     message,
		Cause:       cause,
		Recoverable: true,
		Timestamp:   time.Now(),
		Details:     make(map[string]any),
	}
}

// AuthenticationError creates a new non-recoverable authentication error.
func AuthenticationError(message string) *SdkTplError {
	return &SdkTplError{
		Code:        ErrAuthFailed,
		Message:     message,
		Recoverable: false,
		StatusCode:  401,
		Timestamp:   time.Now(),
		Details:     make(map[string]any),
	}
}

// SecurityError creates a new non-recoverable security error.
func SecurityError(message string) *SdkTplError {
	return &SdkTplError{
		Code:        ErrSecurityPII,
		Message:     message,
		Recoverable: false,
		Timestamp:   time.Now(),
		Details:     make(map[string]any),
	}
}

// IsRecoverable reports whether the given error is a recoverable SdkTplError.
func IsRecoverable(err error) bool {
	if sdkErr, ok := err.(*SdkTplError); ok {
		return sdkErr.Recoverable
	}
	return false
}
