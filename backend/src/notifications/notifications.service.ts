import { Injectable, NotFoundException, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { AppNotification } from '../database/entities/notification.entity.js';
import { LedgerCategory, NotificationKind } from '../database/enums.js';
import { msg } from '../common/i18n/locale-context.js';
import {
  isProfitLedgerEntry,
  redactProfitData,
} from '../common/interceptors/profit-visibility.interceptor.js';

@Injectable()
export class NotificationsService implements OnModuleInit {
  constructor(
    @InjectRepository(AppNotification)
    private readonly notifications: Repository<AppNotification>,
    @InjectRepository(LedgerEntry)
    private readonly ledger: Repository<LedgerEntry>,
  ) {}

  async onModuleInit() {
    if (await this.notifications.count()) return;
    const entries = await this.ledger.find({
      order: { createdAt: 'ASC' },
      take: 30,
    });
    for (const entry of entries) {
      await this.notifications.save(this.buildFromLedger(entry));
    }
  }

  async findAll(limit = 40, includeProfits = true) {
    const take = Math.min(Math.max(limit, 1), 100);
    const rows = await this.notifications.find({
      where: includeProfits ? {} : { adminOnly: false },
      order: { createdAt: 'DESC' },
      take: includeProfits ? take : 100,
    });
    if (includeProfits) return rows;
    const profitIds = await this.profitNotificationIds(rows);
    return rows
      .filter((row) => !profitIds.has(row.id))
      .slice(0, take)
      .map((row) => redactProfitData(row) as AppNotification);
  }

  async unreadCount(includeProfits = true) {
    if (includeProfits) {
      const count = await this.notifications.count({
        where: { isRead: false },
      });
      return { count };
    }
    const rows = await this.notifications.find({
      where: { isRead: false, adminOnly: false },
    });
    const profitIds = await this.profitNotificationIds(rows);
    return { count: rows.filter((row) => !profitIds.has(row.id)).length };
  }

  private async profitNotificationIds(rows: AppNotification[]) {
    const ledgerIds = rows
      .map((row) => row.ledgerEntryId)
      .filter((id): id is string => !!id);
    if (!ledgerIds.length) return new Set<string>();
    const entries = await this.ledger.find({ where: { id: In(ledgerIds) } });
    const profitLedgerIds = new Set(
      entries.filter(isProfitLedgerEntry).map((entry) => entry.id),
    );
    return new Set(
      rows
        .filter(
          (row) =>
            !!row.ledgerEntryId && profitLedgerIds.has(row.ledgerEntryId),
        )
        .map((row) => row.id),
    );
  }

  async markRead(id: string, includeProfits = true) {
    const notification = await this.notifications.findOne({ where: { id } });
    if (!notification)
      throw new NotFoundException(
        msg({ ar: 'الإشعار غير موجود', en: 'Notification not found' }),
      );
    if (!includeProfits && notification.adminOnly) {
      throw new NotFoundException(
        msg({ ar: 'الإشعار غير موجود', en: 'Notification not found' }),
      );
    }
    if (!includeProfits && notification.ledgerEntryId) {
      const entry = await this.ledger.findOne({
        where: { id: notification.ledgerEntryId },
      });
      if (entry && isProfitLedgerEntry(entry)) {
        throw new NotFoundException(
          msg({ ar: 'الإشعار غير موجود', en: 'Notification not found' }),
        );
      }
    }
    notification.isRead = true;
    return this.notifications.save(notification);
  }

  async markAllRead(includeProfits = true) {
    const query = this.notifications
      .createQueryBuilder()
      .update(AppNotification)
      .set({ isRead: true })
      .where('is_read = false');
    if (!includeProfits) {
      const unread = await this.notifications.find({
        where: { isRead: false, adminOnly: false },
      });
      const profitIds = await this.profitNotificationIds(unread);
      const visibleIds = unread
        .filter((row) => !profitIds.has(row.id))
        .map((row) => row.id);
      if (!visibleIds.length) return { ok: true };
      query.andWhere('id IN (:...visibleIds)', { visibleIds });
    }
    await query.execute();
    return { ok: true };
  }

  buildFromLedger(entry: LedgerEntry): AppNotification {
    const mapped = notificationContent(entry);
    return this.notifications.create({
      kind: mapped.kind,
      title: mapped.title,
      body: mapped.body,
      amount: entry.amount > 0 ? entry.amount : null,
      ledgerEntryId: entry.id,
      isRead: false,
      createdAt: entry.createdAt,
    });
  }
}

export function notificationContent(
  entry: LedgerEntry,
  includeProfits = true,
): {
  kind: NotificationKind;
  title: string;
  body: string;
} {
  const metadata = entry.metadata ?? {};
  if (
    entry.category === LedgerCategory.MACHINE_USAGE &&
    metadata['machineDepleted'] === true
  ) {
    const value = (key: string) => Number(metadata[key] ?? 0).toFixed(2);
    const rawMachineName = metadata['machineName'];
    const machineName =
      typeof rawMachineName === 'string' && rawMachineName.trim()
        ? rawMachineName
        : msg({ ar: 'غير معروفة', en: 'Unknown' });
    return {
      kind: NotificationKind.WITHDRAWAL,
      title: msg({
        ar: `نفاد رصيد الماكينة — ${machineName}`,
        en: `Machine balance depleted — ${machineName}`,
      }),
      body: msg({
        ar:
          `نفد رصيد الماكينة «${machineName}». ` +
          `إجمالي المشحون: ${value('loadedBalance')} ج.م، ` +
          `إجمالي المستخدم: ${value('usedBalance')} ج.م، ` +
          `المتبقي: ${value('remainingBalance')} ج.م، ` +
          (includeProfits
            ? `إجمالي العمولات: ${value('commissionBalance')} ج.م، `
            : '') +
          `قيمة آخر عملية: ${Number(entry.amount).toFixed(2)} ج.م، ` +
          (includeProfits
            ? `عمولة آخر عملية: ${value('commission')} ج.م. `
            : '') +
          `يرجى شحن الماكينة.`,
        en:
          `Machine «${machineName}» balance is depleted. ` +
          `Total loaded: EGP ${value('loadedBalance')}, ` +
          `total used: EGP ${value('usedBalance')}, ` +
          `remaining: EGP ${value('remainingBalance')}, ` +
          (includeProfits
            ? `total commissions: EGP ${value('commissionBalance')}, `
            : '') +
          `last operation amount: EGP ${Number(entry.amount).toFixed(2)}, ` +
          (includeProfits
            ? `last operation commission: EGP ${value('commission')}. `
            : '') +
          `Please top up the machine.`,
      }),
    };
  }

  const mapped = mapLedgerCategory(entry.category);
  return {
    ...mapped,
    body: includeProfits
      ? entry.description
      : (redactProfitData(entry.description) as string),
  };
}

export function mapLedgerCategory(category: LedgerCategory): {
  kind: NotificationKind;
  title: string;
} {
  switch (category) {
    case LedgerCategory.TOP_UP:
      return {
        kind: NotificationKind.DEPOSIT,
        title: msg({ ar: 'إيداع — شحن رصيد', en: 'Deposit — balance top-up' }),
      };
    case LedgerCategory.CASH_RECEIPT:
      return {
        kind: NotificationKind.DEPOSIT,
        title: msg({
          ar: 'إيداع — استلام من مندوب',
          en: 'Deposit — agent collection',
        }),
      };
    case LedgerCategory.WALLET_CASH_FEE:
      return {
        kind: NotificationKind.DEPOSIT,
        title: msg({ ar: 'دخول عمولة المحفظة للخزنة', en: 'Wallet fee added to treasury' }),
      };
    case LedgerCategory.COMMISSION:
      return {
        kind: NotificationKind.DEPOSIT,
        title: msg({ ar: 'إيداع — عمولة', en: 'Deposit — commission' }),
      };
    case LedgerCategory.OPENING_BALANCE:
      return {
        kind: NotificationKind.DEPOSIT,
        title: msg({
          ar: 'إيداع — رصيد افتتاحي',
          en: 'Deposit — opening balance',
        }),
      };
    case LedgerCategory.MACHINE_USAGE:
      return {
        kind: NotificationKind.WITHDRAWAL,
        title: msg({
          ar: 'سحب — استخدام ماكينة',
          en: 'Withdrawal — machine usage',
        }),
      };
    case LedgerCategory.WALLET_USAGE:
      return {
        kind: NotificationKind.WITHDRAWAL,
        title: msg({
          ar: 'سحب — استخدام محفظة',
          en: 'Withdrawal — wallet usage',
        }),
      };
    case LedgerCategory.COMPANY_EXECUTION:
      return {
        kind: NotificationKind.WITHDRAWAL,
        title: msg({
          ar: 'سحب — تنفيذ توريد',
          en: 'Withdrawal — company settlement',
        }),
      };
    case LedgerCategory.REVERSAL:
      return {
        kind: NotificationKind.WITHDRAWAL,
        title: msg({
          ar: 'سحب — عكس عملية',
          en: 'Withdrawal — operation reversal',
        }),
      };
    case LedgerCategory.INTERNAL_TRANSFER:
      return {
        kind: NotificationKind.TRANSFER,
        title: msg({ ar: 'تحويل داخلي', en: 'Internal transfer' }),
      };
    case LedgerCategory.DAILY_ROLLOVER:
      return {
        kind: NotificationKind.INFO,
        title: msg({ ar: 'ترحيل يومي', en: 'Daily rollover' }),
      };
    default:
      return {
        kind: NotificationKind.INFO,
        title: msg({ ar: 'حركة جديدة', en: 'New movement' }),
      };
  }
}
