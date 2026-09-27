import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { decimalTransformer } from '../decimal.transformer.js';
import { FinancialAccount } from './financial-account.entity.js';
import { User } from './user.entity.js';

export type FawryCashCounts = {
  count200: number;
  count100: number;
  count50: number;
  count20: number;
  count10: number;
  count5: number;
};

@Entity('fawry_deposits')
export class FawryDeposit {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => FinancialAccount, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'account_id' })
  account: FinancialAccount;

  @Column({ name: 'account_id', type: 'uuid' })
  accountId: string;

  @ManyToOne(() => User, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'depositor_user_id' })
  depositor: User | null;

  @Column({ name: 'depositor_user_id', type: 'uuid', nullable: true })
  depositorUserId: string | null;

  /** Kept as a snapshot so the audit trail survives user rename/deletion. */
  @Column({ name: 'depositor_name', length: 120 })
  depositorName: string;

  @Column({ name: 'cash_counts', type: 'jsonb' })
  cashCounts: FawryCashCounts;

  @Column({
    type: 'numeric',
    precision: 16,
    scale: 2,
    transformer: decimalTransformer,
  })
  amount: number;

  @Column({ type: 'varchar', length: 80, nullable: true })
  reference: string | null;

  @Column({ name: 'performed_by', length: 80 })
  performedBy: string;

  @Column({ name: 'ledger_entry_id', type: 'uuid', nullable: true })
  ledgerEntryId: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
