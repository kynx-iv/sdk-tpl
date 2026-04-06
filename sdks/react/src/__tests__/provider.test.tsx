import React from 'react';
import { render, screen, waitFor, act } from '@testing-library/react';
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { {{SDK_SLUG_PASCAL}}Provider } from '../components/SdkTplProvider';
import { use{{SDK_SLUG_PASCAL}}Context } from '../context';

// Mock the SDK client
vi.mock('{{ORG_NAME}}/{{SDK_SLUG}}', () => {
  return {
    {{SDK_SLUG_PASCAL}}Client: vi.fn().mockImplementation((config: unknown) => ({
      config,
      close: vi.fn(),
    })),
  };
});

const CONTEXT_KEY = '__{{SDK_SLUG_UPPER}}_REACT_CONTEXT__';

/**
 * Helper component that displays context state for testing.
 */
function ContextConsumer() {
  const { client, isReady, isLoading, error } = use{{SDK_SLUG_PASCAL}}Context();

  return (
    <div>
      <span data-testid="is-ready">{String(isReady)}</span>
      <span data-testid="is-loading">{String(isLoading)}</span>
      <span data-testid="has-client">{String(client !== null)}</span>
      <span data-testid="error">{error?.message ?? 'none'}</span>
    </div>
  );
}

describe('{{SDK_SLUG_PASCAL}}Provider', () => {
  const defaultConfig = {
    apiKey: 'test-api-key',
  };

  afterEach(() => {
    vi.restoreAllMocks();
    const globalRegistry = globalThis as unknown as Record<string, unknown>;
    delete globalRegistry[CONTEXT_KEY];
  });

  it('should render children', () => {
    render(
      <{{SDK_SLUG_PASCAL}}Provider config={defaultConfig}>
        <div data-testid="child">Hello</div>
      </{{SDK_SLUG_PASCAL}}Provider>,
    );

    expect(screen.getByTestId('child')).toHaveTextContent('Hello');
  });

  it('should initialize the client and become ready', async () => {
    render(
      <{{SDK_SLUG_PASCAL}}Provider config={defaultConfig}>
        <ContextConsumer />
      </{{SDK_SLUG_PASCAL}}Provider>,
    );

    await waitFor(() => {
      expect(screen.getByTestId('is-ready')).toHaveTextContent('true');
    });

    expect(screen.getByTestId('has-client')).toHaveTextContent('true');
    expect(screen.getByTestId('is-loading')).toHaveTextContent('false');
    expect(screen.getByTestId('error')).toHaveTextContent('none');
  });

  it('should call onReady when client initializes successfully', async () => {
    const onReady = vi.fn();

    render(
      <{{SDK_SLUG_PASCAL}}Provider config={defaultConfig} onReady={onReady}>
        <ContextConsumer />
      </{{SDK_SLUG_PASCAL}}Provider>,
    );

    await waitFor(() => {
      expect(onReady).toHaveBeenCalledTimes(1);
    });
  });

  it('should handle initialization errors', async () => {
    const { {{SDK_SLUG_PASCAL}}Client } = await import('{{ORG_NAME}}/{{SDK_SLUG}}');
    const MockClient = {{SDK_SLUG_PASCAL}}Client as unknown as ReturnType<typeof vi.fn>;
    MockClient.mockImplementationOnce(() => {
      throw new Error('Init failed');
    });

    const onError = vi.fn();

    render(
      <{{SDK_SLUG_PASCAL}}Provider config={defaultConfig} onError={onError}>
        <ContextConsumer />
      </{{SDK_SLUG_PASCAL}}Provider>,
    );

    await waitFor(() => {
      expect(screen.getByTestId('error')).toHaveTextContent('Init failed');
    });

    expect(screen.getByTestId('is-ready')).toHaveTextContent('false');
    expect(screen.getByTestId('is-loading')).toHaveTextContent('false');
    expect(onError).toHaveBeenCalledWith(expect.any(Error));
  });

  it('should call client.close on unmount', async () => {
    const closeFn = vi.fn();
    const { {{SDK_SLUG_PASCAL}}Client } = await import('{{ORG_NAME}}/{{SDK_SLUG}}');
    const MockClient = {{SDK_SLUG_PASCAL}}Client as unknown as ReturnType<typeof vi.fn>;
    MockClient.mockImplementation(() => ({
      close: closeFn,
    }));

    const { unmount } = render(
      <{{SDK_SLUG_PASCAL}}Provider config={defaultConfig}>
        <ContextConsumer />
      </{{SDK_SLUG_PASCAL}}Provider>,
    );

    await waitFor(() => {
      expect(screen.getByTestId('is-ready')).toHaveTextContent('true');
    });

    unmount();

    expect(closeFn).toHaveBeenCalled();
  });

  it('should render multiple children', () => {
    render(
      <{{SDK_SLUG_PASCAL}}Provider config={defaultConfig}>
        <div data-testid="child-1">First</div>
        <div data-testid="child-2">Second</div>
      </{{SDK_SLUG_PASCAL}}Provider>,
    );

    expect(screen.getByTestId('child-1')).toBeInTheDocument();
    expect(screen.getByTestId('child-2')).toBeInTheDocument();
  });
});
