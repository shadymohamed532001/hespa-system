import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { decimalTransformer } from '../decimal.transformer.js';

@Entity('daily_closes')
export class DailyClose {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'business_date', type: 'date', unique: true })
  businessDate: string;

  @Column({ type: 'jsonb' })
  snapshot: Record<string, unknown>;

  @Column({
    name: 'total_assets',
    type: 'numeric',
    precision: 16,
    scale: 2,
    transformer: decimalTransformer,
  })
  totalAssets: number;

  @Column({
    name: 'pending_collections',
    type: 'numeric',
    precision: 16,
    scale: 2,
    transformer: decimalTransformer,
  })
  pendingCollections: number;

  @Column({ name: 'closed_by', length: 80 })
  closedBy: string;

  @Column({ type: 'varchar', length: 300, nullable: true })
  note: string | null;

  @CreateDateColumn({ name: 'closed_at', type: 'timestamptz' })
  closedAt: Date;
}
