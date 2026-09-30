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
import { UsersService } from '../users/users.service.js';
import {
  CreatePurchaseVisaDto,
  WithdrawPurchaseVisaDto,
} from './dto/purchase-visa.dto.js';
import {
  viewerCanSeePurchaseVisaNumber,
  redactCardNumbers,
} from './purchase-visa-card.js';
import { PurchaseVisasService } from './purchase-visas.service.js';

type UserRequest = { user: { userId: string; username: string } };

@Controller('purchase-visas')
@RequirePermissions(AppPermission.VIEW_BALANCES)
export class PurchaseVisasController {
  constructor(
    private readonly visas: PurchaseVisasService,
    private readonly users: UsersService,
  ) {}

  @Get()
  async findAll(
    @Query('includeInactive', new ParseBoolPipe({ optional: true }))
    includeInactive: boolean | undefined,
    @Request() request: UserRequest,
  ) {
    const rows = await this.visas.findAll(includeInactive ?? false);
    return redactCardNumbers(rows, await this.revealCards(request.user.userId));
  }

  @RequirePermissions(AppPermission.MANAGE_ASSETS)
  @Idempotent()
  @Post()
  async create(
    @Body() dto: CreatePurchaseVisaDto,
    @Request() request: UserRequest,
  ) {
    const visa = await this.visas.create(dto, request.user.username);
    return redactCardNumbers(visa, await this.revealCards(request.user.userId));
  }

  @RequirePermissions(AppPermission.USE_PURCHASE_VISAS)
  @Idempotent()
  @Post(':id/withdraw')
  async withdraw(
    @Param('id') id: string,
    @Body() dto: WithdrawPurchaseVisaDto,
    @Request() request: UserRequest,
  ) {
    const result = await this.visas.withdraw(id, dto, request.user.username);
    return redactCardNumbers(
      result,
      await this.revealCards(request.user.userId),
    );
  }

  private async revealCards(userId: string) {
    const user = await this.users.findActiveById(userId);
    return viewerCanSeePurchaseVisaNumber(user.role, user.permissions);
  }
}
