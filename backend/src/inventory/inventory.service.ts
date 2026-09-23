import {
  BadRequestException,
  Injectable,
  NotFoundException,
  OnModuleInit,
} from '@nestjs/common';
import { msg } from '../common/i18n/locale-context.js';
import { InjectRepository } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { DataSource, Repository } from 'typeorm';
import { InventoryProduct } from '../database/entities/inventory-product.entity.js';
import { InventorySale } from '../database/entities/inventory-sale.entity.js';
import { InventoryStockMovement } from '../database/entities/inventory-stock-movement.entity.js';
import { InventoryTreasury } from '../database/entities/inventory-treasury.entity.js';
import { InventoryCategory, InventoryMovementType } from '../database/enums.js';
import { ReversalDto } from '../common/dto/reversal.dto.js';
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
    @InjectRepository(InventoryStockMovement)
    private readonly movements: Repository<InventoryStockMovement>,
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
        costPrice: 1400,
      }),
      this.products.create({
        name: 'جراب سيليكون سامسونج A15',
        category: InventoryCategory.CASE,
        stockQty: 25,
        soldQty: 0,
        defaultPrice: 75,
        costPrice: 40,
      }),
      this.products.create({
        name: 'سماعة سلكية Type-C',
        category: InventoryCategory.ACCESSORY,
        stockQty: 40,
        soldQty: 0,
        defaultPrice: 120,
        costPrice: 70,
      }),
      this.products.create({
        name: 'موبايل مستعمل — اختبار',
        category: InventoryCategory.MOBILE,
        stockQty: 3,
        soldQty: 0,
        defaultPrice: 4500,
        costPrice: 3800,
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

  async createProduct(dto: CreateInventoryProductDto, username: string) {
    return this.dataSource.transaction(async (manager) => {
      const repo = manager.getRepository(InventoryProduct);
      const product = await repo.save(
        repo.create({
          name: dto.name,
          category: dto.category,
          stockQty: dto.openingStock,
          soldQty: 0,
          defaultPrice: dto.defaultPrice,
          costPrice: dto.costPrice,
        }),
      );
      if (dto.openingStock > 0) {
        await manager.getRepository(InventoryStockMovement).save({
          productId: product.id,
          type: InventoryMovementType.OPENING,
          quantity: dto.openingStock,
          unitCost: dto.costPrice,
          supplier: null,
          note: msg({ ar: 'رصيد افتتاحي للمخزون', en: 'Opening inventory balance' }),
          performedBy: username,
        });
      }
      return this.serializeProduct(product);
    });
  }

  async stockIn(id: string, dto: StockInDto, username: string) {
    return this.dataSource.transaction(async (manager) => {
      const repo = manager.getRepository(InventoryProduct);
      const product = await repo.findOne({
        where: { id, active: true },
        lock: { mode: 'pessimistic_write' },
      });
      if (!product) throw new NotFoundException(msg({ ar: 'الصنف غير موجود أو موقوف', en: 'Item not found or inactive' }));
      const previousQty = product.stockQty;
      const incomingCost = dto.unitCost ?? product.costPrice;
      const nextQty = previousQty + dto.quantity;
      if (dto.unitCost != null && nextQty > 0) {
        product.costPrice = Number(
          (
            (previousQty * product.costPrice + dto.quantity * dto.unitCost) /
            nextQty
          ).toFixed(2),
        );
      }
      product.stockQty = nextQty;
      await repo.save(product);
      await manager.getRepository(InventoryStockMovement).save({
        productId: product.id,
        type: InventoryMovementType.STOCK_IN,
        quantity: dto.quantity,
        unitCost: incomingCost,
        supplier: dto.supplier ?? null,
        note: dto.note ?? null,
        performedBy: username,
      });
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
      if (!product) throw new NotFoundException(msg({ ar: 'الصنف غير موجود أو موقوف', en: 'Item not found or inactive' }));
      if (product.stockQty < dto.quantity) {
        throw new BadRequestException({
          message: msg({ ar: 'الكمية المطلوبة أكبر من المتاح في المخزن', en: 'Requested quantity exceeds available stock' }),
          available: product.stockQty,
        });
      }

      const totalAmount = Number((dto.quantity * dto.unitPrice).toFixed(2));
      const grossProfit = Number(
        (dto.quantity * (dto.unitPrice - product.costPrice)).toFixed(2),
      );
      product.stockQty -= dto.quantity;
      product.soldQty += dto.quantity;
      await productRepo.save(product);

      const sale = await saleRepo.save(
        saleRepo.create({
          productId: product.id,
          quantity: dto.quantity,
          unitPrice: dto.unitPrice,
          totalAmount,
          unitCost: product.costPrice,
          grossProfit,
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
      await manager.getRepository(InventoryStockMovement).save({
        productId: product.id,
        type: InventoryMovementType.SALE,
        quantity: -dto.quantity,
        unitCost: product.costPrice,
        supplier: null,
        note: dto.note ?? null,
        performedBy: username,
      });

      return {
        sale: {
          id: sale.id,
          productId: product.id,
          productName: product.name,
          quantity: sale.quantity,
          unitPrice: sale.unitPrice,
          totalAmount: sale.totalAmount,
          unitCost: sale.unitCost,
          grossProfit: sale.grossProfit,
          note: sale.note,
          performedBy: sale.performedBy,
          createdAt: sale.createdAt,
        },
        product: this.serializeProduct(product),
        inventoryTreasuryBalance: box.balance,
        message:
          msg({ ar: 'تم تسجيل البيع وإضافة المبلغ إلى خزنة المخزن (منفصلة عن خزنة الكاش)', en: 'Sale recorded and amount added to inventory treasury (separate from cash treasury)' }),
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
      unitCost: sale.unitCost,
      grossProfit: sale.grossProfit,
      reversedAt: sale.reversedAt,
      reversalReason: sale.reversalReason,
      note: sale.note,
      performedBy: sale.performedBy,
      createdAt: sale.createdAt,
    }));
  }

  async findMovements(limit = 100) {
    const rows = await this.movements.find({
      relations: { product: true },
      order: { createdAt: 'DESC' },
      take: Math.min(Math.max(limit, 1), 500),
    });
    return rows.map((row) => ({
      id: row.id,
      productId: row.productId,
      productName: row.product?.name ?? '—',
      type: row.type,
      quantity: row.quantity,
      unitCost: row.unitCost,
      supplier: row.supplier,
      note: row.note,
      performedBy: row.performedBy,
      createdAt: row.createdAt,
    }));
  }

  async treasurySummary() {
    const box = await this.treasury.findOne({ where: { id: 'inventory' } });
    const products = await this.products.find({ where: { active: true } });
    const totals = await this.sales
      .createQueryBuilder('sale')
      .select('COUNT(sale.id)', 'count')
      .addSelect('COALESCE(SUM(sale.totalAmount), 0)', 'total')
      .addSelect('COALESCE(SUM(sale.quantity), 0)', 'units')
      .addSelect('COALESCE(SUM(sale.grossProfit), 0)', 'profit')
      .where('sale.reversed_at IS NULL')
      .getRawOne<{
        count: string;
        total: string;
        units: string;
        profit: string;
      }>();
    const today = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Africa/Cairo',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).format(new Date());
    const todayTotals = await this.sales
      .createQueryBuilder('sale')
      .select('COUNT(sale.id)', 'count')
      .addSelect('COALESCE(SUM(sale.totalAmount), 0)', 'total')
      .where('sale.reversed_at IS NULL')
      .andWhere(
        `(sale.created_at AT TIME ZONE 'Africa/Cairo')::date = :today`,
        {
          today,
        },
      )
      .getRawOne<{ count: string; total: string }>();

    const stockUnits = products.reduce((sum, p) => sum + p.stockQty, 0);
    const soldUnits = products.reduce((sum, p) => sum + p.soldQty, 0);

    return {
      balance: box?.balance ?? 0,
      stockUnits,
      soldUnits,
      productCount: products.length,
      salesCount: Number(totals?.count ?? 0),
      salesTotal: Number(totals?.total ?? 0),
      grossProfit: Number(totals?.profit ?? 0),
      soldUnitsRecorded: Number(totals?.units ?? 0),
      todaySalesCount: Number(todayTotals?.count ?? 0),
      todaySalesAmount: Number(todayTotals?.total ?? 0),
      isolatedFromCashTreasury: true,
      note: msg({ ar: 'خزنة المخزن مستقلة تمامًا عن خزنة الكاش المركزية', en: 'Inventory treasury is completely separate from the central cash treasury' }),
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
      costPrice: product.costPrice,
      active: product.active,
      createdAt: product.createdAt,
      updatedAt: product.updatedAt,
    };
  }

  async reverseSale(id: string, dto: ReversalDto, username: string) {
    return this.dataSource.transaction(async (manager) => {
      const saleRepo = manager.getRepository(InventorySale);
      const sale = await saleRepo.findOne({
        where: { id },
        lock: { mode: 'pessimistic_write' },
      });
      if (!sale) throw new NotFoundException(msg({ ar: 'عملية البيع غير موجودة', en: 'Sale not found' }));
      if (sale.reversedAt) throw new BadRequestException(msg({ ar: 'تم عكس البيع بالفعل', en: 'Sale already reversed' }));

      const product = await manager.getRepository(InventoryProduct).findOne({
        where: { id: sale.productId },
        lock: { mode: 'pessimistic_write' },
      });
      const box = await manager.getRepository(InventoryTreasury).findOne({
        where: { id: 'inventory' },
        lock: { mode: 'pessimistic_write' },
      });
      if (!product || !box)
        throw new NotFoundException(msg({ ar: 'بيانات البيع غير مكتملة', en: 'Sale data is incomplete' }));
      if (box.balance < sale.totalAmount) {
        throw new BadRequestException(msg({ ar: 'رصيد خزنة المخزن لا يكفي لعكس البيع', en: 'Inventory treasury balance is insufficient to reverse the sale' }));
      }

      product.stockQty += sale.quantity;
      product.soldQty -= sale.quantity;
      box.balance = Number((box.balance - sale.totalAmount).toFixed(2));
      sale.reversedAt = new Date();
      sale.reversalReason = dto.reason;
      await manager.getRepository(InventoryProduct).save(product);
      await manager.getRepository(InventoryTreasury).save(box);
      await saleRepo.save(sale);
      await manager.getRepository(InventoryStockMovement).save({
        productId: product.id,
        type: InventoryMovementType.REVERSAL,
        quantity: sale.quantity,
        unitCost: sale.unitCost,
        supplier: null,
        note: dto.reason,
        performedBy: username,
      });
      return { reversed: true, saleId: sale.id, reason: dto.reason };
    });
  }
}
