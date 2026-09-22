import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import {
  AppPermission,
  DEFAULT_EMPLOYEE_PERMISSIONS,
  DEFAULT_USER_LIMITS,
  UserRole,
} from '../enums.js';
import type { UserLimits } from '../enums.js';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true, length: 80 })
  username: string;

  @Column({ name: 'display_name', length: 120, default: '' })
  displayName: string;

  @Column({ name: 'password_hash' })
  passwordHash: string;

  @Column({ type: 'enum', enum: UserRole })
  role: UserRole;

  /** Effective only for employees; admins always have every permission. */
  @Column({
    type: 'jsonb',
    default: () => `'${JSON.stringify(DEFAULT_EMPLOYEE_PERMISSIONS)}'`,
  })
  permissions: AppPermission[];

  @Column({
    type: 'jsonb',
    default: () => `'${JSON.stringify(DEFAULT_USER_LIMITS)}'`,
  })
  limits: UserLimits;

  @Column({ default: true })
  active: boolean;

  /** Incremented whenever credentials, role, permissions, or status change. */
  @Column({ name: 'token_version', type: 'int', default: 0 })
  tokenVersion: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
