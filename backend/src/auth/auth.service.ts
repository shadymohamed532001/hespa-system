import {
  ConflictException,
  Injectable,
  OnModuleInit,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { compare, hash } from 'bcryptjs';
import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import { IsNull, Repository } from 'typeorm';
import { RefreshToken } from '../database/entities/refresh-token.entity.js';
import { User } from '../database/entities/user.entity.js';
import {
  ALL_PERMISSIONS,
  DEFAULT_EMPLOYEE_PERMISSIONS,
  DEFAULT_USER_LIMITS,
  UserRole,
} from '../database/enums.js';
import { UsersService } from '../users/users.service.js';
import { LoginDto, LoginPortal } from './dto/login.dto.js';
import { RecoverAdminDto } from './dto/recover-admin.dto.js';
import { msg } from '../common/i18n/locale-context.js';

const DAY_MS = 86_400_000;

@Injectable()
export class AuthService implements OnModuleInit {
  constructor(
    @InjectRepository(User) private readonly users: Repository<User>,
    @InjectRepository(RefreshToken)
    private readonly refreshTokens: Repository<RefreshToken>,
    private readonly usersService: UsersService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  async onModuleInit() {
    const production =
      this.config.get('NODE_ENV', 'development') === 'production';
    const seedDemo =
      this.config.get('SEED_DEMO_DATA', production ? 'false' : 'true') ===
      'true';

    if (seedDemo) {
      await this.ensureDemoUser('demo', 'demo', UserRole.ADMIN, 'مدير النظام');
      await this.ensureDemoUser(
        'shix',
        'shix',
        UserRole.EMPLOYEE,
        'موظف المحل',
      );
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
      const user = await this.users.findOne({
        where: { username: credential.username },
      });
      if (!user || !user.active) continue;
      if (await compare(credential.password, user.passwordHash)) {
        user.active = false;
        user.tokenVersion = Number(user.tokenVersion ?? 0) + 1;
        await this.users.save(user);
        await this.revokeAllRefreshTokens(user.id);
      }
    }
  }

  private async ensureProductionAdmin() {
    if (
      await this.users.exists({ where: { role: UserRole.ADMIN, active: true } })
    )
      return;

    const username = this.config
      .get<string>('BOOTSTRAP_ADMIN_USERNAME')
      ?.trim()
      .toLowerCase();
    const password = this.config.get<string>('BOOTSTRAP_ADMIN_PASSWORD');
    if (
      !username ||
      !password ||
      password.length < 10 ||
      password.length > 128
    ) {
      throw new Error(
        'No active admin exists. Set BOOTSTRAP_ADMIN_USERNAME and a 10+ character BOOTSTRAP_ADMIN_PASSWORD for the first production start.',
      );
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
      await this.revokeAllRefreshTokens(existing.id);
      return;
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
      throw new UnauthorizedException(
        msg({
          ar: 'اسم المستخدم أو كلمة المرور غير صحيحة',
          en: 'Invalid username or password',
        }),
      );
    }

    const expectedRole =
      dto.portal === LoginPortal.ADMIN ? UserRole.ADMIN : UserRole.EMPLOYEE;
    if (user.role !== expectedRole) {
      throw new UnauthorizedException(
        dto.portal === LoginPortal.ADMIN
          ? msg({
              ar: 'هذا الحساب يدخل من مدخل الموظفين فقط',
              en: 'This account can only sign in from the staff portal',
            })
          : msg({
              ar: 'هذا الحساب يدخل من مدخل الأدمن فقط',
              en: 'This account can only sign in from the admin portal',
            }),
      );
    }

    return this.issueSession(user);
  }

  async recoverAdmin(dto: RecoverAdminDto) {
    const configuredKey = this.config.get<string>('ADMIN_RECOVERY_KEY') ?? '';
    if (!this.matchesRecoveryKey(dto.recoveryKey, configuredKey)) {
      throw new UnauthorizedException(
        msg({
          ar: 'كود استعادة المدير غير صحيح أو غير مفعّل',
          en: 'Admin recovery code is invalid or not configured',
        }),
      );
    }

    const username = dto.username.trim().toLowerCase();
    if (await this.users.exists({ where: { username } })) {
      throw new ConflictException(
        msg({
          ar: 'اسم المستخدم مستخدم بالفعل',
          en: 'Username is already taken',
        }),
      );
    }

    const user = await this.users.save(
      this.users.create({
        username,
        displayName: (dto.displayName ?? dto.username).trim(),
        passwordHash: await hash(dto.password, 12),
        role: UserRole.ADMIN,
        permissions: [...ALL_PERMISSIONS],
        limits: { ...DEFAULT_USER_LIMITS },
        active: true,
        tokenVersion: 0,
      }),
    );
    return { ok: true, user: this.usersService.toPublic(user) };
  }

  async refresh(rawRefreshToken: string) {
    const tokenHash = this.hashRefreshToken(rawRefreshToken);
    const stored = await this.refreshTokens.findOne({ where: { tokenHash } });
    if (!stored) {
      throw new UnauthorizedException(
        msg({
          ar: 'انتهت الجلسة، سجل الدخول مرة أخرى',
          en: 'Session expired, please sign in again',
        }),
      );
    }

    if (stored.revokedAt) {
      // Suspected reuse of a rotated token — revoke the whole family.
      await this.revokeAllRefreshTokens(stored.userId);
      throw new UnauthorizedException(
        msg({
          ar: 'انتهت الجلسة، سجل الدخول مرة أخرى',
          en: 'Session expired, please sign in again',
        }),
      );
    }

    if (stored.expiresAt.getTime() <= Date.now()) {
      stored.revokedAt = new Date();
      await this.refreshTokens.save(stored);
      throw new UnauthorizedException(
        msg({
          ar: 'انتهت الجلسة، سجل الدخول مرة أخرى',
          en: 'Session expired, please sign in again',
        }),
      );
    }

    const user = await this.users.findOne({
      where: { id: stored.userId, active: true },
    });
    if (
      !user ||
      Number(user.tokenVersion ?? 0) !== Number(stored.tokenVersion)
    ) {
      await this.revokeAllRefreshTokens(stored.userId);
      throw new UnauthorizedException(
        msg({
          ar: 'انتهت الجلسة، سجل الدخول مرة أخرى',
          en: 'Session expired, please sign in again',
        }),
      );
    }

    const session = await this.issueSession(user, stored);
    return session;
  }

  async logout(rawRefreshToken: string) {
    const tokenHash = this.hashRefreshToken(rawRefreshToken);
    const stored = await this.refreshTokens.findOne({ where: { tokenHash } });
    if (stored && !stored.revokedAt) {
      stored.revokedAt = new Date();
      await this.refreshTokens.save(stored);
    }
    return { ok: true };
  }

  async me(userId: string) {
    const user = await this.usersService.findActiveById(userId);
    return this.usersService.toPublic(user);
  }

  private async issueSession(user: User, previous?: RefreshToken) {
    const publicUser = this.usersService.toPublic(user);
    const accessToken = await this.jwt.signAsync({
      sub: user.id,
      username: user.username,
      role: user.role,
      ver: Number(user.tokenVersion ?? 0),
    });
    const { raw: refreshToken, id: refreshTokenId } =
      await this.createRefreshToken(user);
    if (previous) {
      previous.revokedAt = new Date();
      previous.replacedById = refreshTokenId;
      await this.refreshTokens.save(previous);
    }
    return { accessToken, refreshToken, user: publicUser };
  }

  private async createRefreshToken(user: User) {
    const raw = randomBytes(48).toString('base64url');
    const expiresIn = this.config.get('REFRESH_TOKEN_EXPIRES_IN', '30d');
    const expiresAt = new Date(
      Date.now() + this.parseDurationMs(expiresIn, 30 * DAY_MS),
    );
    const saved = await this.refreshTokens.save(
      this.refreshTokens.create({
        userId: user.id,
        tokenHash: this.hashRefreshToken(raw),
        tokenVersion: Number(user.tokenVersion ?? 0),
        expiresAt,
        revokedAt: null,
        replacedById: null,
      }),
    );
    return { raw, id: saved.id };
  }

  private async revokeAllRefreshTokens(userId: string) {
    await this.refreshTokens.update(
      { userId, revokedAt: IsNull() },
      { revokedAt: new Date() },
    );
  }

  private hashRefreshToken(raw: string) {
    return createHash('sha256').update(raw).digest('hex');
  }

  private matchesRecoveryKey(provided: string, configured: string) {
    if (configured.length < 16) return false;
    const providedHash = createHash('sha256').update(provided).digest();
    const configuredHash = createHash('sha256').update(configured).digest();
    return timingSafeEqual(providedHash, configuredHash);
  }

  private parseDurationMs(value: string, fallbackMs: number) {
    const match = /^(\d+)\s*([smhd])$/i.exec(value.trim());
    if (!match) return fallbackMs;
    const amount = Number(match[1]);
    const unit = match[2].toLowerCase();
    const multipliers: Record<string, number> = {
      s: 1000,
      m: 60_000,
      h: 3_600_000,
      d: DAY_MS,
    };
    return amount * (multipliers[unit] ?? 1);
  }
}
