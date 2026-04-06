<?php

declare(strict_types=1);

namespace SdkTpl;

use SdkTpl\Errors\SdkTplException;
use SdkTpl\Http\HttpClient;
use SdkTpl\Utils\Version;

/**
 * Main client for the {{SDK_NAME}} SDK.
 *
 * Usage:
 * ```php
 * $client = new SdkTplClient([
 *     'apiKey' => 'your-api-key',
 * ]);
 * $health = $client->healthCheck();
 * $client->close();
 * ```
 */
class SdkTplClient
{
    private SdkTplConfig $config;
    private HttpClient $httpClient;

    /**
     * @param array<string, mixed> $config Configuration options.
     *
     * @throws SdkTplException If the configuration is invalid.
     */
    public function __construct(array $config)
    {
        $this->config = new SdkTplConfig($config);
        $this->httpClient = new HttpClient($this->config);
    }

    /**
     * Performs a health check against the API.
     *
     * @return array{status: string, version: string, apiVersion: string}
     *
     * @throws SdkTplException If the request fails.
     */
    public function healthCheck(): array
    {
        try {
            $response = $this->httpClient->get('/health');

            return [
                'status' => 'ok',
                'version' => Version::SDK_VERSION,
                'apiVersion' => $response['apiVersion'] ?? 'unknown',
            ];
        } catch (SdkTplException $e) {
            throw $e;
        } catch (\Throwable $e) {
            throw SdkTplException::networkError('Health check failed: ' . $e->getMessage(), $e);
        }
    }

    /**
     * Sends a request to the API.
     *
     * @param string                    $method HTTP method (GET, POST, PUT, DELETE).
     * @param string                    $path   API endpoint path.
     * @param array<string, mixed>|null $body   Optional request body.
     *
     * @return array<string, mixed> Parsed JSON response.
     *
     * @throws SdkTplException If the request fails.
     */
    public function request(string $method, string $path, ?array $body = null): array
    {
        return match (strtoupper($method)) {
            'GET' => $this->httpClient->get($path),
            'POST' => $this->httpClient->post($path, $body),
            'PUT' => $this->httpClient->put($path, $body),
            'DELETE' => $this->httpClient->delete($path),
            default => throw SdkTplException::validationError("Unsupported HTTP method: {$method}"),
        };
    }

    /**
     * Returns the current configuration.
     */
    public function getConfig(): SdkTplConfig
    {
        return $this->config;
    }

    /**
     * Closes the underlying HTTP client and releases resources.
     */
    public function close(): void
    {
        $this->httpClient->close();
    }
}
