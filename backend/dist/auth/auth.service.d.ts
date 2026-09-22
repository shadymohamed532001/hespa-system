import { OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Repository } from 'typeorm';
import { User } from '../database/entities/user.entity.js';
import { UsersService } from '../users/users.service.js';
import { LoginDto } from './dto/login.dto.js';
export declare class AuthService implements OnModuleInit {
    private readonly users;
    private readonly usersService;
    private readonly jwt;
    private readonly config;
    constructor(users: Repository<User>, usersService: UsersService, jwt: JwtService, config: ConfigService);
    onModuleInit(): Promise<void>;
    private disableUnchangedDemoUsers;
    private ensureProductionAdmin;
    private ensureDemoUser;
    login(dto: LoginDto): Promise<{
        accessToken: string;
        user: import("../users/users.service.js").PublicUser;
    }>;
    me(userId: string): Promise<import("../users/users.service.js").PublicUser>;
}
