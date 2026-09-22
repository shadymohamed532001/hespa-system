import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { decimalTransformer } from '../decimal.transformer.js';
import { NotificationKind } from '../enums.js';

@Entity('notifications')
export class AppNotification {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'enum', enum: NotificationKind })
  kind: NotificationKind;

  @Column({ length: 120 })
  title: string;

  @Column({ type: 'text' })
  body: string;

  @Column({
    type: 'numeric',
    precision: 16,
    scale: 2,
    nullable: true,
    transformer: decimalTransformer,
  })
  amount: number | null;

  @Column({ name: 'ledger_entry_id', type: 'uuid', nullable: true, unique: true })
  ledgerEntryId: string | null;

  @Column({ name: 'is_read', default: false })
  isRead: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
