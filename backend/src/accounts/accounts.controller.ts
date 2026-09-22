import { Body, Controller, Delete, Get, Param, ParseBoolPipe, Patch, Post, Query, Request } from '@nestjs/common';
import { RequirePermissions } from '../common/decorators/permissions.decorator.js';
import { Idempotent } from '../common/decorators/idempotent.decorator.js';
import { AppPermission } from '../database/enums.js';
import { UsersService } from '../users/users.service.js';
import { AccountsService } from './accounts.service.js';
import { CreateAccountDto } from './dto/create-account.dto.js';
import { TopUpAccountDto } from './dto/top-up-account.dto.js';

type UserRequest = { user: { userId: string; username: string } };

@Controller('accounts')
@RequirePermissions(AppPermission.VIEW_BALANCES)
export class AccountsController {
  constructor(
    private readonly accounts: AccountsService,
    private readonly users: UsersService,
  ) {}

  @Get()
  findAll(@Query('includeInactive', new ParseBoolPipe({ optional: true })) includeInactive?: boolean) {
    return this.accounts.findAll(includeInactive ?? false);
  }

  @RequirePermissions(AppPermission.MANAGE_ASSETS)
  @Idempotent()
  @Post()
  create(@Body() dto: CreateAccountDto, @Request() request: UserRequest) {
    return this.accounts.create(dto, request.user.username);
  }

  @RequirePermissions(AppPermission.TOP_UP_ASSETS)
  @Idempotent()
  @Post(':id/top-up')
  async topUp(
    @Param('id') id: string,
    @Body() dto: TopUpAccountDto,
    @Request() request: UserRequest,
  ) {
    await this.users.assertAmountLimit(request.user.userId, 'maxTopUpAmount', dto.amount);
    return this.accounts.topUp(id, dto, request.user.username);
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
