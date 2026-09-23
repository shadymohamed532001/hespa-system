import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  OnModuleInit,
} from '@nestjs/common';
import { msg } from '../common/i18n/locale-context.js';
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
    if (!user) throw new NotFoundException(msg({ ar: 'المستخدم غير موجود', en: 'User not found' }));
    return user;
  }

  async findActiveById(id: string) {
    const user = await this.users.findOne({ where: { id, active: true } });
    if (!user) throw new NotFoundException(msg({ ar: 'المستخدم غير موجود أو غير نشط', en: 'User not found or inactive' }));
    return user;
  }

  async create(dto: CreateUserDto) {
    const username = dto.username.trim().toLowerCase();
    if (await this.users.exists({ where: { username } })) {
      throw new ConflictException(msg({ ar: 'اسم المستخدم مستخدم بالفعل', en: 'Username is already taken' }));
    }
    const role = dto.role ?? UserRole.EMPLOYEE;
    if (role === UserRole.ADMIN) {
      throw new BadRequestException(msg({ ar: 'لا يمكن إنشاء أدمن إضافي من هذه الواجهة', en: 'Cannot create an additional admin from this screen' }));
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

  async update(
    id: string,
    dto: UpdateUserDto,
    actorId: string,
    actorRole: UserRole,
  ) {
    const user = await this.findById(id);
    let revokeSessions = false;
    if (
      user.role === UserRole.ADMIN &&
      user.id !== actorId &&
      actorRole !== UserRole.ADMIN
    ) {
      throw new ForbiddenException(msg({ ar: 'لا يمكن لغير الأدمن تعديل حساب أدمن', en: 'Only an admin can edit an admin account' }));
    }
    if (dto.displayName != null) user.displayName = dto.displayName.trim();
    if (dto.password) {
      user.passwordHash = await hash(dto.password, 12);
      revokeSessions = true;
    }
    if (dto.role != null && dto.role !== user.role) {
      if (dto.role === UserRole.ADMIN) {
        throw new BadRequestException(msg({ ar: 'لا يمكن ترقية المستخدم إلى أدمن', en: 'Cannot promote the user to admin' }));
      }
      if (user.id === actorId) {
        throw new BadRequestException(msg({ ar: 'لا يمكنك تغيير دور حسابك الحالي', en: 'You cannot change your own account role' }));
      }
      if (actorRole !== UserRole.ADMIN) {
        throw new ForbiddenException(msg({ ar: 'تغيير دور الحساب متاح للأدمن فقط', en: 'Changing account role is available to admins only' }));
      }
      if (user.role === UserRole.ADMIN && user.active) {
        await this.assertAnotherActiveAdmin(user.id);
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
        throw new BadRequestException(msg({ ar: 'لا يمكنك تعطيل حسابك الحالي', en: 'You cannot deactivate your own account' }));
      }
      if (user.role === UserRole.ADMIN && dto.active === false) {
        if (actorRole !== UserRole.ADMIN) {
          throw new ForbiddenException(msg({ ar: 'لا يمكن لغير الأدمن تعطيل حساب أدمن', en: 'Only an admin can deactivate an admin account' }));
        }
        await this.assertAnotherActiveAdmin(user.id);
      }
      user.active = dto.active;
      revokeSessions = true;
    }
    if (revokeSessions) user.tokenVersion = Number(user.tokenVersion ?? 0) + 1;
    return this.toPublic(await this.users.save(user));
  }

  async setActive(
    id: string,
    active: boolean,
    actorId: string,
    actorRole: UserRole,
  ) {
    return this.update(id, { active }, actorId, actorRole);
  }

  async remove(id: string, actorId: string, actorRole: UserRole) {
    if (actorRole !== UserRole.ADMIN) {
      throw new ForbiddenException(msg({ ar: 'حذف الحسابات متاح للأدمن فقط', en: 'Deleting accounts is available to admins only' }));
    }
    if (id === actorId) {
      throw new BadRequestException(msg({ ar: 'لا يمكنك حذف حسابك الحالي', en: 'You cannot delete your own account' }));
    }

    const user = await this.findById(id);
    if (user.role === UserRole.ADMIN && user.active) {
      await this.assertAnotherActiveAdmin(user.id);
    }

    const deletedId = user.id;
    const deletedLabel = user.displayName || user.username;
    await this.users.remove(user);
    return {
      ok: true,
      id: deletedId,
      message: `تم حذف حساب ${deletedLabel} نهائيًا`,
    };
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
        maxReceiveAmount: msg({ ar: 'استلام/تحصيل', en: 'Receive / collection' }),
        maxTopUpAmount: msg({ ar: 'الشحن', en: 'Top-up' }),
        maxSaleAmount: msg({ ar: 'البيع', en: 'Sale' }),
        maxTransferAmount: msg({ ar: 'التحويل', en: 'Transfer' }),
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
      {
        key: AppPermission.USE_WALLETS,
        label: 'استخدام المحافظ الإلكترونية وInstaPay',
        note: 'تحويل أو دفع من رصيد المحفظة وتسجيل العمولة',
      },
      {
        key: AppPermission.REVERSE_OPERATIONS,
        label: 'عكس العمليات المالية',
        note: 'صلاحية حساسة مع تسجيل السبب والمنفذ',
      },
      {
        key: AppPermission.RECONCILE_BALANCES,
        label: 'تسوية الأرصدة الفعلية',
        note: 'مطابقة الرصيد المسجل مع الجرد الفعلي',
      },
    ];
  }

  private async assertAnotherActiveAdmin(excludedUserId: string) {
    const activeAdmins = await this.users.count({
      where: { role: UserRole.ADMIN, active: true },
    });
    const excluded = await this.users.findOne({
      where: { id: excludedUserId },
    });
    const remaining = activeAdmins - (excluded?.active ? 1 : 0);
    if (remaining < 1) {
      throw new BadRequestException(
        msg({
          ar: 'لا يمكن تعطيل أو حذف آخر حساب أدمن نشط',
          en: 'Cannot deactivate or delete the last active admin account',
        }),
      );
    }
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
