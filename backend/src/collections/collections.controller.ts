import { Body, Controller, Get, Param, Post, Request } from '@nestjs/common';
import { RequirePermissions } from '../common/decorators/permissions.decorator.js';
import { Idempotent } from '../common/decorators/idempotent.decorator.js';
import { AppPermission } from '../database/enums.js';
import { UsersService } from '../users/users.service.js';
import { CollectionsService } from './collections.service.js';
import { ExecuteHoldDto } from './dto/execute-hold.dto.js';
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
  findAll() {
    return this.collections.findAll();
  }

  @RequirePermissions(AppPermission.RECEIVE_COLLECTIONS)
  @Idempotent()
  @Post('receive')
  async receive(@Body() dto: ReceiveCollectionDto, @Request() request: UserRequest) {
    await this.users.assertAmountLimit(
      request.user.userId,
      'maxReceiveAmount',
      dto.amount,
    );
    return this.collections.receive(dto, request.user.username);
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
    return this.collections.execute(id, dto, request.user.username);
  }
}
