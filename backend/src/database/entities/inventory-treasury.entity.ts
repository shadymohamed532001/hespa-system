import { Column, Entity, PrimaryColumn, UpdateDateColumn } from 'typeorm';
import { decimalTransformer } from '../decimal.transformer.js';

/** Separate cash box for inventory/mobile sales — never mixes with main treasury. */
@Entity('inventory_treasury')
export class InventoryTreasury {
  @PrimaryColumn({ default: 'inventory' })
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
