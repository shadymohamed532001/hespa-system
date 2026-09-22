import {
  BadRequestException,
  Injectable,
  NotFoundException,
  OnModuleInit,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { DataSource, Repository } from 'typeorm';
import { InventoryProduct } from '../database/entities/inventory-product.entity.js';
import { InventorySale } from '../database/entities/inventory-sale.entity.js';
import { InventoryTreasury } from '../database/entities/inventory-treasury.entity.js';
import { InventoryCategory } from '../database/enums.js';
import { CreateInventoryProductDto } from './dto/create-product.dto.js';
import { SellProductDto } from './dto/sell-product.dto.js';
import { StockInDto } from './dto/stock-in.dto.js';
import { shouldSeedDemoData } from '../config/demo-data.js';

@Injectable()
export class InventoryService implements OnModuleInit {
  constructor(
    @InjectRepository(InventoryProduct)
    private readonly products: Repository<InventoryProduct>,
    @InjectRepository(InventorySale)
    private readonly sales: Repository<InventorySale>,
    @InjectRepository(InventoryTreasury)
    private readonly treasury: Repository<InventoryTreasury>,
    private readonly dataSource: DataSource,
    private readonly config: ConfigService,
  ) {}

  async onModuleInit() {
    let box = await this.treasury.findOne({ where: { id: 'inventory' } });
    if (!box) {
      box = await this.treasury.save(
        this.treasury.create({ id: 'inventory', balance: 0 }),
      );
    }

    if (!shouldSeedDemoData(this.config) || (await this.products.count()))
      return;

    await this.products.save([
      this.products.create({
        name: 'شاشة آيفون 11',
        category: InventoryCategory.SCREEN,
        stockQty: 8,
        soldQty: 0,
        defaultPrice: 1850,
      }),
      this.products.create({
        name: 'جراب سيليكون سامسونج A15',
        category: InventoryCategory.CASE,
        stockQty: 25,
        soldQty: 0,
        defaultPrice: 75,
      }),
      this.products.create({
        name: 'سماعة سلكية Type-C',
        category: InventoryCategory.ACCESSORY,
        stockQty: 40,
        soldQty: 0,
        defaultPrice: 120,
      }),
      this.products.create({
        name: 'موبايل مستعمل — اختبار',
        category: InventoryCategory.MOBILE,
        stockQty: 3,
        soldQty: 0,
        defaultPrice: 4500,
      }),
    ]);
  }

  async findProducts() {
    const items = await this.products.find({
      where: { active: true },
      order: { createdAt: 'ASC' },
    });
    return items.map((item) => this.serializeProduct(item));
  }

  async createProduct(dto: CreateInventoryProductDto) {
    const product = await this.products.save(
      this.products.create({
        name: dto.name,
        category: dto.category,
        stockQty: dto.openingStock,
        soldQty: 0,
        defaultPrice: dto.defaultPrice,
      }),
    );
    return this.serializeProduct(product);
  }

  async stockIn(id: string, dto: StockInDto) {
    return this.dataSource.transaction(async (manager) => {
      const repo = manager.getRepository(InventoryProduct);
      const product = await repo.findOne({
        where: { id, active: true },
        lock: { mode: 'pessimistic_write' },
      });
      if (!product) throw new NotFoundException('الصنف غير موجود أو موقوف');
      product.stockQty += dto.quantity;
      await repo.save(product);
      return this.serializeProduct(product);
    });
  }

  async sell(id: string, dto: SellProductDto, username: string) {
    return this.dataSource.transaction(async (manager) => {
      const productRepo = manager.getRepository(InventoryProduct);
      const saleRepo = manager.getRepository(InventorySale);
      const treasuryRepo = manager.getRepository(InventoryTreasury);

      const product = await productRepo.findOne({
        where: { id, active: true },
        lock: { mode: 'pessimistic_write' },
      });
      if (!product) throw new NotFoundException('الصنف غير موجود أو موقوف');
      if (product.stockQty < dto.quantity) {
        throw new BadRequestException({
          message: 'الكمية المطلوبة أكبر من المتاح في المخزن',
          available: product.stockQty,
        });
      }

      const totalAmount = Number((dto.quantity * dto.unitPrice).toFixed(2));
      product.stockQty -= dto.quantity;
      product.soldQty += dto.quantity;
      await productRepo.save(product);

      const sale = await saleRepo.save(
        saleRepo.create({
          productId: product.id,
          quantity: dto.quantity,
          unitPrice: dto.unitPrice,
          totalAmount,
          note: dto.note ?? null,
          performedBy: username,
        }),
      );

      let box = await treasuryRepo.findOne({
        where: { id: 'inventory' },
        lock: { mode: 'pessimistic_write' },
      });
      if (!box) {
        box = treasuryRepo.create({ id: 'inventory', balance: 0 });
      }
      box.balance = Number((box.balance + totalAmount).toFixed(2));
      await treasuryRepo.save(box);

      return {
        sale: {
          id: sale.id,
          productId: product.id,
          productName: product.name,
          quantity: sale.quantity,
          unitPrice: sale.unitPrice,
          totalAmount: sale.totalAmount,
          note: sale.note,
          performedBy: sale.performedBy,
          createdAt: sale.createdAt,
        },
        product: this.serializeProduct(product),
        inventoryTreasuryBalance: box.balance,
        message:
          'تم تسجيل البيع وإضافة المبلغ إلى خزنة المخزن (منفصلة عن خزنة الكاش)',
      };
    });
  }

  async findSales(limit = 50) {
    const take = Math.min(Math.max(limit, 1), 200);
    const rows = await this.sales.find({
      relations: { product: true },
      order: { createdAt: 'DESC' },
      take,
    });
    return rows.map((sale) => ({
      id: sale.id,
      productId: sale.productId,
      productName: sale.product?.name ?? '—',
      category: sale.product?.category ?? null,
      quantity: sale.quantity,
      unitPrice: sale.unitPrice,
      totalAmount: sale.totalAmount,
      note: sale.note,
      performedBy: sale.performedBy,
      createdAt: sale.createdAt,
    }));
  }

  async treasurySummary() {
    const box = await this.treasury.findOne({ where: { id: 'inventory' } });
    const products = await this.products.find({ where: { active: true } });
    const sales = await this.sales.find({
      order: { createdAt: 'DESC' },
      take: 200,
    });

    const stockUnits = products.reduce((sum, p) => sum + p.stockQty, 0);
    const soldUnits = products.reduce((sum, p) => sum + p.soldQty, 0);
    const salesTotal = sales.reduce((sum, s) => sum + Number(s.totalAmount), 0);

    const today = new Date();
    const todaySales = sales.filter((s) => {
      const d = new Date(s.createdAt);
      return (
        d.getFullYear() === today.getFullYear() &&
        d.getMonth() === today.getMonth() &&
        d.getDate() === today.getDate()
      );
    });
    const todayAmount = todaySales.reduce(
      (sum, s) => sum + Number(s.totalAmount),
      0,
    );

    return {
      balance: box?.balance ?? 0,
      stockUnits,
      soldUnits,
      productCount: products.length,
      salesCount: sales.length,
      salesTotal,
      todaySalesCount: todaySales.length,
      todaySalesAmount: todayAmount,
      isolatedFromCashTreasury: true,
      note: 'خزنة المخزن مستقلة تمامًا عن خزنة الكاش المركزية',
    };
  }

  private serializeProduct(product: InventoryProduct) {
    return {
      id: product.id,
      name: product.name,
      category: product.category,
      stockQty: product.stockQty,
      soldQty: product.soldQty,
      remainingQty: product.stockQty,
      defaultPrice: product.defaultPrice,
      active: product.active,
      createdAt: product.createdAt,
      updatedAt: product.updatedAt,
    };
  }
}
