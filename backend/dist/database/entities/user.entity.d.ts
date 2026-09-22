import { UserRole } from '../enums.js';
export declare class User {
    id: string;
    username: string;
    passwordHash: string;
    role: UserRole;
    active: boolean;
    createdAt: Date;
    updatedAt: Date;
}
