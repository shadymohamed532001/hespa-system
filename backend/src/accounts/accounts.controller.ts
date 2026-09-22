import { Body, Controller, Delete, Get, Param, ParseBoolPipe, Patch, Post, Query, Request } from '@nestjs/common';
import { Roles } from '../common/decorators/roles.decorator.js';
import { UserRole } from '../database/enums.js';
import { AccountsService } from './accounts.service.js';
import { CreateAccountDto } from './dto/create-account.dto.js';
import { TopUpAccountDto } from './dto/top-up-account.dto.js';

type UserRequest = { user: { username: string } };

@Controller('accounts')
export class AccountsController {
  constructor(private readonly accounts: AccountsService) {}

  @Get()
  findAll(@Query('includeInactive', new ParseBoolPipe({ optional: true })) includeInactive?: boolean) {
    return this.accounts.findAll(includeInactive ?? false);
  }

  @Roles(UserRole.ADMIN)
  @Post()
  create(@Body() dto: CreateAccountDto, @Request() request: UserRequest) {
    return this.accounts.create(dto, request.user.username);
  }

  @Roles(UserRole.ADMIN)
  @Post(':id/top-up')
  topUp(@Param('id') id: string, @Body() dto: TopUpAccountDto, @Request() request: UserRequest) {
    return this.accounts.topUp(id, dto, request.user.username);
  }

  @Roles(UserRole.ADMIN)
  @Patch(':id/status')
  setStatus(@Param('id') id: string, @Body('active') active: boolean) {
    return this.accounts.setActive(id, active);
  }

  @Roles(UserRole.ADMIN)
  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.accounts.remove(id);
  }
}

