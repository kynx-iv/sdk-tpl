//! # SdkTpl
//!
//! Official Rust SDK for the SdkTpl API.
//!
//! ## Quick Start
//!
//! ```rust
//! use sdk_tpl::SdkTplClient;
//! use sdk_tpl::SdkTplConfig;
//!
//! #[tokio::main]
//! async fn main() -> Result<(), Box<dyn std::error::Error>> {
//!     let config = SdkTplConfig::builder()
//!         .api_key("your-api-key")
//!         .build()?;
//!
//!     let client = SdkTplClient::new(config)?;
//!     let health = client.health_check().await?;
//!     println!("Status: {}", health.status);
//!
//!     Ok(())
//! }
//! ```

pub mod client;
pub mod config;
pub mod email_client;
pub mod errors;
pub mod http;
pub mod models;
pub mod security;
pub mod utils;
pub mod validators;

// Re-exports for convenience
pub use client::SdkTplClient;
pub use config::{SdkTplConfig, RetryConfig, CircuitBreakerConfig};
pub use errors::{SdkTplError, ErrorCode};
