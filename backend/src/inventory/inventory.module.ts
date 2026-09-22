import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { InventoryProduct } from '../database/entities/inventory-product.entity.js';
import { InventorySale } from '../database/entities/inventory-sale.entity.js';
import { InventoryTreasury } from '../database/entities/inventory-treasury.entity.js';
import { InventoryController } from './inventory.controller.js';
import { InventoryService } from './inventory.service.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      InventoryProduct,
      InventorySale,
      InventoryTreasury,
    ]),
  ],
  controllers: [InventoryController],
  providers: [InventoryService],
  exports: [InventoryService],
})
export class InventoryModule {}
