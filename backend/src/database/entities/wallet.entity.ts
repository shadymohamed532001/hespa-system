import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { decimalTransformer } from '../decimal.transformer.js';

@Entity('wallets')
export class Wallet {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true, length: 150 })
  name: string;

  @Column({ length: 80 })
  type: string;

  @Column({ default: true })
  active: boolean;

  @Column({ name: 'opening_balance', type: 'numeric', precision: 16, scale: 2, default: 0, transformer: decimalTransformer })
  openingBalance: number;

  @Column({ name: 'today_top_up', type: 'numeric', precision: 16, scale: 2, default: 0, transformer: decimalTransformer })
  todayTopUp: number;

  @Column({ type: 'numeric', precision: 16, scale: 2, default: 0, transformer: decimalTransformer })
  balance: number;

  @Column({ name: 'daily_top_up', type: 'numeric', precision: 16, scale: 2, default: 0, transformer: decimalTransformer })
  dailyTopUp: number;

  @Column({ name: 'monthly_top_up', type: 'numeric', precision: 16, scale: 2, default: 0, transformer: decimalTransformer })
  monthlyTopUp: number;

  @Column({ name: 'counter_day', type: 'date', nullable: true })
  counterDay: string | null;

  @Column({ name: 'counter_month', length: 7, nullable: true })
  counterMonth: string | null;

  @Column({ name: 'commission_balance', type: 'numeric', precision: 16, scale: 2, default: 0, transformer: decimalTransformer })
  commissionBalance: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}

