import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { AppNotification } from '../database/entities/notification.entity.js';
import { Wallet } from '../database/entities/wallet.entity.js';
import { Treasury } from '../database/entities/treasury.entity.js';
import { NotificationsModule } from '../notifications/notifications.module.js';
import { WalletLimitNoticeService } from './wallet-limit-notice.service.js';
import { WalletsController } from './wallets.controller.js';
import { WalletsService } from './wallets.service.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([Wallet, Treasury, LedgerEntry, AppNotification]),
    NotificationsModule,
  ],
  controllers: [WalletsController],
  providers: [WalletsService, WalletLimitNoticeService],
  exports: [WalletLimitNoticeService],
})
export class WalletsModule {}
