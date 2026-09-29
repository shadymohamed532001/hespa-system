import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { decimalTransformer } from '../decimal.transformer.js';

@Entity('purchase_visas')
export class PurchaseVisa {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true, length: 150 })
  name: string;

  @Column({ name: 'card_number', unique: true, length: 16 })
  cardNumber: string;

  @Column({ name: 'owner_name', length: 120 })
  ownerName: string;

  @Column({ name: 'expires_on', type: 'date' })
  expiresOn: string;

  @Column({ default: true })
  active: boolean;

  @Column({
    type: 'numeric',
    precision: 16,
    scale: 2,
    default: 0,
    transformer: decimalTransformer,
  })
  balance: number;

  @Column({
    name: 'commission_balance',
    type: 'numeric',
    precision: 16,
    scale: 2,
    default: 0,
    transformer: decimalTransformer,
  })
  commissionBalance: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
