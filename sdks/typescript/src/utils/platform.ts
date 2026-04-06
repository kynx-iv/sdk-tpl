import { SDK_VERSION } from './version';

/**
 * Returns `true` when running inside a browser-like environment.
 */
export function isBrowser(): boolean {
  return typeof globalThis !== 'undefined' && 'window' in globalThis;
}

/**
 * Returns `true` when running inside a Node.js-like environment.
 */
export function isNode(): boolean {
  return typeof process !== 'undefined' && process.versions != null && process.versions.node != null;
}

export type RuntimeEnvironment = 'browser' | 'node' | 'unknown';

/**
 * Determines the current runtime environment.
 */
export function getEnvironment(): RuntimeEnvironment {
  if (isNode()) return 'node';
  if (isBrowser()) return 'browser';
  return 'unknown';
}

/**
 * Returns the SDK User-Agent string suitable for HTTP headers.
 *
 * Format: `sdk_tpl-ts/<version>`
 */
export function getSDKUserAgent(): string {
  return `sdk_tpl-ts/${SDK_VERSION}`;
}
