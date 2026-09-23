import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PERMISSIONS_KEY } from '../decorators/permissions.decorator.js';
import { AppPermission, UserRole } from '../../database/enums.js';
import { UsersService } from '../../users/users.service.js';
import { msg } from '../i18n/locale-context.js';

type AuthUser = { userId?: string; role?: UserRole };

@Injectable()
export class PermissionsGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly users: UsersService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const required = this.reflector.getAllAndOverride<AppPermission[]>(
      PERMISSIONS_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!required?.length) return true;

    const request = context.switchToHttp().getRequest<{ user?: AuthUser }>();
    const auth = request.user;
    if (!auth?.userId) {
      throw new ForbiddenException(
        msg({ ar: 'غير مصرح', en: 'Unauthorized' }),
      );
    }

    if (auth.role === UserRole.ADMIN) return true;

    const allowed = await this.users.hasPermissions(auth.userId, required);
    if (!allowed) {
      throw new ForbiddenException(
        msg({
          ar: 'ليس لديك صلاحية لتنفيذ هذه العملية',
          en: 'You do not have permission to perform this action',
        }),
      );
    }
    return true;
  }
}
