import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AppNotification } from '../database/entities/notification.entity.js';
import { Wallet } from '../database/entities/wallet.entity.js';
import { NotificationKind } from '../database/enums.js';
import { FcmService } from '../notifications/fcm.service.js';

@Injectable()
export class WalletLimitNoticeService {
  private readonly logger = new Logger(WalletLimitNoticeService.name);

  constructor(
    @InjectRepository(AppNotification)
    private readonly notifications: Repository<AppNotification>,
    private readonly fcm: FcmService,
  ) {}

  async notifyDailyThreshold(wallet: Wallet) {
    const day = wallet.counterDay ?? 'unknown';
    const dedupeKey = `wallet-daily-50k:${wallet.id}:${day}`;
    try {
      const existing = await this.notifications.findOne({ where: { dedupeKey } });
      if (existing) return;
    } catch (error) {
      this.logger.warn(
        `Wallet daily notice lookup failed: ${error instanceof Error ? error.message : 'unknown error'}`,
      );
      return;
    }

    const amount = '50,000';
    const title = 'غيّر المحفظة';
    const owner = wallet.ownerName?.trim() ? ` باسم ${wallet.ownerName.trim()}` : '';
    const body = `${wallet.name}${owner} وصلت ${amount} ج.م النهاردة. استخدم محفظة تانية.`;

    let saved: AppNotification;
    try {
      saved = await this.notifications.save(
        this.notifications.create({
          kind: NotificationKind.INFO,
          title,
          body,
          amount: Number(wallet.dailyTopUp),
          ledgerEntryId: null,
          isRead: false,
          adminOnly: false,
          dedupeKey,
        }),
      );
    } catch (error) {
      if (isUniqueViolation(error)) return;
      this.logger.warn(
        `Wallet daily notice failed: ${error instanceof Error ? error.message : 'unknown error'}`,
      );
      return;
    }

    try {
      await this.fcm.sendPush({
        title,
        body,
        data: { notificationId: saved.id, kind: saved.kind },
      });
    } catch (error) {
      this.logger.warn(
        `Wallet daily push failed: ${error instanceof Error ? error.message : 'unknown error'}`,
      );
    }
  }
}

function isUniqueViolation(error: unknown) {
  if (!error || typeof error !== 'object') return false;
  const record = error as { code?: string; driverError?: { code?: string } };
  return record.code === '23505' || record.driverError?.code === '23505';
}
