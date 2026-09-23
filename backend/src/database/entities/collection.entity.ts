import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { decimalTransformer } from '../decimal.transformer.js';
import { CollectionStatus, ExecutionMode } from '../enums.js';
import { FinancialAccount } from './financial-account.entity.js';

@Entity('collections')
export class Collection {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true, length: 40 })
  reference: string;

  @Column({ name: 'agent_name', length: 150 })
  agentName: string;

  @Column({ name: 'company_name', length: 150 })
  companyName: string;

  @Column({
    type: 'numeric',
    precision: 16,
    scale: 2,
    transformer: decimalTransformer,
  })
  amount: number;

  @Column({ type: 'enum', enum: ExecutionMode })
  executionMode: ExecutionMode;

  @Column({ type: 'enum', enum: CollectionStatus })
  status: CollectionStatus;

  @Column({ name: 'received_at', type: 'timestamptz' })
  receivedAt: Date;

  @Column({ name: 'executed_at', type: 'timestamptz', nullable: true })
  executedAt: Date | null;

  @Column({ name: 'reversed_at', type: 'timestamptz', nullable: true })
  reversedAt: Date | null;

  @Column({ name: 'reversal_reason', type: 'varchar', length: 300, nullable: true })
  reversalReason: string | null;

  @ManyToOne(() => FinancialAccount, { nullable: true, onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'account_id' })
  account: FinancialAccount | null;

  @Column({
    type: 'numeric',
    precision: 16,
    scale: 2,
    default: 0,
    transformer: decimalTransformer,
  })
  commission: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
