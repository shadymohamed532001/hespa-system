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
