import { Injectable, OnModuleInit, UnauthorizedException } from '@nestjs/common';
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
  ) {}

  async onModuleInit() {
    await this.ensureDemoUser('demo', 'demo', UserRole.ADMIN, 'مدير النظام');
    await this.ensureDemoUser('shix', 'shix', UserRole.EMPLOYEE, 'موظف المحل');
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

  async me(userId: string) {
    const user = await this.usersService.findActiveById(userId);
    return this.usersService.toPublic(user);
  }
}
