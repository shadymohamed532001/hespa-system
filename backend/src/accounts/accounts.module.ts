import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { FinancialAccount } from '../database/entities/financial-account.entity.js';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { AccountsController } from './accounts.controller.js';
import { AccountsService } from './accounts.service.js';

@Module({
  imports: [TypeOrmModule.forFeature([FinancialAccount, LedgerEntry])],
  controllers: [AccountsController],
  providers: [AccountsService],
  exports: [AccountsService],
})
export class AccountsModule {}

