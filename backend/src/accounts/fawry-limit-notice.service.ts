import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { FinancialAccount } from '../database/entities/financial-account.entity.js';
import { AppNotification } from '../database/entities/notification.entity.js';
import { NotificationKind, UserRole } from '../database/enums.js';
import { FcmService } from '../notifications/fcm.service.js';
import { FAWRY_DAILY_WITHDRAW_LIMIT } from './fawry-limit.js';

export type FawryLimitNotice = { account: FinancialAccount; percent: number };

const egp = (n: number) =>
  n.toLocaleString('en-US', { maximumFractionDigits: 2 });

export function fawryLimitNoticeText(
  name: string,
  withdrawn: number,
  percent: number,
) {
  const limit = egp(FAWRY_DAILY_WITHDRAW_LIMIT);
  if (percent >= 100) {
    return {
      title: 'حساب فوري خلّص حد السحب اليومي',
      body: `${name} وصل ${limit} ج.م النهارده. مش هيقبل سحب تاني لحد بكرة، استخدم حساب تاني.`,
    };
  }
  const remaining = Math.max(0, FAWRY_DAILY_WITHDRAW_LIMIT - withdrawn);
  return {
    title: 'حساب فوري قرب يخلص حد السحب',
    body: `${name} اتسحب منه ${egp(withdrawn)} ج.م من ${limit} النهارده (${percent}%). المتبقي ${egp(remaining)} ج.م.`,
  };
}

/** Admin-only alerts when a Fawry account nears its daily withdrawal limit. */
@Injectable()
export class FawryLimitNoticeService {
  private readonly logger = new Logger(FawryLimitNoticeService.name);

  constructor(
    @InjectRepository(AppNotification)
    private readonly notifications: Repository<AppNotification>,
    private readonly fcm: FcmService,
  ) {}

  async notify({ account, percent }: FawryLimitNotice) {
    const day = account.withdrawCounterDay ?? 'unknown';
    const dedupeKey = `fawry-withdraw:${account.id}:${day}:${percent}`;
    const withdrawn = Number(account.dailyWithdrawn);
    const { title, body } = fawryLimitNoticeText(
      account.name,
      withdrawn,
      percent,
    );

    let saved: AppNotification;
    try {
      const existing = await this.notifications.findOne({
        where: { dedupeKey },
      });
      if (existing) return;
      saved = await this.notifications.save(
        this.notifications.create({
          kind: NotificationKind.INFO,
          title,
          body,
          amount: withdrawn,
          ledgerEntryId: null,
          isRead: false,
          adminOnly: true,
          dedupeKey,
        }),
      );
    } catch (error) {
      if (isUniqueViolation(error)) return;
      this.logger.warn(
        `Fawry limit notice failed: ${error instanceof Error ? error.message : 'unknown error'}`,
      );
      return;
    }

    try {
      await this.fcm.sendPush(
        { title, body, data: { notificationId: saved.id, kind: saved.kind } },
        UserRole.ADMIN,
      );
    } catch (error) {
      this.logger.warn(
        `Fawry limit push failed: ${error instanceof Error ? error.message : 'unknown error'}`,
      );
    }
  }
}

function isUniqueViolation(error: unknown) {
  if (!error || typeof error !== 'object') return false;
  const record = error as { code?: string; driverError?: { code?: string } };
  return record.code === '23505' || record.driverError?.code === '23505';
}
