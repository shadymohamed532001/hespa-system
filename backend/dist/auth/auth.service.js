var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { compare, hash } from 'bcryptjs';
import { Repository } from 'typeorm';
import { User } from '../database/entities/user.entity.js';
import { ALL_PERMISSIONS, DEFAULT_EMPLOYEE_PERMISSIONS, DEFAULT_USER_LIMITS, UserRole, } from '../database/enums.js';
import { UsersService } from '../users/users.service.js';
let AuthService = class AuthService {
    users;
    usersService;
    jwt;
    constructor(users, usersService, jwt) {
        this.users = users;
        this.usersService = usersService;
        this.jwt = jwt;
    }
    async onModuleInit() {
        await this.ensureDemoUser('demo', 'demo', UserRole.ADMIN, 'مدير النظام');
        await this.ensureDemoUser('shix', 'shix', UserRole.EMPLOYEE, 'موظف المحل');
    }
    async ensureDemoUser(username, password, role, displayName) {
        if (await this.users.exists({ where: { username } }))
            return;
        await this.users.save(this.users.create({
            username,
            displayName,
            passwordHash: await hash(password, 12),
            role,
            permissions: role === UserRole.ADMIN
                ? [...ALL_PERMISSIONS]
                : [...DEFAULT_EMPLOYEE_PERMISSIONS],
            limits: { ...DEFAULT_USER_LIMITS },
            active: true,
        }));
    }
    async login(dto) {
        const user = await this.users.findOne({
            where: { username: dto.username, active: true },
        });
        if (!user || !(await compare(dto.password, user.passwordHash))) {
            throw new UnauthorizedException('اسم المستخدم أو كلمة المرور غير صحيحة');
        }
        const publicUser = this.usersService.toPublic(user);
        return {
            accessToken: await this.jwt.signAsync({
                sub: user.id,
                username: user.username,
                role: user.role,
            }),
            user: publicUser,
        };
    }
    async me(userId) {
        const user = await this.usersService.findActiveById(userId);
        return this.usersService.toPublic(user);
    }
};
AuthService = __decorate([
    Injectable(),
    __param(0, InjectRepository(User)),
    __metadata("design:paramtypes", [Repository,
        UsersService,
        JwtService])
], AuthService);
export { AuthService };
//# sourceMappingURL=auth.service.js.map