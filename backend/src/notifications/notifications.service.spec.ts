import { describe, expect, it } from 'vitest';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { LedgerCategory, NotificationKind } from '../database/enums.js';
import { notificationContent } from './notifications.service.js';

describe('notificationContent', () => {
  it('builds a detailed recharge alert when a machine balance reaches zero', () => {
    const entry = {
      category: LedgerCategory.MACHINE_USAGE,
      amount: 125,
      description: 'عملية شحن من ماكينة رقم 2',
      metadata: {
        machineDepleted: true,
        machineName: 'ماكينة رقم 2',
        loadedBalance: 500,
        usedBalance: 500,
        remainingBalance: 0,
        commissionBalance: 17.5,
        commission: 2.5,
      },
    } as LedgerEntry;

    const content = notificationContent(entry);

    expect(content.kind).toBe(NotificationKind.WITHDRAWAL);
    expect(content.title).toContain('نفاد رصيد الماكينة');
    expect(content.title).toContain('ماكينة رقم 2');
    expect(content.body).toContain('إجمالي المشحون: 500.00 ج.م');
    expect(content.body).toContain('إجمالي المستخدم: 500.00 ج.م');
    expect(content.body).toContain('المتبقي: 0.00 ج.م');
    expect(content.body).toContain('إجمالي العمولات: 17.50 ج.م');
    expect(content.body).toContain('قيمة آخر عملية: 125.00 ج.م');
    expect(content.body).toContain('عمولة آخر عملية: 2.50 ج.م');
    expect(content.body).toContain('يرجى شحن الماكينة');
  });

  it('keeps the standard machine-usage notification above zero', () => {
    const entry = {
      category: LedgerCategory.MACHINE_USAGE,
      amount: 50,
      description: 'عملية شحن عادية',
      metadata: { machineDepleted: false, remainingBalance: 50 },
    } as LedgerEntry;

    expect(notificationContent(entry)).toEqual({
      kind: NotificationKind.WITHDRAWAL,
      title: 'سحب — استخدام ماكينة',
      body: 'عملية شحن عادية',
    });
  });

  it('omits profit figures from employee machine alerts', () => {
    const entry = {
      category: LedgerCategory.MACHINE_USAGE,
      amount: 125,
      description: 'عملية من ماكينة وعمولتها 2.50 ج.م',
      metadata: {
        machineDepleted: true,
        machineName: 'ماكينة رقم 2',
        loadedBalance: 500,
        usedBalance: 500,
        remainingBalance: 0,
        commissionBalance: 17.5,
        commission: 2.5,
      },
    } as LedgerEntry;

    const content = notificationContent(entry, false);

    expect(content.body).not.toContain('عمولة');
    expect(content.body).not.toContain('17.50');
    expect(content.body).not.toContain('2.50');
    expect(content.body).toContain('قيمة آخر عملية: 125.00 ج.م');
  });
});
