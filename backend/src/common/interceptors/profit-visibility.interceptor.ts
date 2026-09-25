import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Observable, map } from 'rxjs';
import { LedgerCategory, UserRole } from '../../database/enums.js';

type AuthenticatedRequest = { user?: { role?: UserRole } };

const PROFIT_KEYS = new Set([
  'commission',
  'commissions',
  'commissionbalance',
  'costprice',
  'grossprofit',
  'netprofit',
  'profit',
  'totalprofit',
  'unitcost',
]);

export function isProfitLedgerEntry(value: unknown): boolean {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false;
  const record = value as Record<string, unknown>;
  if (
    record.category === LedgerCategory.COMMISSION ||
    record.category === LedgerCategory.WALLET_CASH_FEE
  )
    return true;
  if (record.category !== LedgerCategory.REVERSAL) return false;
  const metadata = record.metadata;
  return (
    !!metadata &&
    typeof metadata === 'object' &&
    !Array.isArray(metadata) &&
    [LedgerCategory.COMMISSION, LedgerCategory.WALLET_CASH_FEE].includes(
      (metadata as Record<string, unknown>).originalCategory as LedgerCategory,
    )
  );
}

/** Removes profit amounts embedded in otherwise operational descriptions. */
export function redactProfitText(value: string): string {
  return value
    .replace(
      /[،,]?\s*(?:و)?عمولت(?:ه|ها)\s*[:：]?\s*[-+]?\d+(?:[.,]\d+)?(?:\s*ج\.?\s*م\.?)?/giu,
      '',
    )
    .replace(
      /[،,]?\s*(?:إجمالي\s+العمولات|عمولة\s+آخر\s+عملية)\s*[:：]?\s*[-+]?\d+(?:[.,]\d+)?(?:\s*ج\.?\s*م\.?)?/giu,
      '',
    )
    .replace(
      /[،,]?\s*(?:total\s+commissions|last\s+operation\s+commission)\s*[:：]?\s*(?:EGP\s*)?[-+]?\d+(?:[.,]\d+)?/giu,
      '',
    )
    .replace(
      /[،,]?\s*(?:and\s+)?(?:its\s+)?commission\s*[:：]?\s*(?:EGP\s*)?[-+]?\d+(?:[.,]\d+)?/giu,
      '',
    )
    .replace(/[،,]\s*\./gu, '.')
    .replace(/\s+([،,.])/gu, '$1')
    .replace(/([،,])\s*([،,])/gu, '$1')
    .replace(/\s{2,}/gu, ' ')
    .trim();
}

/**
 * Produces an employee-safe copy without mutating service/entity results.
 * Keeping this at the HTTP boundary also protects newly added screens by default.
 */
export function redactProfitData(value: unknown): unknown {
  if (typeof value === 'string') return redactProfitText(value);
  if (value == null || typeof value !== 'object' || value instanceof Date) {
    return value;
  }
  if (Array.isArray(value)) {
    return value
      .filter((item) => !isProfitLedgerEntry(item))
      .map((item) => redactProfitData(item));
  }
  if (isProfitLedgerEntry(value)) return undefined;

  const output: Record<string, unknown> = {};
  for (const [key, item] of Object.entries(value)) {
    if (PROFIT_KEYS.has(key.toLowerCase())) continue;
    output[key] = redactProfitData(item);
  }
  return output;
}

@Injectable()
export class ProfitVisibilityInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    if (request.user?.role !== UserRole.EMPLOYEE) return next.handle();
    return next.handle().pipe(map((value) => redactProfitData(value)));
  }
}
