import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Request,
} from '@nestjs/common';
import { RequirePermissions } from '../common/decorators/permissions.decorator.js';
import { Idempotent } from '../common/decorators/idempotent.decorator.js';
import { AppPermission } from '../database/enums.js';
import { CreateUserDto, UpdateUserDto } from './dto/user.dto.js';
import { UsersService } from './users.service.js';

type UserRequest = { user: { userId: string; username: string } };

@Controller('users')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @RequirePermissions(AppPermission.MANAGE_USERS)
  @Get()
  findAll() {
    return this.users.findAll();
  }

  @RequirePermissions(AppPermission.MANAGE_USERS)
  @Get('permission-catalog')
  catalog() {
    return this.users.permissionCatalog();
  }

  @RequirePermissions(AppPermission.MANAGE_USERS)
  @Idempotent()
  @Post()
  create(@Body() dto: CreateUserDto) {
    return this.users.create(dto);
  }

  @RequirePermissions(AppPermission.MANAGE_USERS)
  @Idempotent()
  @Patch(':id')
  update(
    @Param('id') id: string,
    @Body() dto: UpdateUserDto,
    @Request() request: UserRequest,
  ) {
    return this.users.update(id, dto, request.user.userId);
  }

  @RequirePermissions(AppPermission.MANAGE_USERS)
  @Idempotent()
  @Patch(':id/status')
  setStatus(
    @Param('id') id: string,
    @Body('active') active: boolean,
    @Request() request: UserRequest,
  ) {
    return this.users.setActive(id, active, request.user.userId);
  }
}
