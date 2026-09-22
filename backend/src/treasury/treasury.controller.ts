import { Body, Controller, Get, Post, Request } from '@nestjs/common';
import { Roles } from '../common/decorators/roles.decorator.js';
import { UserRole } from '../database/enums.js';
import { InternalTransferDto } from './dto/internal-transfer.dto.js';
import { TreasuryService } from './treasury.service.js';

type UserRequest = { user: { username: string } };

@Controller('treasury')
export class TreasuryController {
  constructor(private readonly treasury: TreasuryService) {}

  @Get('summary')
  summary() {
    return this.treasury.summary();
  }

  @Roles(UserRole.ADMIN)
  @Post('transfer')
  transfer(@Body() dto: InternalTransferDto, @Request() request: UserRequest) {
    return this.treasury.transfer(dto, request.user.username);
  }

  @Roles(UserRole.ADMIN)
  @Post('rollover')
  rollover(@Request() request: UserRequest) {
    return this.treasury.rollover(request.user.username);
  }
}

