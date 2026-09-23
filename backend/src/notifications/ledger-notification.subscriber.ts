import {
  DataSource,
  EntitySubscriberInterface,
  EventSubscriber,
  InsertEvent,
} from 'typeorm';
import { Injectable, OnModuleInit } from '@nestjs/common';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { AppNotification } from '../database/entities/notification.entity.js';
import { notificationContent } from './notifications.service.js';

@Injectable()
@EventSubscriber()
export class LedgerNotificationSubscriber
  implements EntitySubscriberInterface<LedgerEntry>, OnModuleInit
{
  constructor(private readonly dataSource: DataSource) {}

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
    await repo.save(
      repo.create({
        kind: mapped.kind,
        title: mapped.title,
        body: mapped.body,
        amount: entry.amount > 0 ? entry.amount : null,
        ledgerEntryId: entry.id,
        isRead: false,
      }),
    );
  }
}
