import { AsyncLocalStorage } from 'node:async_hooks';

export type AppLocale = 'ar' | 'en';

const storage = new AsyncLocalStorage<AppLocale>();

export function resolveLocale(raw?: string | string[] | null): AppLocale {
  const value = Array.isArray(raw) ? raw[0] : raw;
  if (!value) return 'ar';
  const normalized = value.toLowerCase();
  if (normalized.startsWith('en')) return 'en';
  return 'ar';
}

export function runWithLocale<T>(locale: AppLocale, fn: () => T): T {
  return storage.run(locale, fn);
}

export function getLocale(): AppLocale {
  return storage.getStore() ?? 'ar';
}

/** Pick Arabic or English copy for the active request locale. */
export function msg(parts: { ar: string; en: string }): string {
  return getLocale() === 'en' ? parts.en : parts.ar;
}
