import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Request,
} from '@nestjs/common';
import { RequirePermissions } from '../common/decorators/permissions.decorator.js';
import { AppPermission } from '../database/enums.js';
import { ReversalDto } from '../common/dto/reversal.dto.js';
import { Idempotent } from '../common/decorators/idempotent.decorator.js';
import { LedgerService } from './ledger.service.js';

type UserRequest = { user: { username: string } };

@Controller('ledger')
@RequirePermissions(AppPermission.VIEW_BALANCES)
export class LedgerController {
  constructor(private readonly ledger: LedgerService) {}

  @Get()
  findAll(@Query('limit') limit?: string) {
    const take = Math.min(Math.max(Number(limit) || 100, 1), 500);
    return this.ledger.findAll(take);
  }

  @RequirePermissions(AppPermission.REVERSE_OPERATIONS)
  @Idempotent()
  @Post(':id/reverse')
  reverse(
    @Param('id') id: string,
    @Body() dto: ReversalDto,
    @Request() request: UserRequest,
  ) {
    return this.ledger.reverse(id, dto, request.user.username);
  }
}
