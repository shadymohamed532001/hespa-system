import { Body, Controller, Get, Param, ParseBoolPipe, Patch, Post, Query, Request } from '@nestjs/common';
import { Roles } from '../common/decorators/roles.decorator.js';
import { UserRole } from '../database/enums.js';
import { CreateMachineDto } from './dto/create-machine.dto.js';
import { LoadMachineDto } from './dto/load-machine.dto.js';
import { UseMachineDto } from './dto/use-machine.dto.js';
import { MachinesService } from './machines.service.js';

type UserRequest = { user: { username: string } };

@Controller('machines')
export class MachinesController {
  constructor(private readonly machines: MachinesService) {}

  @Get()
  findAll(@Query('includeInactive', new ParseBoolPipe({ optional: true })) includeInactive?: boolean) {
    return this.machines.findAll(includeInactive ?? false);
  }

  @Roles(UserRole.ADMIN)
  @Post()
  create(@Body() dto: CreateMachineDto) {
    return this.machines.create(dto);
  }

  @Roles(UserRole.ADMIN)
  @Post(':id/load')
  load(@Param('id') id: string, @Body() dto: LoadMachineDto, @Request() request: UserRequest) {
    return this.machines.load(id, dto, request.user.username);
  }

  @Post(':id/use')
  use(@Param('id') id: string, @Body() dto: UseMachineDto, @Request() request: UserRequest) {
    return this.machines.use(id, dto, request.user.username);
  }

  @Roles(UserRole.ADMIN)
  @Patch(':id/status')
  setStatus(@Param('id') id: string, @Body('active') active: boolean) {
    return this.machines.setActive(id, active);
  }
}
