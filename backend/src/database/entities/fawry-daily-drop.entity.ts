import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  Unique,
} from 'typeorm';
import { decimalTransformer } from '../decimal.transformer.js';

@Entity('fawry_daily_drops')
@Unique('UQ_fawry_daily_drops_account_date', ['accountId', 'businessDate'])
export class FawryDailyDrop {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'account_id', type: 'uuid' })
  accountId: string;

  @Column({ name: 'business_date', type: 'date' })
  businessDate: string;

  @Column({
    type: 'numeric',
    precision: 16,
    scale: 2,
    transformer: decimalTransformer,
  })
  amount: number;

  @Column({ name: 'performed_by', length: 80 })
  performedBy: string;

  @Column({ name: 'ledger_entry_id', type: 'uuid', nullable: true })
  ledgerEntryId: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
