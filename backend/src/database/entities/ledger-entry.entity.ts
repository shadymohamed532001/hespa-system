import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { decimalTransformer } from '../decimal.transformer.js';
import { LedgerCategory } from '../enums.js';

@Entity('ledger_entries')
export class LedgerEntry {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'enum', enum: LedgerCategory })
  category: LedgerCategory;

  @Column({
    type: 'numeric',
    precision: 16,
    scale: 2,
    transformer: decimalTransformer,
  })
  amount: number;

  @Column({ name: 'entity_type', length: 50 })
  entityType: string;

  @Column({
    name: 'entity_id',
    type: 'varchar',
    length: 80,
    nullable: true,
  })
  entityId: string | null;

  @Column({
    type: 'varchar',
    length: 80,
    nullable: true,
  })
  reference: string | null;

  @Column({ type: 'text' })
  description: string;

  @Column({ name: 'performed_by', length: 80 })
  performedBy: string;

  @Column({ name: 'source_type', type: 'varchar', length: 50, nullable: true })
  sourceType: string | null;

  @Column({ name: 'source_id', type: 'varchar', length: 80, nullable: true })
  sourceId: string | null;

  @Column({ name: 'target_type', type: 'varchar', length: 50, nullable: true })
  targetType: string | null;

  @Column({ name: 'target_id', type: 'varchar', length: 80, nullable: true })
  targetId: string | null;

  @Column({ name: 'reverses_entry_id', type: 'uuid', nullable: true })
  reversesEntryId: string | null;

  @Column({ type: 'jsonb', nullable: true })
  metadata: Record<string, unknown> | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
