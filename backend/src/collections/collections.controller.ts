import { Body, Controller, Get, Param, Post, Request } from '@nestjs/common';
import { RequirePermissions } from '../common/decorators/permissions.decorator.js';
import { Idempotent } from '../common/decorators/idempotent.decorator.js';
import { AppPermission } from '../database/enums.js';
import {
  redactCardNumbers,
  viewerCanSeePurchaseVisaNumber,
} from '../purchase-visas/purchase-visa-card.js';
import { UsersService } from '../users/users.service.js';
import { CollectionsService } from './collections.service.js';
import { ExecuteHoldDto } from './dto/execute-hold.dto.js';
import { PayAgentCreditDto } from './dto/pay-agent-credit.dto.js';
import { ReceiveCollectionDto } from './dto/receive-collection.dto.js';

type UserRequest = { user: { userId: string; username: string } };

@Controller('collections')
@RequirePermissions(AppPermission.VIEW_BALANCES)
export class CollectionsController {
  constructor(
    private readonly collections: CollectionsService,
    private readonly users: UsersService,
  ) {}

  @Get()
  async findAll(@Request() request: UserRequest) {
    const rows = await this.collections.findAll();
    return redactCardNumbers(rows, await this.revealCards(request.user.userId));
  }

  @Get('agent-credits')
  findAgentCredits() {
    return this.collections.findAgentCredits();
  }

  @RequirePermissions(AppPermission.RECEIVE_COLLECTIONS)
  @Idempotent()
  @Post('agent-credits/payments')
  async payAgentCredit(
    @Body() dto: PayAgentCreditDto,
    @Request() request: UserRequest,
  ) {
    await this.users.assertAmountLimit(
      request.user.userId,
      'maxReceiveAmount',
      dto.amount,
    );
    return this.collections.payAgentCredit(dto, request.user.username);
  }

  @RequirePermissions(AppPermission.RECEIVE_COLLECTIONS)
  @Idempotent()
  @Post('receive')
  async receive(
    @Body() dto: ReceiveCollectionDto,
    @Request() request: UserRequest,
  ) {
    await this.users.assertAmountLimit(
      request.user.userId,
      'maxReceiveAmount',
      dto.amount,
    );
    const collection = await this.collections.receive(
      dto,
      request.user.username,
    );
    return redactCardNumbers(
      collection,
      await this.revealCards(request.user.userId),
    );
  }

  @RequirePermissions(AppPermission.RECEIVE_COLLECTIONS)
  @Idempotent()
  @Post(':id/execute')
  async execute(
    @Param('id') id: string,
    @Body() dto: ExecuteHoldDto,
    @Request() request: UserRequest,
  ) {
    const hold = await this.collections.findOne(id);
    await this.users.assertAmountLimit(
      request.user.userId,
      'maxReceiveAmount',
      Number(hold.amount),
    );
    const collection = await this.collections.execute(
      id,
      dto,
      request.user.username,
    );
    return redactCardNumbers(
      collection,
      await this.revealCards(request.user.userId),
    );
  }

  private async revealCards(userId: string) {
    const user = await this.users.findActiveById(userId);
    return viewerCanSeePurchaseVisaNumber(user.role, user.permissions);
  }
}
