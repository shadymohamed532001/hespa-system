import { Body, Controller, Get, Post, Request } from '@nestjs/common';
import { RequirePermissions } from '../common/decorators/permissions.decorator.js';
import { Idempotent } from '../common/decorators/idempotent.decorator.js';
import { AppPermission } from '../database/enums.js';
import { UsersService } from '../users/users.service.js';
import { InternalTransferDto } from './dto/internal-transfer.dto.js';
import { TreasuryService } from './treasury.service.js';

type UserRequest = { user: { userId: string; username: string } };

@Controller('treasury')
@RequirePermissions(AppPermission.VIEW_BALANCES)
export class TreasuryController {
  constructor(
    private readonly treasury: TreasuryService,
    private readonly users: UsersService,
  ) {}

  @Get('summary')
  summary() {
    return this.treasury.summary();
  }

  @RequirePermissions(AppPermission.INTERNAL_TRANSFER)
  @Idempotent()
  @Post('transfer')
  async transfer(
    @Body() dto: InternalTransferDto,
    @Request() request: UserRequest,
  ) {
    await this.users.assertAmountLimit(
      request.user.userId,
      'maxTransferAmount',
      dto.amount,
    );
    return this.treasury.transfer(dto, request.user.username);
  }

  @RequirePermissions(AppPermission.DAILY_ROLLOVER)
  @Idempotent()
  @Post('rollover')
  rollover(@Request() request: UserRequest) {
    return this.treasury.rollover(request.user.username);
  }
}
