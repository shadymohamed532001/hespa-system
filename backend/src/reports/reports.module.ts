import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import {
  Collection,
  FinancialAccount,
  InventoryProduct,
  InventorySale,
  InventoryTreasury,
  LedgerEntry,
  Machine,
  Treasury,
  Wallet,
} from '../database/entities/index.js';
import { ReportsController } from './reports.controller.js';
import { ReportsService } from './reports.service.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      LedgerEntry,
      InventorySale,
      InventoryProduct,
      InventoryTreasury,
      Collection,
      FinancialAccount,
      Wallet,
      Machine,
      Treasury,
    ]),
  ],
  controllers: [ReportsController],
  providers: [ReportsService],
})
export class ReportsModule {}
