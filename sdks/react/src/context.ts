import { createContext, useContext } from 'react';
import type { SdkTplContextValue } from './types';

/**
 * Unique key used to store the context on the global window object.
 * This prevents issues with module duplication in monorepos (pnpm, yalc, etc.)
 * where multiple copies of this package might be loaded.
 */
const CONTEXT_KEY = '__SDK_TPL_REACT_CONTEXT__';

/**
 * Gets or creates the SdkTpl React context using a global registry pattern.
 *
 * This ensures that even if multiple copies of the SDK are loaded (common in
 * monorepo setups with pnpm, yalc, or similar tools), they all share the same
 * React context instance.
 *
 * The default value is `undefined` so that `useSdkTplContext` can detect when
 * a component is rendered outside of a SdkTplProvider and throw an error.
 *
 * @returns The shared React context for SdkTpl.
 */
export function getOrCreateContext(): React.Context<SdkTplContextValue | undefined> {
  // Use globalThis for cross-environment compatibility (browser, Node, workers)
  const globalRegistry = globalThis as unknown as Record<
    string,
    React.Context<SdkTplContextValue | undefined> | undefined
  >;

  if (!globalRegistry[CONTEXT_KEY]) {
    globalRegistry[CONTEXT_KEY] = createContext<SdkTplContextValue | undefined>(undefined);
    globalRegistry[CONTEXT_KEY]!.displayName = 'SdkTplContext';
  }

  return globalRegistry[CONTEXT_KEY]!;
}

/**
 * Hook to access the SdkTpl context.
 *
 * Must be used within a SdkTplProvider. Throws an error if used
 * outside of the provider tree.
 *
 * @returns The current SdkTpl context value.
 * @throws Error if used outside of a SdkTplProvider.
 *
 * @example
 * ```tsx
 * function MyComponent() {
 *   const { client, isReady, error } = useSdkTplContext();
 *
 *   if (!isReady) return <div>Loading...</div>;
 *   if (error) return <div>Error: {error.message}</div>;
 *
 *   return <div>Client ready!</div>;
 * }
 * ```
 */
export function useSdkTplContext(): SdkTplContextValue {
  const context = useContext(getOrCreateContext());

  if (context === undefined) {
    throw new Error(
      'useSdkTplContext must be used within a SdkTplProvider. ' +
        'Wrap your component tree with <SdkTplProvider config={...}>.',
    );
  }

  return context;
}
