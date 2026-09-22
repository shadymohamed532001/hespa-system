import { Body, Controller, Get, Param, Post, Request } from '@nestjs/common';
import { Roles } from '../common/decorators/roles.decorator.js';
import { UserRole } from '../database/enums.js';
import { CreateWalletDto } from './dto/create-wallet.dto.js';
import { TopUpWalletDto } from './dto/top-up-wallet.dto.js';
import { WalletsService } from './wallets.service.js';

type UserRequest = { user: { username: string } };

@Controller('wallets')
export class WalletsController {
  constructor(private readonly wallets: WalletsService) {}

  @Get()
  findAll() {
    return this.wallets.findAll();
  }

  @Roles(UserRole.ADMIN)
  @Post()
  create(@Body() dto: CreateWalletDto) {
    return this.wallets.create(dto);
  }

  @Roles(UserRole.ADMIN)
  @Post(':id/top-up')
  topUp(@Param('id') id: string, @Body() dto: TopUpWalletDto, @Request() request: UserRequest) {
    return this.wallets.topUp(id, dto, request.user.username);
  }
}

