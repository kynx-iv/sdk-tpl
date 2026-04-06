use crate::config::SdkTplConfig;
use crate::errors::SdkTplError;
use crate::http::client::HttpClient;

/// Response from the health check endpoint.
#[derive(Debug, Clone, serde::Deserialize)]
pub struct HealthResponse {
    /// The status of the API (e.g., "ok").
    pub status: String,
    /// The API version string.
    pub version: String,
    /// Server timestamp in milliseconds.
    pub timestamp: u64,
}

/// The main SDK client for interacting with the SdkTpl API.
///
/// Create an instance using [`SdkTplClient::new`] with a
/// [`SdkTplConfig`].
pub struct SdkTplClient {
    http: HttpClient,
    #[allow(dead_code)]
    config: SdkTplConfig,
}

impl SdkTplClient {
    /// Creates a new `SdkTplClient` from the provided configuration.
    ///
    /// # Errors
    ///
    /// Returns [`SdkTplError::Validation`] if the configuration is
    /// invalid (e.g., missing API key).
    pub fn new(config: SdkTplConfig) -> Result<Self, SdkTplError> {
        if config.api_key.is_empty() {
            return Err(SdkTplError::Validation {
                message: "API key is required".to_string(),
                code: crate::errors::ErrorCode::Validation,
                field: Some("api_key".to_string()),
            });
        }

        let http = HttpClient::new(&config)?;

        Ok(Self { http, config })
    }

    /// Performs a health check against the API.
    ///
    /// # Errors
    ///
    /// Returns a [`SdkTplError`] if the request fails or the
    /// response cannot be parsed.
    pub async fn health_check(&self) -> Result<HealthResponse, SdkTplError> {
        let response: HealthResponse = self.http.request("GET", "/health", None::<&()>).await?;
        Ok(response)
    }

    /// Closes the client and releases any held resources.
    ///
    /// After calling `close`, the client should not be used for further
    /// requests.
    pub fn close(self) {
        drop(self);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::SdkTplConfig;

    #[test]
    fn test_client_requires_api_key() {
        let result = SdkTplConfig::builder()
            .api_key("")
            .build();
        assert!(result.is_err());
    }
}
