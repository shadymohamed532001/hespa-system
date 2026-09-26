const arabicZero = '٠'.charCodeAt(0);
const persianZero = '۰'.charCodeAt(0);

export function normalizeDigits(value: string): string {
  let result = '';
  for (const char of value) {
    const code = char.charCodeAt(0);
    if (code >= arabicZero && code <= arabicZero + 9) {
      result += String(code - arabicZero);
    } else if (code >= persianZero && code <= persianZero + 9) {
      result += String(code - persianZero);
    } else if (char === '٫') {
      result += '.';
    } else if (char === '٬') {
      continue;
    } else {
      result += char;
    }
  }
  return result;
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return (
    typeof value === 'object' &&
    value !== null &&
    !Array.isArray(value) &&
    Object.getPrototypeOf(value) === Object.prototype
  );
}

/// Amount fields may arrive as Arabic digits. Pure numeric strings become
/// numbers; any other text keeps its letters and only its digits change.
export function normalizeRequestNumbers(value: unknown): unknown {
  if (typeof value === 'string') {
    if (!/[٠-٩۰-۹٫٬]/.test(value)) return value;
    const normalized = normalizeDigits(value).trim();
    if (/^-?(?:0|[1-9]\d*)(\.\d+)?$/.test(normalized)) {
      return Number(normalized);
    }
    return normalizeDigits(value);
  }
  if (Array.isArray(value)) return value.map(normalizeRequestNumbers);
  if (isPlainObject(value)) {
    return Object.fromEntries(
      Object.entries(value).map(([key, item]) => [
        key,
        normalizeRequestNumbers(item),
      ]),
    );
  }
  return value;
}
