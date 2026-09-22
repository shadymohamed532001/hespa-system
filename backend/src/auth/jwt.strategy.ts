import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { UserRole } from '../database/enums.js';
import { UsersService } from '../users/users.service.js';

type JwtPayload = { sub: string; username: string; role: UserRole; ver: number };

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(config: ConfigService, private readonly users: UsersService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.getOrThrow<string>('JWT_SECRET'),
      issuer: config.get('JWT_ISSUER', 'hesba-api'),
      audience: config.get('JWT_AUDIENCE', 'hesba-desktop'),
    });
  }

  async validate(payload: JwtPayload) {
    const user = await this.users.findActiveById(payload.sub).catch(() => null);
    if (!user || Number(user.tokenVersion ?? 0) !== Number(payload.ver ?? -1)) {
      throw new UnauthorizedException('انتهت الجلسة، سجل الدخول مرة أخرى');
    }
    return { userId: user.id, username: user.username, role: user.role };
  }
}
