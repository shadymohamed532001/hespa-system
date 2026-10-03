import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseBoolPipe,
  ParseIntPipe,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  Request,
} from '@nestjs/common';
import { RequirePermissions } from '../common/decorators/permissions.decorator.js';
import { Idempotent } from '../common/decorators/idempotent.decorator.js';
import { Roles } from '../common/decorators/roles.decorator.js';
import { AppPermission, UserRole } from '../database/enums.js';
import { UsersService } from '../users/users.service.js';
import { AccountsService, fawryCashTotal } from './accounts.service.js';
import { CreateAccountDto } from './dto/create-account.dto.js';
import { RecordFawryDailyDropDto } from './dto/record-fawry-daily-drop.dto.js';
import { RecordFawryDepositDto } from './dto/record-fawry-deposit.dto.js';
import { ProfitQrCashOutDto } from './dto/profit-qr-cash-out.dto.js';
import { TopUpAccountDto } from './dto/top-up-account.dto.js';

type UserRequest = { user: { userId: string; username: string } };

@Controller('accounts')
@RequirePermissions(AppPermission.VIEW_BALANCES)
export class AccountsController {
  constructor(
    private readonly accounts: AccountsService,
    private readonly users: UsersService,
  ) {}

  @Roles(UserRole.ADMIN)
  @Get('fawry-daily-drops')
  todayDrops() {
    return this.accounts.todayDrops();
  }

  @Get('fawry-today-operations')
  todayFawryOperations(
    @Query('accountId', new ParseUUIDPipe({ optional: true }))
    accountId?: string,
  ) {
    return this.accounts.todayFawryOperations(accountId);
  }

  @RequirePermissions(AppPermission.TOP_UP_ASSETS)
  @Get('fawry-depositors')
  fawryDepositors() {
    return this.accounts.fawryDepositors();
  }

  @RequirePermissions(AppPermission.TOP_UP_ASSETS)
  @Get('fawry-deposits')
  fawryDeposits(
    @Query('limit', new ParseIntPipe({ optional: true })) limit?: number,
  ) {
    return this.accounts.findFawryDeposits(limit ?? 100);
  }

  @Get()
  findAll(
    @Query('includeInactive', new ParseBoolPipe({ optional: true }))
    includeInactive?: boolean,
  ) {
    return this.accounts.findAll(includeInactive ?? false);
  }

  @RequirePermissions(AppPermission.MANAGE_ASSETS)
  @Idempotent()
  @Post()
  create(@Body() dto: CreateAccountDto, @Request() request: UserRequest) {
    return this.accounts.create(dto, request.user.username);
  }

  @Roles(UserRole.ADMIN)
  @Idempotent()
  @Post(':id/fawry-daily-drop')
  recordDailyDrop(
    @Param('id') id: string,
    @Body() dto: RecordFawryDailyDropDto,
    @Request() request: UserRequest,
  ) {
    return this.accounts.recordDailyDrop(id, dto.amount, request.user.username);
  }

  @RequirePermissions(AppPermission.TOP_UP_ASSETS)
  @Idempotent()
  @Post(':id/top-up')
  async topUp(
    @Param('id') id: string,
    @Body() dto: TopUpAccountDto,
    @Request() request: UserRequest,
  ) {
    await this.users.assertAmountLimit(
      request.user.userId,
      'maxTopUpAmount',
      dto.amount,
    );
    return this.accounts.topUp(id, dto, request.user.username);
  }

  @RequirePermissions(AppPermission.USE_WALLETS)
  @Idempotent()
  @Post(':id/profit-qr-cash-out')
  profitQrCashOut(
    @Param('id') id: string,
    @Body() dto: ProfitQrCashOutDto,
    @Request() request: UserRequest,
  ) {
    return this.accounts.profitQrCashOut(id, dto, request.user.username);
  }

  @RequirePermissions(AppPermission.TOP_UP_ASSETS)
  @Idempotent()
  @Post(':id/fawry-deposit')
  async recordFawryDeposit(
    @Param('id') id: string,
    @Body() dto: RecordFawryDepositDto,
    @Request() request: UserRequest,
  ) {
    const amount = fawryCashTotal(dto.cashCounts);
    await this.users.assertAmountLimit(
      request.user.userId,
      'maxTopUpAmount',
      amount,
    );
    return this.accounts.recordFawryDeposit(id, dto, request.user.username);
  }

  @RequirePermissions(AppPermission.MANAGE_ASSETS)
  @Patch(':id/status')
  setStatus(
    @Param('id') id: string,
    @Body('active', ParseBoolPipe) active: boolean,
  ) {
    return this.accounts.setActive(id, active);
  }

  @RequirePermissions(AppPermission.MANAGE_ASSETS)
  @Idempotent()
  @Delete(':id')
  remove(@Param('id') id: string, @Request() request: UserRequest) {
    return this.accounts.remove(id, request.user.username);
  }
}
