import { Column, Entity, PrimaryColumn, UpdateDateColumn } from 'typeorm';
import { decimalTransformer } from '../decimal.transformer.js';

@Entity('treasury')
export class Treasury {
  @PrimaryColumn({ default: 'main' })
  id: string;

  @Column({
    type: 'numeric',
    precision: 16,
    scale: 2,
    default: 0,
    transformer: decimalTransformer,
  })
  balance: number;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
