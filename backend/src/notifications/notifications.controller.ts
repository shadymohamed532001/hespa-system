import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Request,
} from '@nestjs/common';
import { NotificationsService } from './notifications.service.js';
import { FcmService } from './fcm.service.js';
import { RequirePermissions } from '../common/decorators/permissions.decorator.js';
import { AppPermission, UserRole } from '../database/enums.js';
import {
  RegisterDeviceTokenDto,
  UnregisterDeviceTokenDto,
} from './dto/device-token.dto.js';

type UserRequest = {
  user: { userId: string; username: string; role: UserRole };
};

@Controller('notifications')
@RequirePermissions(AppPermission.VIEW_BALANCES)
export class NotificationsController {
  constructor(
    private readonly notifications: NotificationsService,
    private readonly fcm: FcmService,
  ) {}

  @Get()
  findAll(@Request() request: UserRequest, @Query('limit') limit?: string) {
    return this.notifications.findAll(
      Number(limit) || 40,
      request.user.role === UserRole.ADMIN,
    );
  }

  @Get('unread-count')
  unreadCount(@Request() request: UserRequest) {
    return this.notifications.unreadCount(request.user.role === UserRole.ADMIN);
  }

  @Post('device-token')
  registerDeviceToken(
    @Body() dto: RegisterDeviceTokenDto,
    @Request() request: UserRequest,
  ) {
    return this.fcm.registerToken(
      request.user.userId,
      dto.token,
      dto.platform ?? 'unknown',
    );
  }

  @Post('device-token/unregister')
  unregisterDeviceToken(
    @Body() dto: UnregisterDeviceTokenDto,
    @Request() request: UserRequest,
  ) {
    return this.fcm.unregisterToken(dto.token, request.user.userId);
  }

  @Patch(':id/read')
  markRead(@Param('id') id: string, @Request() request: UserRequest) {
    return this.notifications.markRead(
      id,
      request.user.role === UserRole.ADMIN,
    );
  }

  @Post('read-all')
  markAllRead(@Request() request: UserRequest) {
    return this.notifications.markAllRead(request.user.role === UserRole.ADMIN);
  }
}
