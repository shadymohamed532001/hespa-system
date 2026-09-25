import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseBoolPipe,
  Patch,
  Post,
  Query,
  Request,
} from '@nestjs/common';
import { RequirePermissions } from '../common/decorators/permissions.decorator.js';
import { Idempotent } from '../common/decorators/idempotent.decorator.js';
import { AppPermission } from '../database/enums.js';
import { UsersService } from '../users/users.service.js';
import { CreateWalletDto } from './dto/create-wallet.dto.js';
import { CustomerWalletOperationDto } from './dto/customer-wallet-operation.dto.js';
import { TopUpWalletDto } from './dto/top-up-wallet.dto.js';
import { UseWalletDto } from './dto/use-wallet.dto.js';
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
  findAll(
    @Query('includeInactive', new ParseBoolPipe({ optional: true }))
    includeInactive?: boolean,
  ) {
    return this.wallets.findAll(includeInactive ?? false);
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

  @RequirePermissions(AppPermission.USE_WALLETS)
  @Idempotent()
  @Post(':id/use')
  use(
    @Param('id') id: string,
    @Body() dto: UseWalletDto,
    @Request() request: UserRequest,
  ) {
    return this.wallets.customerOperation(
      id,
      { direction: 'send', amount: dto.amount, reference: dto.reference, purpose: dto.purpose },
      request.user.username,
    );
  }

  @RequirePermissions(AppPermission.USE_WALLETS)
  @Idempotent()
  @Post(':id/customer-operation')
  customerOperation(
    @Param('id') id: string,
    @Body() dto: CustomerWalletOperationDto,
    @Request() request: UserRequest,
  ) {
    return this.wallets.customerOperation(id, dto, request.user.username);
  }

  @RequirePermissions(AppPermission.MANAGE_ASSETS)
  @Idempotent()
  @Patch(':id/status')
  setStatus(
    @Param('id') id: string,
    @Body('active', ParseBoolPipe) active: boolean,
  ) {
    return this.wallets.setActive(id, active);
  }

  @RequirePermissions(AppPermission.MANAGE_ASSETS)
  @Idempotent()
  @Delete(':id')
  remove(@Param('id') id: string, @Request() request: UserRequest) {
    return this.wallets.remove(id, request.user.username);
  }
}
