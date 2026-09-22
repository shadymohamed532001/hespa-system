import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

export enum IdempotencyStatus {
  PENDING = 'pending',
  COMPLETED = 'completed',
}

@Entity('idempotency_records')
@Index(['userId', 'key'], { unique: true })
export class IdempotencyRecord {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @Column({ length: 120 })
  key: string;

  @Column({ length: 12 })
  method: string;

  @Column({ length: 300 })
  path: string;

  @Column({ name: 'request_hash', length: 64 })
  requestHash: string;

  @Column({
    type: 'enum',
    enum: IdempotencyStatus,
    default: IdempotencyStatus.PENDING,
  })
  status: IdempotencyStatus;

  @Column({ type: 'jsonb', nullable: true })
  response: unknown;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
