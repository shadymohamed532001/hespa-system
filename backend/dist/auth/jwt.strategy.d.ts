import { ConfigService } from '@nestjs/config';
import { Strategy } from 'passport-jwt';
import { UserRole } from '../database/enums.js';
import { UsersService } from '../users/users.service.js';
type JwtPayload = {
    sub: string;
    username: string;
    role: UserRole;
    ver: number;
};
declare const JwtStrategy_base: new (...args: [opt: import("passport-jwt").StrategyOptionsWithRequest] | [opt: import("passport-jwt").StrategyOptionsWithoutRequest]) => Strategy & {
    validate(...args: any[]): unknown;
};
export declare class JwtStrategy extends JwtStrategy_base {
    private readonly users;
    constructor(config: ConfigService, users: UsersService);
    validate(payload: JwtPayload): Promise<{
        userId: string;
        username: string;
        role: UserRole;
    }>;
}
export {};
