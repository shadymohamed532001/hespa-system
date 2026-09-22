import {
  Body,
  Controller,
  Get,
  Param,
  ParseBoolPipe,
  Patch,
  Post,
  Query,
  Request,
} from '@nestjs/common';
import { RequirePermissions } from '../common/decorators/permissions.decorator.js';
import { AppPermission } from '../database/enums.js';
import { CreateMachineDto } from './dto/create-machine.dto.js';
import { LoadMachineDto } from './dto/load-machine.dto.js';
import { UseMachineDto } from './dto/use-machine.dto.js';
import { MachinesService } from './machines.service.js';

type UserRequest = { user: { username: string } };

@Controller('machines')
export class MachinesController {
  constructor(private readonly machines: MachinesService) {}

  @Get()
  findAll(
    @Query('includeInactive', new ParseBoolPipe({ optional: true }))
    includeInactive?: boolean,
  ) {
    return this.machines.findAll(includeInactive ?? false);
  }

  @RequirePermissions(AppPermission.MANAGE_ASSETS)
  @Post()
  create(@Body() dto: CreateMachineDto, @Request() request: UserRequest) {
    return this.machines.create(dto, request.user.username);
  }

  @RequirePermissions(AppPermission.TOP_UP_ASSETS)
  @Post(':id/load')
  load(
    @Param('id') id: string,
    @Body() dto: LoadMachineDto,
    @Request() request: UserRequest,
  ) {
    return this.machines.load(id, dto, request.user.username);
  }

  @RequirePermissions(AppPermission.USE_MACHINES)
  @Post(':id/use')
  use(
    @Param('id') id: string,
    @Body() dto: UseMachineDto,
    @Request() request: UserRequest,
  ) {
    return this.machines.use(id, dto, request.user.username);
  }

  @RequirePermissions(AppPermission.MANAGE_ASSETS)
  @Patch(':id/status')
  setStatus(@Param('id') id: string, @Body('active') active: boolean) {
    return this.machines.setActive(id, active);
  }
}
