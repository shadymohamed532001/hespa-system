import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { PurchaseVisa } from '../database/entities/purchase-visa.entity.js';
import { Treasury } from '../database/entities/treasury.entity.js';
import { PurchaseVisasController } from './purchase-visas.controller.js';
import { PurchaseVisasService } from './purchase-visas.service.js';

@Module({
  imports: [TypeOrmModule.forFeature([PurchaseVisa, Treasury, LedgerEntry])],
  controllers: [PurchaseVisasController],
  providers: [PurchaseVisasService],
})
export class PurchaseVisasModule {}
