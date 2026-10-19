import { CorrectionEntriesSubscriber } from './correction-entries.subscriber.js';
import { InventoryModule } from '../inventory/inventory.module.js';
import { CollectionsModule } from '../collections/collections.module.js';
import { PurchaseVisasModule } from '../purchase-visas/purchase-visas.module.js';
import { TreasuryModule } from '../treasury/treasury.module.js';
import { MachinesModule } from '../machines/machines.module.js';
import { WalletsModule } from '../wallets/wallets.module.js';
import { AccountsModule } from '../accounts/accounts.module.js';
import { OperationCorrectionsService } from './operation-corrections.service.js';
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
    InventoryModule,
    CollectionsModule,
    PurchaseVisasModule,
    TreasuryModule,
    MachinesModule,
    WalletsModule,
    AccountsModule,
    TypeOrmModule.forFeature([
      LedgerEntry,
      FinancialAccount,
      Wallet,
      Machine,
      Treasury,
    ]),
  ],
  controllers: [LedgerController],
  providers: [
    LedgerService,
    OperationCorrectionsService,
    CorrectionEntriesSubscriber,
  ],
})
export class LedgerModule {}
