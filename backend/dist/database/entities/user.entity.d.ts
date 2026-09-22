import { AppPermission, UserRole } from '../enums.js';
import type { UserLimits } from '../enums.js';
export declare class User {
    id: string;
    username: string;
    displayName: string;
    passwordHash: string;
    role: UserRole;
    permissions: AppPermission[];
    limits: UserLimits;
    active: boolean;
    createdAt: Date;
    updatedAt: Date;
}
