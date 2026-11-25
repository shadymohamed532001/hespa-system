import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ShopDebtMovement } from '../database/entities/shop-debt-movement.entity.js';
import { ShopDebtsController } from './shop-debts.controller.js';
import { ShopDebtsService } from './shop-debts.service.js';

@Module({
  imports: [TypeOrmModule.forFeature([ShopDebtMovement])],
  controllers: [ShopDebtsController],
  providers: [ShopDebtsService],
})
export class ShopDebtsModule {}
