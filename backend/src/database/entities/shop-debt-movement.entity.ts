import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { decimalTransformer } from '../decimal.transformer.js';

export type ShopDebtKind = 'borrow' | 'repay';

/**
 * Money the shop owner borrowed from a person (borrow) or paid back (repay).
 * Record-only: it does not move treasury or account balances.
 */
@Entity('shop_debt_movements')
export class ShopDebtMovement {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true, length: 40 })
  reference: string;

  @Column({ name: 'person_name', length: 150 })
  personName: string;

  @Column({ type: 'varchar', length: 10 })
  kind: ShopDebtKind;

  @Column({
    type: 'numeric',
    precision: 16,
    scale: 2,
    transformer: decimalTransformer,
  })
  amount: number;

  @Column({ type: 'varchar', length: 500, nullable: true })
  note: string | null;

  @Column({ name: 'performed_by', length: 80 })
  performedBy: string;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @Column({ name: 'cancelled_at', type: 'timestamptz', nullable: true })
  cancelledAt: Date | null;

  @Column({ name: 'cancelled_by', type: 'varchar', length: 80, nullable: true })
  cancelledBy: string | null;

  @Column({
    name: 'cancel_reason',
    type: 'varchar',
    length: 300,
    nullable: true,
  })
  cancelReason: string | null;
}
