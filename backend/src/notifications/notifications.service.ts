import { Injectable, NotFoundException, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { AppNotification } from '../database/entities/notification.entity.js';
import { LedgerCategory, NotificationKind } from '../database/enums.js';

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

  findAll(limit = 40) {
    const take = Math.min(Math.max(limit, 1), 100);
    return this.notifications.find({
      order: { createdAt: 'DESC' },
      take,
    });
  }

  async unreadCount() {
    const count = await this.notifications.count({ where: { isRead: false } });
    return { count };
  }

  async markRead(id: string) {
    const notification = await this.notifications.findOne({ where: { id } });
    if (!notification) throw new NotFoundException('الإشعار غير موجود');
    notification.isRead = true;
    return this.notifications.save(notification);
  }

  async markAllRead() {
    await this.notifications
      .createQueryBuilder()
      .update(AppNotification)
      .set({ isRead: true })
      .where('is_read = false')
      .execute();
    return { ok: true };
  }

  buildFromLedger(entry: LedgerEntry): AppNotification {
    const mapped = mapLedgerCategory(entry.category);
    return this.notifications.create({
      kind: mapped.kind,
      title: mapped.title,
      body: entry.description,
      amount: entry.amount > 0 ? entry.amount : null,
      ledgerEntryId: entry.id,
      isRead: false,
      createdAt: entry.createdAt,
    });
  }
}

export function mapLedgerCategory(category: LedgerCategory): {
  kind: NotificationKind;
  title: string;
} {
  switch (category) {
    case LedgerCategory.TOP_UP:
      return { kind: NotificationKind.DEPOSIT, title: 'إيداع — شحن رصيد' };
    case LedgerCategory.CASH_RECEIPT:
      return { kind: NotificationKind.DEPOSIT, title: 'إيداع — استلام من مندوب' };
    case LedgerCategory.COMMISSION:
      return { kind: NotificationKind.DEPOSIT, title: 'إيداع — عمولة' };
    case LedgerCategory.OPENING_BALANCE:
      return { kind: NotificationKind.DEPOSIT, title: 'إيداع — رصيد افتتاحي' };
    case LedgerCategory.MACHINE_USAGE:
      return { kind: NotificationKind.WITHDRAWAL, title: 'سحب — استخدام ماكينة' };
    case LedgerCategory.COMPANY_EXECUTION:
      return { kind: NotificationKind.WITHDRAWAL, title: 'سحب — تنفيذ توريد' };
    case LedgerCategory.REVERSAL:
      return { kind: NotificationKind.WITHDRAWAL, title: 'سحب — عكس عملية' };
    case LedgerCategory.INTERNAL_TRANSFER:
      return { kind: NotificationKind.TRANSFER, title: 'تحويل داخلي' };
    case LedgerCategory.DAILY_ROLLOVER:
      return { kind: NotificationKind.INFO, title: 'ترحيل يومي' };
    default:
      return { kind: NotificationKind.INFO, title: 'حركة جديدة' };
  }
}
