import { Roles } from '../common/decorators/roles.decorator.js';
import { UserRole } from '../database/enums.js';
import { CorrectionDto } from './correction.dto.js';
import { OperationCorrectionsService } from './operation-corrections.service.js';
import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
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
  constructor(
    private readonly ledger: LedgerService,
    private readonly corrections: OperationCorrectionsService,
  ) {}

  @Get()
  findAll(@Query('limit') limit?: string) {
    const take = Math.min(Math.max(Number(limit) || 100, 1), 500);
    return this.ledger.findAll(take);
  }

  @Roles(UserRole.ADMIN)
  @Get('collections/:id/correction')
  describeCollection(@Param('id', new ParseUUIDPipe()) id: string) {
    return this.corrections.describeCollection(id);
  }

  @Roles(UserRole.ADMIN)
  @Idempotent()
  @Post('collections/:id/cancel')
  cancelCollection(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: ReversalDto,
    @Request() request: UserRequest,
  ) {
    return this.corrections.cancelCollection(id, dto, request.user.username);
  }

  @Roles(UserRole.ADMIN)
  @Idempotent()
  @Post('collections/:id/correct')
  correctCollection(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: CorrectionDto,
    @Request() request: UserRequest,
  ) {
    return this.corrections.correctCollection(id, dto, request.user.username);
  }

  @Roles(UserRole.ADMIN)
  @Get('inventory-sales/:id/correction')
  describeSale(@Param('id', new ParseUUIDPipe()) id: string) {
    return this.corrections.describeSale(id);
  }

  @Roles(UserRole.ADMIN)
  @Idempotent()
  @Post('inventory-sales/:id/cancel')
  cancelSale(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: ReversalDto,
    @Request() request: UserRequest,
  ) {
    return this.corrections.cancelSale(id, dto, request.user.username);
  }

  @Roles(UserRole.ADMIN)
  @Idempotent()
  @Post('inventory-sales/:id/correct')
  correctSale(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: CorrectionDto,
    @Request() request: UserRequest,
  ) {
    return this.corrections.correctSale(id, dto, request.user.username);
  }

  @Roles(UserRole.ADMIN)
  @Get(':id/correction')
  describe(@Param('id', new ParseUUIDPipe()) id: string) {
    return this.corrections.describe(id);
  }

  @Roles(UserRole.ADMIN)
  @Idempotent()
  @Post(':id/cancel')
  cancel(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: ReversalDto,
    @Request() request: UserRequest,
  ) {
    return this.corrections.cancel(id, dto, request.user.username);
  }

  @Roles(UserRole.ADMIN)
  @Idempotent()
  @Post(':id/correct')
  correct(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: CorrectionDto,
    @Request() request: UserRequest,
  ) {
    return this.corrections.correct(id, dto, request.user.username);
  }

  @RequirePermissions(AppPermission.REVERSE_OPERATIONS)
  @Idempotent()
  @Post(':id/reverse')
  reverse(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: ReversalDto,
    @Request() request: UserRequest,
  ) {
    return this.ledger.reverse(id, dto, request.user.username);
  }
}
