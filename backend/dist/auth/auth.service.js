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
import { UserRole } from '../database/enums.js';
let AuthService = class AuthService {
    users;
    jwt;
    constructor(users, jwt) {
        this.users = users;
        this.jwt = jwt;
    }
    async onModuleInit() {
        await this.ensureDemoUser('demo', 'demo', UserRole.ADMIN);
        await this.ensureDemoUser('shix', 'shix', UserRole.EMPLOYEE);
    }
    async ensureDemoUser(username, password, role) {
        if (await this.users.exists({ where: { username } }))
            return;
        await this.users.save(this.users.create({ username, passwordHash: await hash(password, 12), role }));
    }
    async login(dto) {
        const user = await this.users.findOne({ where: { username: dto.username, active: true } });
        if (!user || !(await compare(dto.password, user.passwordHash))) {
            throw new UnauthorizedException('اسم المستخدم أو كلمة المرور غير صحيحة');
        }
        return {
            accessToken: await this.jwt.signAsync({ sub: user.id, username: user.username, role: user.role }),
            user: { id: user.id, username: user.username, role: user.role },
        };
    }
};
AuthService = __decorate([
    Injectable(),
    __param(0, InjectRepository(User)),
    __metadata("design:paramtypes", [Repository,
        JwtService])
], AuthService);
export { AuthService };
//# sourceMappingURL=auth.service.js.map