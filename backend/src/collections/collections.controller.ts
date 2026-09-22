import { Body, Controller, Get, Param, Post, Request } from '@nestjs/common';
import { CollectionsService } from './collections.service.js';
import { ExecuteHoldDto } from './dto/execute-hold.dto.js';
import { ReceiveCollectionDto } from './dto/receive-collection.dto.js';

type UserRequest = { user: { username: string } };

@Controller('collections')
export class CollectionsController {
  constructor(private readonly collections: CollectionsService) {}

  @Get()
  findAll() {
    return this.collections.findAll();
  }

  @Post('receive')
  receive(@Body() dto: ReceiveCollectionDto, @Request() request: UserRequest) {
    return this.collections.receive(dto, request.user.username);
  }

  @Post(':id/execute')
  execute(@Param('id') id: string, @Body() dto: ExecuteHoldDto, @Request() request: UserRequest) {
    return this.collections.execute(id, dto, request.user.username);
  }
}

