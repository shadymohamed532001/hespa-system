import { SetMetadata } from '@nestjs/common';
import { AppPermission } from '../../database/enums.js';

export const PERMISSIONS_KEY = 'permissions';
export const RequirePermissions = (...permissions: AppPermission[]) =>
  SetMetadata(PERMISSIONS_KEY, permissions);
