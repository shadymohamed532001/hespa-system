import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { decimalTransformer } from '../decimal.transformer.js';
import { InventoryCategory } from '../enums.js';

@Entity('inventory_products')
export class InventoryProduct {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ length: 150 })
  name: string;

  @Column({ type: 'enum', enum: InventoryCategory })
  category: InventoryCategory;

  @Column({
    name: 'stock_qty',
    type: 'int',
    default: 0,
  })
  stockQty: number;

  @Column({
    name: 'sold_qty',
    type: 'int',
    default: 0,
  })
  soldQty: number;

  @Column({
    name: 'default_price',
    type: 'numeric',
    precision: 16,
    scale: 2,
    default: 0,
    transformer: decimalTransformer,
  })
  defaultPrice: number;

  @Column({ default: true })
  active: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  get remainingQty(): number {
    return this.stockQty;
  }
}
