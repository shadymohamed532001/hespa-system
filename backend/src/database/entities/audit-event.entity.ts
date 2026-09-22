import { Column, CreateDateColumn, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';

@Entity('audit_events')
@Index(['createdAt'])
export class AuditEvent {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', type: 'uuid', nullable: true })
  userId: string | null;

  @Column({ name: 'username', type: 'varchar', length: 80, nullable: true })
  username: string | null;

  @Column({ length: 12 })
  method: string;

  @Column({ length: 300 })
  path: string;

  @Column({ name: 'status_code', type: 'int' })
  statusCode: number;

  @Column({ default: true })
  success: boolean;

  @Column({ name: 'ip_address', type: 'varchar', length: 80, nullable: true })
  ipAddress: string | null;

  @Column({ name: 'user_agent', type: 'varchar', length: 500, nullable: true })
  userAgent: string | null;

  @Column({ type: 'jsonb', nullable: true })
  details: Record<string, unknown> | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
