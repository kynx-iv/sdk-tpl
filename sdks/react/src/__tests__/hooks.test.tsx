import React from 'react';
import { renderHook, act, waitFor } from '@testing-library/react';
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { use{{SDK_SLUG_PASCAL}} } from '../hooks/useSdkTpl';
import { getOrCreateContext } from '../context';
import type { {{SDK_SLUG_PASCAL}}ContextValue } from '../types';

const CONTEXT_KEY = '__{{SDK_SLUG_UPPER}}_REACT_CONTEXT__';

/**
 * Creates a wrapper component that provides mock context values.
 */
function createWrapper(contextValue: Partial<{{SDK_SLUG_PASCAL}}ContextValue> = {}) {
  const Context = getOrCreateContext();

  const defaultValue: {{SDK_SLUG_PASCAL}}ContextValue = {
    client: { someAction: vi.fn() } as unknown as {{SDK_SLUG_PASCAL}}ContextValue['client'],
    isReady: true,
    isLoading: false,
    error: null,
    ...contextValue,
  };

  return function Wrapper({ children }: { children: React.ReactNode }) {
    return <Context.Provider value={defaultValue}>{children}</Context.Provider>;
  };
}

describe('use{{SDK_SLUG_PASCAL}}', () => {
  afterEach(() => {
    vi.restoreAllMocks();
    const globalRegistry = globalThis as unknown as Record<string, unknown>;
    delete globalRegistry[CONTEXT_KEY];
  });

  it('should return initial state', () => {
    const actionFn = vi.fn();
    const { result } = renderHook(() => use{{SDK_SLUG_PASCAL}}(actionFn), {
      wrapper: createWrapper(),
    });

    expect(result.current.data).toBeNull();
    expect(result.current.error).toBeNull();
    expect(result.current.loading).toBe(false);
    expect(result.current.success).toBe(false);
    expect(typeof result.current.execute).toBe('function');
    expect(typeof result.current.reset).toBe('function');
  });

  it('should execute action and return data on success', async () => {
    const mockData = { id: 1, name: 'test' };
    const actionFn = vi.fn().mockResolvedValue(mockData);

    const { result } = renderHook(() => use{{SDK_SLUG_PASCAL}}<typeof mockData>(actionFn), {
      wrapper: createWrapper(),
    });

    await act(async () => {
      await result.current.execute();
    });

    expect(result.current.data).toEqual(mockData);
    expect(result.current.success).toBe(true);
    expect(result.current.loading).toBe(false);
    expect(result.current.error).toBeNull();
  });

  it('should set loading state during execution', async () => {
    let resolvePromise: (value: string) => void;
    const actionFn = vi.fn().mockImplementation(
      () => new Promise<string>((resolve) => { resolvePromise = resolve; }),
    );

    const { result } = renderHook(() => use{{SDK_SLUG_PASCAL}}<string>(actionFn), {
      wrapper: createWrapper(),
    });

    let executePromise: Promise<unknown>;

    act(() => {
      executePromise = result.current.execute();
    });

    // Loading should be true while the action is executing
    expect(result.current.loading).toBe(true);

    await act(async () => {
      resolvePromise!('done');
      await executePromise;
    });

    expect(result.current.loading).toBe(false);
    expect(result.current.data).toBe('done');
  });

  it('should handle errors during execution', async () => {
    const actionError = new Error('Action failed');
    const actionFn = vi.fn().mockRejectedValue(actionError);
    const onError = vi.fn();

    const { result } = renderHook(
      () => use{{SDK_SLUG_PASCAL}}(actionFn, { onError }),
      { wrapper: createWrapper() },
    );

    await act(async () => {
      await result.current.execute();
    });

    expect(result.current.error).toEqual(actionError);
    expect(result.current.success).toBe(false);
    expect(result.current.loading).toBe(false);
    expect(result.current.data).toBeNull();
    expect(onError).toHaveBeenCalledWith(actionError);
  });

  it('should call onSuccess callback', async () => {
    const mockData = { result: 'ok' };
    const actionFn = vi.fn().mockResolvedValue(mockData);
    const onSuccess = vi.fn();

    const { result } = renderHook(
      () => use{{SDK_SLUG_PASCAL}}(actionFn, { onSuccess }),
      { wrapper: createWrapper() },
    );

    await act(async () => {
      await result.current.execute();
    });

    expect(onSuccess).toHaveBeenCalledWith(mockData);
  });

  it('should reset state', async () => {
    const actionFn = vi.fn().mockResolvedValue('data');

    const { result } = renderHook(() => use{{SDK_SLUG_PASCAL}}(actionFn), {
      wrapper: createWrapper(),
    });

    await act(async () => {
      await result.current.execute();
    });

    expect(result.current.data).toBe('data');
    expect(result.current.success).toBe(true);

    act(() => {
      result.current.reset();
    });

    expect(result.current.data).toBeNull();
    expect(result.current.error).toBeNull();
    expect(result.current.loading).toBe(false);
    expect(result.current.success).toBe(false);
  });

  it('should error when client is not ready', async () => {
    const actionFn = vi.fn();
    const onError = vi.fn();

    const { result } = renderHook(
      () => use{{SDK_SLUG_PASCAL}}(actionFn, { onError }),
      { wrapper: createWrapper({ client: null, isReady: false }) },
    );

    await act(async () => {
      await result.current.execute();
    });

    expect(result.current.error).toBeDefined();
    expect(result.current.error?.message).toContain('not ready');
    expect(onError).toHaveBeenCalled();
    expect(actionFn).not.toHaveBeenCalled();
  });

  it('should pass arguments to the action function', async () => {
    const actionFn = vi.fn().mockResolvedValue('result');

    const { result } = renderHook(() => use{{SDK_SLUG_PASCAL}}(actionFn), {
      wrapper: createWrapper(),
    });

    await act(async () => {
      await result.current.execute('arg1', 'arg2');
    });

    expect(actionFn).toHaveBeenCalledWith(
      expect.anything(), // client
      'arg1',
      'arg2',
    );
  });

  it('should handle non-Error exceptions', async () => {
    const actionFn = vi.fn().mockRejectedValue('string error');

    const { result } = renderHook(() => use{{SDK_SLUG_PASCAL}}(actionFn), {
      wrapper: createWrapper(),
    });

    await act(async () => {
      await result.current.execute();
    });

    expect(result.current.error).toBeInstanceOf(Error);
    expect(result.current.error?.message).toBe('An unexpected error occurred');
  });
});
