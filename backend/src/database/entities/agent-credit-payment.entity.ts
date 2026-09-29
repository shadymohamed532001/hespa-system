import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { decimalTransformer } from '../decimal.transformer.js';

@Entity('agent_credit_payments')
export class AgentCreditPayment {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true, length: 40 })
  reference: string;

  @Column({ name: 'agent_name', length: 150 })
  agentName: string;

  @Column({
    type: 'numeric',
    precision: 16,
    scale: 2,
    transformer: decimalTransformer,
  })
  amount: number;

  @Column({ name: 'performed_by', length: 80 })
  performedBy: string;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
