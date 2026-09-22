import { Body, Controller, Get, Param, Post, Request } from '@nestjs/common';
import { RequirePermissions } from '../common/decorators/permissions.decorator.js';
import { Idempotent } from '../common/decorators/idempotent.decorator.js';
import { AppPermission } from '../database/enums.js';
import { UsersService } from '../users/users.service.js';
import { CreateWalletDto } from './dto/create-wallet.dto.js';
import { TopUpWalletDto } from './dto/top-up-wallet.dto.js';
import { WalletsService } from './wallets.service.js';

type UserRequest = { user: { userId: string; username: string } };

@Controller('wallets')
@RequirePermissions(AppPermission.VIEW_BALANCES)
export class WalletsController {
  constructor(
    private readonly wallets: WalletsService,
    private readonly users: UsersService,
  ) {}

  @Get()
  findAll() {
    return this.wallets.findAll();
  }

  @RequirePermissions(AppPermission.MANAGE_ASSETS)
  @Idempotent()
  @Post()
  create(@Body() dto: CreateWalletDto, @Request() request: UserRequest) {
    return this.wallets.create(dto, request.user.username);
  }

  @RequirePermissions(AppPermission.TOP_UP_ASSETS)
  @Idempotent()
  @Post(':id/top-up')
  async topUp(
    @Param('id') id: string,
    @Body() dto: TopUpWalletDto,
    @Request() request: UserRequest,
  ) {
    await this.users.assertAmountLimit(
      request.user.userId,
      'maxTopUpAmount',
      dto.amount,
    );
    return this.wallets.topUp(id, dto, request.user.username);
  }
}
