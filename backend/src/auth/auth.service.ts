import { Injectable, OnModuleInit, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { compare, hash } from 'bcryptjs';
import { Repository } from 'typeorm';
import { User } from '../database/entities/user.entity.js';
import { UserRole } from '../database/enums.js';
import { LoginDto } from './dto/login.dto.js';

@Injectable()
export class AuthService implements OnModuleInit {
  constructor(
    @InjectRepository(User) private readonly users: Repository<User>,
    private readonly jwt: JwtService,
  ) {}

  async onModuleInit() {
    await this.ensureDemoUser('demo', 'demo', UserRole.ADMIN);
    await this.ensureDemoUser('shix', 'shix', UserRole.EMPLOYEE);
  }

  private async ensureDemoUser(username: string, password: string, role: UserRole) {
    if (await this.users.exists({ where: { username } })) return;
    await this.users.save(
      this.users.create({ username, passwordHash: await hash(password, 12), role }),
    );
  }

  async login(dto: LoginDto) {
    const user = await this.users.findOne({ where: { username: dto.username, active: true } });
    if (!user || !(await compare(dto.password, user.passwordHash))) {
      throw new UnauthorizedException('اسم المستخدم أو كلمة المرور غير صحيحة');
    }
    return {
      accessToken: await this.jwt.signAsync({ sub: user.id, username: user.username, role: user.role }),
      user: { id: user.id, username: user.username, role: user.role },
    };
  }
}

