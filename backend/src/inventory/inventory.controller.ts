import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Request,
} from '@nestjs/common';
import { Roles } from '../common/decorators/roles.decorator.js';
import { UserRole } from '../database/enums.js';
import { CreateInventoryProductDto } from './dto/create-product.dto.js';
import { SellProductDto } from './dto/sell-product.dto.js';
import { StockInDto } from './dto/stock-in.dto.js';
import { InventoryService } from './inventory.service.js';

type UserRequest = { user: { username: string } };

@Controller('inventory')
export class InventoryController {
  constructor(private readonly inventory: InventoryService) {}

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

  @Roles(UserRole.ADMIN)
  @Post('products')
  create(@Body() dto: CreateInventoryProductDto) {
    return this.inventory.createProduct(dto);
  }

  @Roles(UserRole.ADMIN)
  @Post('products/:id/stock-in')
  stockIn(@Param('id') id: string, @Body() dto: StockInDto) {
    return this.inventory.stockIn(id, dto);
  }

  @Post('products/:id/sell')
  sell(
    @Param('id') id: string,
    @Body() dto: SellProductDto,
    @Request() request: UserRequest,
  ) {
    return this.inventory.sell(id, dto, request.user.username);
  }
}
