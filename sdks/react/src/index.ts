// Components
export { SdkTplProvider } from './components';

// Hooks
export { useSdkTpl } from './hooks';

// Context
export { useSdkTplContext, getOrCreateContext } from './context';

// Types
export type {
  SdkTplProviderProps,
  SdkTplContextValue,
  UseSdkTplOptions,
  UseSdkTplResult,
} from './types';

// Email domain types
export type {
  EmailProvider,
  EmailData,
  SendEmailOptions,
  SendEmailResponse,
  EmailFormData,
  UseEmailFormOptions,
  UseEmailFormResult,
  BulkEmailResult,
} from './types/email';

// Email form hook
export { useEmailForm } from './hooks/useEmailForm';
