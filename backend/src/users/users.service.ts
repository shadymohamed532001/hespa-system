import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  OnModuleInit,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { hash } from 'bcryptjs';
import { Repository } from 'typeorm';
import { User } from '../database/entities/user.entity.js';
import {
  ALL_PERMISSIONS,
  AppPermission,
  DEFAULT_EMPLOYEE_PERMISSIONS,
  DEFAULT_USER_LIMITS,
  UserLimits,
  UserRole,
} from '../database/enums.js';
import { CreateUserDto, UpdateUserDto, UserLimitsDto } from './dto/user.dto.js';

export type PublicUser = {
  id: string;
  username: string;
  displayName: string;
  role: UserRole;
  permissions: AppPermission[];
  limits: UserLimits;
  active: boolean;
  createdAt: Date;
};

@Injectable()
export class UsersService implements OnModuleInit {
  constructor(
    @InjectRepository(User) private readonly users: Repository<User>,
  ) {}

  async onModuleInit() {
    // Backfill columns for users created before permissions existed.
    const rows = await this.users.find();
    for (const user of rows) {
      let dirty = false;
      if (!user.displayName) {
        user.displayName = user.username;
        dirty = true;
      }
      if (!Array.isArray(user.permissions) || user.permissions.length === 0) {
        user.permissions =
          user.role === UserRole.ADMIN
            ? [...ALL_PERMISSIONS]
            : [...DEFAULT_EMPLOYEE_PERMISSIONS];
        dirty = true;
      }
      if (!user.limits || typeof user.limits !== 'object') {
        user.limits = { ...DEFAULT_USER_LIMITS };
        dirty = true;
      } else {
        user.limits = { ...DEFAULT_USER_LIMITS, ...user.limits };
      }
      if (dirty) await this.users.save(user);
    }
  }

  toPublic(user: User): PublicUser {
    const permissions =
      user.role === UserRole.ADMIN
        ? [...ALL_PERMISSIONS]
        : [...(user.permissions ?? DEFAULT_EMPLOYEE_PERMISSIONS)];
    return {
      id: user.id,
      username: user.username,
      displayName: user.displayName || user.username,
      role: user.role,
      permissions,
      limits: { ...DEFAULT_USER_LIMITS, ...user.limits },
      active: user.active,
      createdAt: user.createdAt,
    };
  }

  async findAll() {
    const rows = await this.users.find({ order: { createdAt: 'ASC' } });
    return rows.map((u) => this.toPublic(u));
  }

  async findById(id: string) {
    const user = await this.users.findOne({ where: { id } });
    if (!user) throw new NotFoundException('المستخدم غير موجود');
    return user;
  }

  async findActiveById(id: string) {
    const user = await this.users.findOne({ where: { id, active: true } });
    if (!user) throw new NotFoundException('المستخدم غير موجود أو غير نشط');
    return user;
  }

  async create(dto: CreateUserDto) {
    const username = dto.username.trim().toLowerCase();
    if (await this.users.exists({ where: { username } })) {
      throw new ConflictException('اسم المستخدم مستخدم بالفعل');
    }
    const role = dto.role ?? UserRole.EMPLOYEE;
    if (role === UserRole.ADMIN) {
      throw new BadRequestException('لا يمكن إنشاء أدمن إضافي من هذه الواجهة');
    }
    const user = this.users.create({
      username,
      displayName: (dto.displayName ?? dto.username).trim(),
      passwordHash: await hash(dto.password, 12),
      role,
      permissions: dto.permissions?.length
        ? [...new Set(dto.permissions)]
        : [...DEFAULT_EMPLOYEE_PERMISSIONS],
      limits: this.mergeLimits(DEFAULT_USER_LIMITS, dto.limits),
      active: true,
      tokenVersion: 0,
    });
    return this.toPublic(await this.users.save(user));
  }

  async update(id: string, dto: UpdateUserDto, actorId: string) {
    const user = await this.findById(id);
    let revokeSessions = false;
    if (user.role === UserRole.ADMIN && user.id !== actorId) {
      throw new ForbiddenException(
        'لا يمكن تعديل حساب الأدمن الأساسي بهذه الطريقة',
      );
    }
    if (dto.displayName != null) user.displayName = dto.displayName.trim();
    if (dto.password) {
      user.passwordHash = await hash(dto.password, 12);
      revokeSessions = true;
    }
    if (dto.role != null && user.role !== UserRole.ADMIN) {
      if (dto.role === UserRole.ADMIN) {
        throw new BadRequestException('لا يمكن ترقية المستخدم إلى أدمن');
      }
      user.role = dto.role;
      revokeSessions = true;
    }
    if (dto.permissions && user.role !== UserRole.ADMIN) {
      user.permissions = [...new Set(dto.permissions)];
      revokeSessions = true;
    }
    if (dto.limits) {
      user.limits = this.mergeLimits(
        user.limits ?? DEFAULT_USER_LIMITS,
        dto.limits,
      );
      revokeSessions = true;
    }
    if (dto.active != null) {
      if (user.id === actorId && dto.active === false) {
        throw new BadRequestException('لا يمكنك تعطيل حسابك الحالي');
      }
      if (user.role === UserRole.ADMIN && dto.active === false) {
        throw new BadRequestException('لا يمكن تعطيل حساب الأدمن');
      }
      user.active = dto.active;
      revokeSessions = true;
    }
    if (revokeSessions) user.tokenVersion = Number(user.tokenVersion ?? 0) + 1;
    return this.toPublic(await this.users.save(user));
  }

  async setActive(id: string, active: boolean, actorId: string) {
    return this.update(id, { active }, actorId);
  }

  async hasPermissions(userId: string, required: AppPermission[]) {
    const user = await this.findActiveById(userId);
    if (user.role === UserRole.ADMIN) return true;
    const owned = new Set(user.permissions ?? []);
    return required.every((p) => owned.has(p));
  }

  async assertAmountLimit(
    userId: string,
    key: keyof UserLimits,
    amount: number,
  ) {
    const user = await this.findActiveById(userId);
    if (user.role === UserRole.ADMIN) return;
    const limits = { ...DEFAULT_USER_LIMITS, ...user.limits };
    const cap = limits[key];
    if (cap == null) return;
    if (Number(amount) > Number(cap)) {
      const labels: Record<keyof UserLimits, string> = {
        maxReceiveAmount: 'استلام/تحصيل',
        maxTopUpAmount: 'الشحن',
        maxSaleAmount: 'البيع',
        maxTransferAmount: 'التحويل',
      };
      throw new ForbiddenException(
        `تجاوزت الحد المسموح لعملية ${labels[key]} (${cap})`,
      );
    }
  }

  permissionCatalog() {
    return [
      {
        key: AppPermission.VIEW_BALANCES,
        label: 'مشاهدة الأرصدة والحركات',
        note: 'للمتابعة اليومية',
      },
      {
        key: AppPermission.RECEIVE_COLLECTIONS,
        label: 'استلام كاش المندوب وتنفيذ التحصيل',
        note: 'العمليات اليومية',
      },
      {
        key: AppPermission.MANAGE_ASSETS,
        label: 'إضافة أو تعديل الحسابات والمحافظ والماكينات',
        note: 'إعدادات الأصول',
      },
      {
        key: AppPermission.TOP_UP_ASSETS,
        label: 'شحن الحسابات والمحافظ وتحميل الماكينات',
        note: 'من لوحة الإدارة',
      },
      {
        key: AppPermission.INTERNAL_TRANSFER,
        label: 'التحويل الداخلي بين أصول المحل',
        note: 'نقل داخلي بلا ربح أو مصروف',
      },
      {
        key: AppPermission.DAILY_ROLLOVER,
        label: 'إقفال اليوم وترحيل الرصيد',
        note: 'تثبيت الرصيد الافتتاحي',
      },
      {
        key: AppPermission.MANAGE_USERS,
        label: 'إدارة المستخدمين والصلاحيات',
        note: 'إعدادات النظام',
      },
      {
        key: AppPermission.SELL_INVENTORY,
        label: 'بيع أصناف من مخزن الموبايلات والإكسسوارات',
        note: 'فلوس البيع تذهب لخزنة المخزن فقط',
      },
      {
        key: AppPermission.MANAGE_INVENTORY,
        label: 'إضافة أصناف وتوريد مخزون للمخزن',
        note: 'إعدادات مخزن منفصل عن الكاش',
      },
      {
        key: AppPermission.USE_MACHINES,
        label: 'استخدام ماكينات شحن الرصيد',
        note: 'خصم من رصيد الماكينة',
      },
    ];
  }

  private mergeLimits(base: UserLimits, patch?: UserLimitsDto): UserLimits {
    if (!patch) return { ...DEFAULT_USER_LIMITS, ...base };
    return {
      maxReceiveAmount:
        patch.maxReceiveAmount === undefined
          ? (base.maxReceiveAmount ?? null)
          : patch.maxReceiveAmount,
      maxTopUpAmount:
        patch.maxTopUpAmount === undefined
          ? (base.maxTopUpAmount ?? null)
          : patch.maxTopUpAmount,
      maxSaleAmount:
        patch.maxSaleAmount === undefined
          ? (base.maxSaleAmount ?? null)
          : patch.maxSaleAmount,
      maxTransferAmount:
        patch.maxTransferAmount === undefined
          ? (base.maxTransferAmount ?? null)
          : patch.maxTransferAmount,
    };
  }
}
