import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { AppNotification } from '../database/entities/notification.entity.js';
import { LedgerNotificationSubscriber } from './ledger-notification.subscriber.js';
import { NotificationsController } from './notifications.controller.js';
import { NotificationsService } from './notifications.service.js';

@Module({
  imports: [TypeOrmModule.forFeature([AppNotification, LedgerEntry])],
  controllers: [NotificationsController],
  providers: [NotificationsService, LedgerNotificationSubscriber],
  exports: [NotificationsService],
})
export class NotificationsModule {}
