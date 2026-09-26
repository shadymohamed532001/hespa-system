import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { FawryDailyDrop } from '../database/entities/fawry-daily-drop.entity.js';
import { FinancialAccount } from '../database/entities/financial-account.entity.js';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { AppNotification } from '../database/entities/notification.entity.js';
import { NotificationsModule } from '../notifications/notifications.module.js';
import { AccountsController } from './accounts.controller.js';
import { AccountsService } from './accounts.service.js';
import { FawryDropReminderService } from './fawry-drop-reminder.service.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      FinancialAccount,
      LedgerEntry,
      FawryDailyDrop,
      AppNotification,
    ]),
    NotificationsModule,
  ],
  controllers: [AccountsController],
  providers: [AccountsService, FawryDropReminderService],
  exports: [AccountsService],
})
export class AccountsModule {}
