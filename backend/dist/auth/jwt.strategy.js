var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { UsersService } from '../users/users.service.js';
let JwtStrategy = class JwtStrategy extends PassportStrategy(Strategy) {
    users;
    constructor(config, users) {
        super({
            jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
            ignoreExpiration: false,
            secretOrKey: config.getOrThrow('JWT_SECRET'),
            issuer: config.get('JWT_ISSUER', 'hesba-api'),
            audience: config.get('JWT_AUDIENCE', 'hesba-desktop'),
        });
        this.users = users;
    }
    async validate(payload) {
        const user = await this.users.findActiveById(payload.sub).catch(() => null);
        if (!user || Number(user.tokenVersion ?? 0) !== Number(payload.ver ?? -1)) {
            throw new UnauthorizedException('انتهت الجلسة، سجل الدخول مرة أخرى');
        }
        return { userId: user.id, username: user.username, role: user.role };
    }
};
JwtStrategy = __decorate([
    Injectable(),
    __metadata("design:paramtypes", [ConfigService, UsersService])
], JwtStrategy);
export { JwtStrategy };
//# sourceMappingURL=jwt.strategy.js.map