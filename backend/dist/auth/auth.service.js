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
import { Injectable, UnauthorizedException, } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
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
    config;
    constructor(users, usersService, jwt, config) {
        this.users = users;
        this.usersService = usersService;
        this.jwt = jwt;
        this.config = config;
    }
    async onModuleInit() {
        const production = this.config.get('NODE_ENV', 'development') === 'production';
        const seedDemo = this.config.get('SEED_DEMO_DATA', production ? 'false' : 'true') ===
            'true';
        if (seedDemo) {
            await this.ensureDemoUser('demo', 'demo', UserRole.ADMIN, 'مدير النظام');
            await this.ensureDemoUser('shix', 'shix', UserRole.EMPLOYEE, 'موظف المحل');
            return;
        }
        await this.disableUnchangedDemoUsers();
        await this.ensureProductionAdmin();
    }
    async disableUnchangedDemoUsers() {
        const demoCredentials = [
            { username: 'demo', password: 'demo' },
            { username: 'shix', password: 'shix' },
        ];
        for (const credential of demoCredentials) {
            const user = await this.users.findOne({
                where: { username: credential.username },
            });
            if (!user || !user.active)
                continue;
            if (await compare(credential.password, user.passwordHash)) {
                user.active = false;
                user.tokenVersion = Number(user.tokenVersion ?? 0) + 1;
                await this.users.save(user);
            }
        }
    }
    async ensureProductionAdmin() {
        if (await this.users.exists({ where: { role: UserRole.ADMIN, active: true } }))
            return;
        const username = this.config
            .get('BOOTSTRAP_ADMIN_USERNAME')
            ?.trim()
            .toLowerCase();
        const password = this.config.get('BOOTSTRAP_ADMIN_PASSWORD');
        if (!username ||
            !password ||
            password.length < 10 ||
            password.length > 128) {
            throw new Error('No active admin exists. Set BOOTSTRAP_ADMIN_USERNAME and a 10+ character BOOTSTRAP_ADMIN_PASSWORD for the first production start.');
        }
        const existing = await this.users.findOne({ where: { username } });
        if (existing) {
            existing.displayName = existing.displayName || 'مدير النظام';
            existing.passwordHash = await hash(password, 12);
            existing.role = UserRole.ADMIN;
            existing.permissions = [...ALL_PERMISSIONS];
            existing.active = true;
            existing.tokenVersion = Number(existing.tokenVersion ?? 0) + 1;
            await this.users.save(existing);
            return;
        }
        await this.users.save(this.users.create({
            username,
            displayName: 'مدير النظام',
            passwordHash: await hash(password, 12),
            role: UserRole.ADMIN,
            permissions: [...ALL_PERMISSIONS],
            limits: { ...DEFAULT_USER_LIMITS },
            active: true,
            tokenVersion: 0,
        }));
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
            where: { username: dto.username.trim().toLowerCase(), active: true },
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
                ver: Number(user.tokenVersion ?? 0),
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
        JwtService,
        ConfigService])
], AuthService);
export { AuthService };
//# sourceMappingURL=auth.service.js.map