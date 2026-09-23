import {
  DataSource,
  EntitySubscriberInterface,
  EventSubscriber,
  InsertEvent,
} from 'typeorm';
import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { AppNotification } from '../database/entities/notification.entity.js';
import { notificationContent } from './notifications.service.js';
import { FcmService } from './fcm.service.js';
import { isProfitLedgerEntry } from '../common/interceptors/profit-visibility.interceptor.js';
import { UserRole } from '../database/enums.js';

@Injectable()
@EventSubscriber()
export class LedgerNotificationSubscriber
  implements EntitySubscriberInterface<LedgerEntry>, OnModuleInit
{
  private readonly logger = new Logger(LedgerNotificationSubscriber.name);

  constructor(
    private readonly dataSource: DataSource,
    private readonly fcm: FcmService,
  ) {}

  onModuleInit() {
    this.dataSource.subscribers.push(this);
  }

  listenTo() {
    return LedgerEntry;
  }

  async afterInsert(event: InsertEvent<LedgerEntry>) {
    const entry = event.entity;
    if (!entry?.id) return;

    const repo = event.manager.getRepository(AppNotification);
    const existing = await repo.findOne({
      where: { ledgerEntryId: entry.id },
    });
    if (existing) return;

    const mapped = notificationContent(entry);
    const saved = await repo.save(
      repo.create({
        kind: mapped.kind,
        title: mapped.title,
        body: mapped.body,
        amount: entry.amount > 0 ? entry.amount : null,
        ledgerEntryId: entry.id,
        isRead: false,
      }),
    );

    try {
      await this.fcm.sendPush(
        {
          title: mapped.title,
          body: mapped.body,
          data: {
            notificationId: saved.id,
            kind: mapped.kind,
            ledgerEntryId: entry.id,
            category: entry.category,
          },
        },
        UserRole.ADMIN,
      );
      if (!isProfitLedgerEntry(entry)) {
        const employeeContent = notificationContent(entry, false);
        await this.fcm.sendPush(
          {
            title: employeeContent.title,
            body: employeeContent.body,
            data: {
              notificationId: saved.id,
              kind: employeeContent.kind,
              ledgerEntryId: entry.id,
              category: entry.category,
            },
          },
          UserRole.EMPLOYEE,
        );
      }
    } catch (error) {
      this.logger.warn(
        `Push notification failed: ${error instanceof Error ? error.message : error}`,
      );
    }
  }
}
