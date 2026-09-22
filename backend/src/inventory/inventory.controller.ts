import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Request,
} from '@nestjs/common';
import { RequirePermissions } from '../common/decorators/permissions.decorator.js';
import { Idempotent } from '../common/decorators/idempotent.decorator.js';
import { AppPermission } from '../database/enums.js';
import { UsersService } from '../users/users.service.js';
import { CreateInventoryProductDto } from './dto/create-product.dto.js';
import { SellProductDto } from './dto/sell-product.dto.js';
import { StockInDto } from './dto/stock-in.dto.js';
import { InventoryService } from './inventory.service.js';

type UserRequest = { user: { userId: string; username: string } };

@Controller('inventory')
@RequirePermissions(AppPermission.VIEW_BALANCES)
export class InventoryController {
  constructor(
    private readonly inventory: InventoryService,
    private readonly users: UsersService,
  ) {}

  @Get('products')
  products() {
    return this.inventory.findProducts();
  }

  @Get('sales')
  sales(@Query('limit') limit?: string) {
    return this.inventory.findSales(Number(limit) || 50);
  }

  @Get('treasury/summary')
  treasurySummary() {
    return this.inventory.treasurySummary();
  }

  @RequirePermissions(AppPermission.MANAGE_INVENTORY)
  @Idempotent()
  @Post('products')
  create(@Body() dto: CreateInventoryProductDto) {
    return this.inventory.createProduct(dto);
  }

  @RequirePermissions(AppPermission.MANAGE_INVENTORY)
  @Idempotent()
  @Post('products/:id/stock-in')
  stockIn(@Param('id') id: string, @Body() dto: StockInDto) {
    return this.inventory.stockIn(id, dto);
  }

  @RequirePermissions(AppPermission.SELL_INVENTORY)
  @Idempotent()
  @Post('products/:id/sell')
  async sell(
    @Param('id') id: string,
    @Body() dto: SellProductDto,
    @Request() request: UserRequest,
  ) {
    const total = Number(dto.quantity) * Number(dto.unitPrice);
    await this.users.assertAmountLimit(
      request.user.userId,
      'maxSaleAmount',
      total,
    );
    return this.inventory.sell(id, dto, request.user.username);
  }
}
