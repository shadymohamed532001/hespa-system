import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { FcmService } from '../notifications/fcm.service.js';
import { FawryDailyDrop } from '../database/entities/fawry-daily-drop.entity.js';
import { FinancialAccount } from '../database/entities/financial-account.entity.js';
import { AppNotification } from '../database/entities/notification.entity.js';
import { AccountType, NotificationKind, UserRole } from '../database/enums.js';
import {
  FAWRY_DROP_REMINDER_HOUR,
  cairoParts,
  fawryAccountsDueForDrop,
} from './cairo-time.js';

@Injectable()
export class FawryDropReminderService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(FawryDropReminderService.name);
  private timer: ReturnType<typeof setInterval> | null = null;
  private startup: ReturnType<typeof setTimeout> | null = null;

  constructor(
    @InjectRepository(FinancialAccount)
    private readonly accounts: Repository<FinancialAccount>,
    @InjectRepository(FawryDailyDrop)
    private readonly drops: Repository<FawryDailyDrop>,
    @InjectRepository(AppNotification)
    private readonly notifications: Repository<AppNotification>,
    private readonly fcm: FcmService,
    private readonly config: ConfigService,
  ) {}

  onModuleInit() {
    if (this.config.get('NODE_ENV') === 'test') return;
    const tick = () => {
      void this.remindIfDue().catch((error: unknown) => {
        this.logger.warn(
          `Fawry drop reminder failed: ${error instanceof Error ? error.message : error}`,
        );
      });
    };
    this.startup = setTimeout(tick, 15_000);
    this.timer = setInterval(tick, 15 * 60 * 1000);
  }

  onModuleDestroy() {
    if (this.startup) clearTimeout(this.startup);
    if (this.timer) clearInterval(this.timer);
  }

  async remindIfDue(now = new Date()) {
    if (cairoParts(now).hour < FAWRY_DROP_REMINDER_HOUR) return { sent: false };

    const accounts = await this.accounts.find({
      where: { type: AccountType.FAWRY, active: true },
    });
    const date = cairoParts(now).date;
    const drops = await this.drops.find({ where: { businessDate: date } });
    const due = fawryAccountsDueForDrop({
      now,
      accounts,
      recordedAccountIds: drops.map((drop) => drop.accountId),
    });
    if (!due.remind) return { sent: false };

    const dedupeKey = `fawry-drop-reminder:${due.date}`;
    const existing = await this.notifications.findOne({ where: { dedupeKey } });
    if (existing) return { sent: false };

    const names = due.missing.map((account) => account.name).join('، ');
    const title = 'نزلة فوري لسه متتسجلش';
    const body = `سجّل نزل كام النهاردة لحسابات فوري: ${names}`.slice(0, 500);

    let saved: AppNotification;
    try {
      saved = await this.notifications.save(
        this.notifications.create({
          kind: NotificationKind.INFO,
          title,
          body,
          amount: null,
          ledgerEntryId: null,
          isRead: false,
          adminOnly: true,
          dedupeKey,
        }),
      );
    } catch (error) {
      if (isUniqueViolation(error)) return { sent: false };
      throw error;
    }

    try {
      await this.fcm.sendPush(
        {
          title,
          body,
          data: { notificationId: saved.id, kind: saved.kind },
        },
        UserRole.ADMIN,
      );
    } catch (error) {
      this.logger.warn(
        `Fawry drop push failed: ${error instanceof Error ? error.message : error}`,
      );
    }
    return { sent: true, id: saved.id };
  }
}

function isUniqueViolation(error: unknown) {
  if (!error || typeof error !== 'object') return false;
  const record = error as { code?: string; driverError?: { code?: string } };
  return record.code === '23505' || record.driverError?.code === '23505';
}
