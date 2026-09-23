import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DevicePushToken } from '../database/entities/device-push-token.entity.js';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { AppNotification } from '../database/entities/notification.entity.js';
import { FcmService } from './fcm.service.js';
import { LedgerNotificationSubscriber } from './ledger-notification.subscriber.js';
import { NotificationsController } from './notifications.controller.js';
import { NotificationsService } from './notifications.service.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([AppNotification, LedgerEntry, DevicePushToken]),
  ],
  controllers: [NotificationsController],
  providers: [NotificationsService, LedgerNotificationSubscriber, FcmService],
  exports: [NotificationsService, FcmService],
})
export class NotificationsModule {}
