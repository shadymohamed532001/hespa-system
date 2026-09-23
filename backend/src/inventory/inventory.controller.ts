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
import { ReversalDto } from '../common/dto/reversal.dto.js';
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

  @Get('movements')
  movements(@Query('limit') limit?: string) {
    return this.inventory.findMovements(Number(limit) || 100);
  }

  @RequirePermissions(AppPermission.MANAGE_INVENTORY)
  @Idempotent()
  @Post('products')
  create(
    @Body() dto: CreateInventoryProductDto,
    @Request() request: UserRequest,
  ) {
    return this.inventory.createProduct(dto, request.user.username);
  }

  @RequirePermissions(AppPermission.MANAGE_INVENTORY)
  @Idempotent()
  @Post('products/:id/stock-in')
  stockIn(
    @Param('id') id: string,
    @Body() dto: StockInDto,
    @Request() request: UserRequest,
  ) {
    return this.inventory.stockIn(id, dto, request.user.username);
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

  @RequirePermissions(AppPermission.REVERSE_OPERATIONS)
  @Idempotent()
  @Post('sales/:id/reverse')
  reverseSale(
    @Param('id') id: string,
    @Body() dto: ReversalDto,
    @Request() request: UserRequest,
  ) {
    return this.inventory.reverseSale(id, dto, request.user.username);
  }
}
