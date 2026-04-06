import { useCallback, useEffect, useRef, useState } from 'react';
import type { SdkTplEmailClient } from '{{ORG_NAME}}/{{SDK_SLUG}}';
import { useSdkTplContext } from '../context';
import type { UseSdkTplOptions, UseSdkTplResult } from '../types';

/**
 * Generic action hook for executing async operations with the SdkTpl client.
 *
 * Manages loading, error, and success states automatically. Handles cleanup
 * on unmount to prevent state updates on unmounted components.
 *
 * @template T - The expected return type of the action function.
 * @param actionFn - An async function that receives the client and returns data.
 * @param options - Optional callbacks for success and error handling.
 * @returns An object containing state and control functions.
 *
 * @example
 * ```tsx
 * import { useSdkTpl } from '{{ORG_NAME}}/sdk_tpl-react';
 *
 * function SendButton() {
 *   const { execute, loading, error, success, data } = useSdkTpl<ResponseType>(
 *     async (client, ...args) => {
 *       return await client.someAction(...args);
 *     },
 *     {
 *       onSuccess: (data) => console.log('Done:', data),
 *       onError: (err) => console.error('Failed:', err),
 *     }
 *   );
 *
 *   return (
 *     <button onClick={() => execute()} disabled={loading}>
 *       {loading ? 'Sending...' : 'Send'}
 *     </button>
 *   );
 * }
 * ```
 */
export function useSdkTpl<T = unknown>(
  actionFn: (client: SdkTplEmailClient, ...args: unknown[]) => Promise<T>,
  options: UseSdkTplOptions = {},
): UseSdkTplResult<T> {
  const { client, isReady } = useSdkTplContext();

  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<Error | null>(null);
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);

  // Track mounted state to prevent updates after unmount
  const mountedRef = useRef(true);
  const abortControllerRef = useRef<AbortController | null>(null);

  // Stable references to callbacks
  const optionsRef = useRef(options);
  optionsRef.current = options;

  // Stable reference to the action function
  const actionFnRef = useRef(actionFn);
  actionFnRef.current = actionFn;

  // Set up unmount cleanup
  useEffect(() => {
    mountedRef.current = true;
    return () => {
      mountedRef.current = false;
      abortControllerRef.current?.abort();
    };
  }, []);

  /**
   * Execute the action with optional arguments.
   */
  const execute = useCallback(
    async (...args: unknown[]): Promise<T | undefined> => {
      if (!client || !isReady) {
        const notReadyError = new Error(
          'SdkTpl client is not ready. Ensure the component is wrapped in a SdkTplProvider.',
        );
        setError(notReadyError);
        optionsRef.current.onError?.(notReadyError);
        return undefined;
      }

      // Abort any in-flight request
      abortControllerRef.current?.abort();
      abortControllerRef.current = new AbortController();

      setLoading(true);
      setError(null);
      setSuccess(false);

      try {
        const result = await actionFnRef.current(client, ...args);

        if (mountedRef.current) {
          setData(result);
          setLoading(false);
          setSuccess(true);
          optionsRef.current.onSuccess?.(result);
        }

        return result;
      } catch (err) {
        // Ignore abort errors
        if (err instanceof DOMException && err.name === 'AbortError') {
          return undefined;
        }

        const actionError =
          err instanceof Error ? err : new Error('An unexpected error occurred');

        if (mountedRef.current) {
          setError(actionError);
          setLoading(false);
          setSuccess(false);
          optionsRef.current.onError?.(actionError);
        }

        return undefined;
      }
    },
    [client, isReady],
  );

  /**
   * Reset the hook state to its initial values.
   */
  const reset = useCallback(() => {
    abortControllerRef.current?.abort();
    setData(null);
    setError(null);
    setLoading(false);
    setSuccess(false);
  }, []);

  return {
    data,
    error,
    loading,
    success,
    execute,
    reset,
  };
}
