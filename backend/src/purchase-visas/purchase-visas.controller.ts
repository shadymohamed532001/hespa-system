import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Request,
} from '@nestjs/common';
import { ParseBoolPipe } from '@nestjs/common';
import { Idempotent } from '../common/decorators/idempotent.decorator.js';
import { RequirePermissions } from '../common/decorators/permissions.decorator.js';
import { AppPermission } from '../database/enums.js';
import {
  CreatePurchaseVisaDto,
  WithdrawPurchaseVisaDto,
} from './dto/purchase-visa.dto.js';
import { PurchaseVisasService } from './purchase-visas.service.js';

type UserRequest = { user: { username: string } };

@Controller('purchase-visas')
@RequirePermissions(AppPermission.VIEW_BALANCES)
export class PurchaseVisasController {
  constructor(private readonly visas: PurchaseVisasService) {}

  @Get()
  findAll(
    @Query('includeInactive', new ParseBoolPipe({ optional: true }))
    includeInactive?: boolean,
  ) {
    return this.visas.findAll(includeInactive ?? false);
  }

  @RequirePermissions(AppPermission.MANAGE_ASSETS)
  @Idempotent()
  @Post()
  create(@Body() dto: CreatePurchaseVisaDto, @Request() request: UserRequest) {
    return this.visas.create(dto, request.user.username);
  }

  @RequirePermissions(AppPermission.USE_PURCHASE_VISAS)
  @Idempotent()
  @Post(':id/withdraw')
  withdraw(
    @Param('id') id: string,
    @Body() dto: WithdrawPurchaseVisaDto,
    @Request() request: UserRequest,
  ) {
    return this.visas.withdraw(id, dto, request.user.username);
  }
}
