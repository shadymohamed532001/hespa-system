import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn } from 'typeorm';
import { decimalTransformer } from '../decimal.transformer.js';
import { LedgerCategory } from '../enums.js';

@Entity('ledger_entries')
export class LedgerEntry {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'enum', enum: LedgerCategory })
  category: LedgerCategory;

  @Column({ type: 'numeric', precision: 16, scale: 2, transformer: decimalTransformer })
  amount: number;

  @Column({ name: 'entity_type', length: 50 })
  entityType: string;

  @Column({ name: 'entity_id', length: 80, nullable: true })
  entityId: string | null;

  @Column({ length: 80, nullable: true })
  reference: string | null;

  @Column({ type: 'text' })
  description: string;

  @Column({ name: 'performed_by', length: 80 })
  performedBy: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}

