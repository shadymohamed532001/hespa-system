import { OnModuleInit } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Repository } from 'typeorm';
import { User } from '../database/entities/user.entity.js';
import { UserRole } from '../database/enums.js';
import { LoginDto } from './dto/login.dto.js';
export declare class AuthService implements OnModuleInit {
    private readonly users;
    private readonly jwt;
    constructor(users: Repository<User>, jwt: JwtService);
    onModuleInit(): Promise<void>;
    private ensureDemoUser;
    login(dto: LoginDto): Promise<{
        accessToken: string;
        user: {
            id: string;
            username: string;
            role: UserRole;
        };
    }>;
}
