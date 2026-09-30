import { AppPermission, UserRole } from '../database/enums.js';

export type PurchaseVisaCard =
  | { ok: true; cardNumber: string; expiresOn: string }
  | { ok: false; error: 'card' | 'expiry' | 'expired' };

/** 16-digit card number with a valid Luhn check, and an MM/YY expiry. */
export function parsePurchaseVisaCard(
  cardNumber: string,
  expiry: string,
  now = new Date(),
): PurchaseVisaCard {
  const digits = cardNumber.replace(/\D/g, '');
  if (!/^\d{16}$/.test(digits) || !luhn(digits)) {
    return { ok: false, error: 'card' };
  }

  const match = /^(\d{2})\/(\d{2})$/.exec(expiry.trim());
  if (!match) return { ok: false, error: 'expiry' };
  const month = Number(match[1]);
  const year = 2000 + Number(match[2]);
  if (month < 1 || month > 12) return { ok: false, error: 'expiry' };

  const current = now.getFullYear() * 12 + now.getMonth();
  const expires = year * 12 + (month - 1);
  if (expires < current) return { ok: false, error: 'expired' };

  const lastDay = new Date(Date.UTC(year, month, 0)).getUTCDate();
  const monthText = String(month).padStart(2, '0');
  const dayText = String(lastDay).padStart(2, '0');
  return {
    ok: true,
    cardNumber: digits,
    expiresOn: `${year}-${monthText}-${dayText}`,
  };
}

export function maskCardNumber(cardNumber: string) {
  const digits = cardNumber.replace(/\D/g, '');
  if (digits.length <= 4) return digits;
  return `${'*'.repeat(digits.length - 4)}${digits.slice(-4)}`;
}

export function viewerCanSeePurchaseVisaNumber(
  role: UserRole | string | undefined,
  permissions: readonly string[] | null | undefined,
) {
  if (role === UserRole.ADMIN) return true;
  const owned = new Set(permissions ?? []);
  return (
    owned.has(AppPermission.MANAGE_ASSETS) ||
    owned.has(AppPermission.USE_PURCHASE_VISAS)
  );
}

/** Hides full card numbers from viewers who only follow balances. */
export function redactCardNumbers<T>(value: T, reveal: boolean): T {
  if (reveal || value == null || typeof value !== 'object') return value;
  if (value instanceof Date) return value;
  if (Array.isArray(value)) {
    return value.map((item) => redactCardNumbers(item, reveal)) as T;
  }

  const source = value as Record<string, unknown>;
  let changed = false;
  const next: Record<string, unknown> = {};
  for (const [key, item] of Object.entries(source)) {
    if (key === 'cardNumber' && typeof item === 'string') {
      next[key] = maskCardNumber(item);
      changed = true;
      continue;
    }
    if (
      item &&
      typeof item === 'object' &&
      (key === 'purchaseVisa' || key === 'visa' || Array.isArray(item))
    ) {
      const redacted = redactCardNumbers(item, reveal);
      next[key] = redacted;
      if (redacted !== item) changed = true;
      continue;
    }
    next[key] = item;
  }
  return (changed ? next : value) as T;
}

function luhn(digits: string) {
  let sum = 0;
  let doubleDigit = false;
  for (let index = digits.length - 1; index >= 0; index -= 1) {
    let value = digits.charCodeAt(index) - 48;
    if (doubleDigit) {
      value *= 2;
      if (value > 9) value -= 9;
    }
    sum += value;
    doubleDigit = !doubleDigit;
  }
  return sum % 10 === 0;
}
