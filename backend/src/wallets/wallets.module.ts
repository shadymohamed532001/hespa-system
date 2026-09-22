import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { Wallet } from '../database/entities/wallet.entity.js';
import { WalletsController } from './wallets.controller.js';
import { WalletsService } from './wallets.service.js';

@Module({
  imports: [TypeOrmModule.forFeature([Wallet, LedgerEntry])],
  controllers: [WalletsController],
  providers: [WalletsService],
})
export class WalletsModule {}

