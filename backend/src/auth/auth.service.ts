import { Injectable, OnModuleInit, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { compare, hash } from 'bcryptjs';
import { Repository } from 'typeorm';
import { User } from '../database/entities/user.entity.js';
import {
  ALL_PERMISSIONS,
  DEFAULT_EMPLOYEE_PERMISSIONS,
  DEFAULT_USER_LIMITS,
  UserRole,
} from '../database/enums.js';
import { UsersService } from '../users/users.service.js';
import { LoginDto } from './dto/login.dto.js';

@Injectable()
export class AuthService implements OnModuleInit {
  constructor(
    @InjectRepository(User) private readonly users: Repository<User>,
    private readonly usersService: UsersService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  async onModuleInit() {
    const production = this.config.get('NODE_ENV', 'development') === 'production';
    const seedDemo =
      this.config.get('SEED_DEMO_DATA', production ? 'false' : 'true') === 'true';

    if (seedDemo) {
      await this.ensureDemoUser('demo', 'demo', UserRole.ADMIN, 'مدير النظام');
      await this.ensureDemoUser('shix', 'shix', UserRole.EMPLOYEE, 'موظف المحل');
      return;
    }

    await this.disableUnchangedDemoUsers();
    await this.ensureProductionAdmin();
  }

  private async disableUnchangedDemoUsers() {
    const demoCredentials = [
      { username: 'demo', password: 'demo' },
      { username: 'shix', password: 'shix' },
    ];
    for (const credential of demoCredentials) {
      const user = await this.users.findOne({ where: { username: credential.username } });
      if (!user || !user.active) continue;
      if (await compare(credential.password, user.passwordHash)) {
        user.active = false;
        user.tokenVersion = Number(user.tokenVersion ?? 0) + 1;
        await this.users.save(user);
      }
    }
  }

  private async ensureProductionAdmin() {
    if (await this.users.exists({ where: { role: UserRole.ADMIN, active: true } })) return;

    const username = this.config.get<string>('BOOTSTRAP_ADMIN_USERNAME')?.trim().toLowerCase();
    const password = this.config.get<string>('BOOTSTRAP_ADMIN_PASSWORD');
    if (!username || !password || password.length < 10 || password.length > 128) {
      throw new Error(
        'No active admin exists. Set BOOTSTRAP_ADMIN_USERNAME and a 10+ character BOOTSTRAP_ADMIN_PASSWORD for the first production start.',
      );
    }
    await this.users.save(
      this.users.create({
        username,
        displayName: 'مدير النظام',
        passwordHash: await hash(password, 12),
        role: UserRole.ADMIN,
        permissions: [...ALL_PERMISSIONS],
        limits: { ...DEFAULT_USER_LIMITS },
        active: true,
        tokenVersion: 0,
      }),
    );
  }

  private async ensureDemoUser(
    username: string,
    password: string,
    role: UserRole,
    displayName: string,
  ) {
    if (await this.users.exists({ where: { username } })) return;
    await this.users.save(
      this.users.create({
        username,
        displayName,
        passwordHash: await hash(password, 12),
        role,
        permissions:
          role === UserRole.ADMIN
            ? [...ALL_PERMISSIONS]
            : [...DEFAULT_EMPLOYEE_PERMISSIONS],
        limits: { ...DEFAULT_USER_LIMITS },
        active: true,
      }),
    );
  }

  async login(dto: LoginDto) {
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

  async me(userId: string) {
    const user = await this.usersService.findActiveById(userId);
    return this.usersService.toPublic(user);
  }
}
