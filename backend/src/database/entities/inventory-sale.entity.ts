import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { decimalTransformer } from '../decimal.transformer.js';
import { InventoryProduct } from './inventory-product.entity.js';

@Entity('inventory_sales')
export class InventorySale {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => InventoryProduct, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'product_id' })
  product: InventoryProduct;

  @Column({ name: 'product_id' })
  productId: string;

  @Column({ type: 'int' })
  quantity: number;

  @Column({
    name: 'unit_price',
    type: 'numeric',
    precision: 16,
    scale: 2,
    transformer: decimalTransformer,
  })
  unitPrice: number;

  @Column({
    name: 'total_amount',
    type: 'numeric',
    precision: 16,
    scale: 2,
    transformer: decimalTransformer,
  })
  totalAmount: number;

  @Column({
    name: 'unit_cost',
    type: 'numeric',
    precision: 16,
    scale: 2,
    default: 0,
    transformer: decimalTransformer,
  })
  unitCost: number;

  @Column({
    name: 'gross_profit',
    type: 'numeric',
    precision: 16,
    scale: 2,
    default: 0,
    transformer: decimalTransformer,
  })
  grossProfit: number;

  @Column({ type: 'varchar', length: 200, nullable: true })
  note: string | null;

  @Column({ name: 'performed_by', length: 80 })
  performedBy: string;

  @Column({ name: 'reversed_at', type: 'timestamptz', nullable: true })
  reversedAt: Date | null;

  @Column({
    name: 'reversal_reason',
    type: 'varchar',
    length: 300,
    nullable: true,
  })
  reversalReason: string | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
