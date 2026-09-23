import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { LedgerController } from './ledger.controller.js';
import { LedgerService } from './ledger.service.js';
import { FinancialAccount } from '../database/entities/financial-account.entity.js';
import { Machine } from '../database/entities/machine.entity.js';
import { Treasury } from '../database/entities/treasury.entity.js';
import { Wallet } from '../database/entities/wallet.entity.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      LedgerEntry,
      FinancialAccount,
      Wallet,
      Machine,
      Treasury,
    ]),
  ],
  controllers: [LedgerController],
  providers: [LedgerService],
})
export class LedgerModule {}
