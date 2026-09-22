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

  @Column({ type: 'varchar', length: 200, nullable: true })
  note: string | null;

  @Column({ name: 'performed_by', length: 80 })
  performedBy: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
