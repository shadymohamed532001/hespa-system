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
import { AppPermission } from '../database/enums.js';
import {
  RegisterDeviceTokenDto,
  UnregisterDeviceTokenDto,
} from './dto/device-token.dto.js';

type UserRequest = { user: { userId: string; username: string } };

@Controller('notifications')
@RequirePermissions(AppPermission.VIEW_BALANCES)
export class NotificationsController {
  constructor(
    private readonly notifications: NotificationsService,
    private readonly fcm: FcmService,
  ) {}

  @Get()
  findAll(@Query('limit') limit?: string) {
    return this.notifications.findAll(Number(limit) || 40);
  }

  @Get('unread-count')
  unreadCount() {
    return this.notifications.unreadCount();
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
  markRead(@Param('id') id: string) {
    return this.notifications.markRead(id);
  }

  @Post('read-all')
  markAllRead() {
    return this.notifications.markAllRead();
  }
}
