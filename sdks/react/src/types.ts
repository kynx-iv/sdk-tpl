import type { SdkTplEmailClient, SdkTplConfig } from '{{ORG_NAME}}/{{SDK_SLUG}}';

/**
 * Props for the SdkTplProvider component.
 */
export interface SdkTplProviderProps {
  /** Configuration for the SdkTpl client. */
  config: SdkTplConfig;
  /** Callback invoked when the client is ready. */
  onReady?: () => void;
  /** Callback invoked when client initialization fails. */
  onError?: (error: Error) => void;
  /** Child components that will have access to the SdkTpl context. */
  children: React.ReactNode;
}

/**
 * Value provided by the SdkTpl React context.
 */
export interface SdkTplContextValue {
  /** The initialized SdkTpl client instance, or null if not yet ready. */
  client: SdkTplEmailClient | null;
  /** Whether the client has been successfully initialized. */
  isReady: boolean;
  /** Whether the client is currently initializing. */
  isLoading: boolean;
  /** Error that occurred during initialization, if any. */
  error: Error | null;
}

/**
 * Options for the useSdkTpl hook.
 */
export interface UseSdkTplOptions {
  /** Callback invoked on successful action execution. */
  onSuccess?: (data: unknown) => void;
  /** Callback invoked when an action fails. */
  onError?: (error: Error) => void;
}

/**
 * Result returned by the useSdkTpl hook.
 */
export interface UseSdkTplResult<T> {
  /** The data returned by the action, or null if not yet executed. */
  data: T | null;
  /** Error that occurred during action execution, if any. */
  error: Error | null;
  /** Whether the action is currently executing. */
  loading: boolean;
  /** Whether the action completed successfully. */
  success: boolean;
  /** Execute the action with optional arguments. */
  execute: (...args: unknown[]) => Promise<T | undefined>;
  /** Reset the hook state to its initial values. */
  reset: () => void;
}
