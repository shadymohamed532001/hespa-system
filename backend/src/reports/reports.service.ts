import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Between, Repository } from 'typeorm';
import { Collection } from '../database/entities/collection.entity.js';
import { FinancialAccount } from '../database/entities/financial-account.entity.js';
import { InventoryProduct } from '../database/entities/inventory-product.entity.js';
import { InventorySale } from '../database/entities/inventory-sale.entity.js';
import { InventoryTreasury } from '../database/entities/inventory-treasury.entity.js';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { Machine } from '../database/entities/machine.entity.js';
import { Treasury } from '../database/entities/treasury.entity.js';
import { Wallet } from '../database/entities/wallet.entity.js';
import { LedgerCategory } from '../database/enums.js';

type ReportScope = {
  start: Date;
  end: Date;
  entityType: string;
  entityId?: string;
};

type FlowKind =
  'deposit' | 'withdrawal' | 'commission' | 'transfer' | 'neutral';

type ReportOperation = {
  id: string;
  createdAt: Date;
  category: string;
  kind: FlowKind | 'sale';
  amount: number;
  entityType: string;
  entityId: string | null;
  entityName: string;
  description: string;
  reference: string | null;
  performedBy: string;
};

type ChannelRow = {
  entityType: string;
  entityId: string;
  name: string;
  kind: string;
  currentBalance: number;
  deposits: number;
  withdrawals: number;
  commissions: number;
  net: number;
  operationCount: number;
};

const round = (value: number) => Number(value.toFixed(2));

@Injectable()
export class ReportsService {
  constructor(
    @InjectRepository(LedgerEntry)
    private readonly ledger: Repository<LedgerEntry>,
    @InjectRepository(InventorySale)
    private readonly sales: Repository<InventorySale>,
    @InjectRepository(InventoryProduct)
    private readonly products: Repository<InventoryProduct>,
    @InjectRepository(InventoryTreasury)
    private readonly inventoryTreasury: Repository<InventoryTreasury>,
    @InjectRepository(Collection)
    private readonly collections: Repository<Collection>,
    @InjectRepository(FinancialAccount)
    private readonly accounts: Repository<FinancialAccount>,
    @InjectRepository(Wallet) private readonly wallets: Repository<Wallet>,
    @InjectRepository(Machine) private readonly machines: Repository<Machine>,
    @InjectRepository(Treasury) private readonly treasury: Repository<Treasury>,
  ) {}

  async summary(scope: ReportScope) {
    const inclusiveEnd = new Date(scope.end.getTime() - 1);
    const [
      ledger,
      sales,
      collections,
      accounts,
      wallets,
      machines,
      treasury,
      inventoryBox,
      products,
    ] = await Promise.all([
      this.ledger.find({
        where: { createdAt: Between(scope.start, inclusiveEnd) },
        order: { createdAt: 'DESC' },
      }),
      this.sales.find({
        where: { createdAt: Between(scope.start, inclusiveEnd) },
        relations: { product: true },
        order: { createdAt: 'DESC' },
      }),
      this.collections.find({
        where: { receivedAt: Between(scope.start, inclusiveEnd) },
        relations: { account: true },
        order: { receivedAt: 'DESC' },
      }),
      this.accounts.find({ order: { createdAt: 'ASC' } }),
      this.wallets.find({ order: { createdAt: 'ASC' } }),
      this.machines.find({ order: { createdAt: 'ASC' } }),
      this.treasury.findOne({ where: { id: 'main' } }),
      this.inventoryTreasury.findOne({ where: { id: 'inventory' } }),
      this.products.find({ order: { createdAt: 'ASC' } }),
    ]);

    const names = new Map<string, string>();
    names.set('treasury:main', 'الخزنة المركزية');
    names.set('inventory:inventory', 'خزنة المخزن');
    for (const item of accounts) names.set(`account:${item.id}`, item.name);
    for (const item of wallets) names.set(`wallet:${item.id}`, item.name);
    for (const item of machines) names.set(`machine:${item.id}`, item.name);

    const channels = new Map<string, ChannelRow>();
    const addChannel = (
      entityType: string,
      entityId: string,
      name: string,
      kind: string,
      currentBalance: number,
    ) => {
      const key = `${entityType}:${entityId}`;
      channels.set(key, {
        entityType,
        entityId,
        name,
        kind,
        currentBalance: round(currentBalance),
        deposits: 0,
        withdrawals: 0,
        commissions: 0,
        net: 0,
        operationCount: 0,
      });
    };

    addChannel(
      'treasury',
      'main',
      'الخزنة المركزية',
      'cash',
      Number(treasury?.balance ?? 0),
    );
    for (const item of accounts) {
      addChannel(
        'account',
        item.id,
        item.name,
        item.type,
        Number(item.balance),
      );
    }
    for (const item of wallets) {
      addChannel('wallet', item.id, item.name, item.type, Number(item.balance));
    }
    for (const item of machines) {
      addChannel(
        'machine',
        item.id,
        item.name,
        'machine',
        Number(item.loadedBalance) - Number(item.usedBalance),
      );
    }
    addChannel(
      'inventory',
      'inventory',
      'خزنة المخزن',
      'inventory',
      Number(inventoryBox?.balance ?? 0),
    );

    const matchesScope = (type: string, id: string | null) => {
      if (scope.entityType === 'all') return true;
      if (type !== scope.entityType) return false;
      return !scope.entityId || id === scope.entityId;
    };

    const channelFor = (type: string, id: string | null) =>
      id ? channels.get(`${type}:${id}`) : undefined;

    const applyFlow = (
      channel: ChannelRow | undefined,
      kind: FlowKind,
      amount: number,
    ) => {
      if (!channel) return;
      const value = Math.abs(Number(amount));
      if (kind === 'deposit') channel.deposits += value;
      if (kind === 'withdrawal') channel.withdrawals += value;
      if (kind === 'commission') channel.commissions += value;
      channel.operationCount += 1;
      channel.net = channel.deposits - channel.withdrawals;
    };

    const operations: ReportOperation[] = [];
    for (const entry of ledger) {
      if (entry.category === LedgerCategory.INTERNAL_TRANSFER) {
        const sourceMatch = Boolean(
          entry.sourceType && matchesScope(entry.sourceType, entry.sourceId),
        );
        const targetMatch = Boolean(
          entry.targetType && matchesScope(entry.targetType, entry.targetId),
        );
        const visible =
          scope.entityType === 'all' || sourceMatch || targetMatch;
        if (!visible) continue;

        applyFlow(
          channelFor(entry.sourceType ?? '', entry.sourceId),
          'withdrawal',
          entry.amount,
        );
        applyFlow(
          channelFor(entry.targetType ?? '', entry.targetId),
          'deposit',
          entry.amount,
        );

        const scopedKind: FlowKind =
          scope.entityType === 'all'
            ? 'transfer'
            : sourceMatch
              ? 'withdrawal'
              : targetMatch
                ? 'deposit'
                : 'transfer';
        operations.push({
          id: entry.id,
          createdAt: entry.createdAt,
          category: entry.category,
          kind: scopedKind,
          amount: Math.abs(Number(entry.amount)),
          entityType: 'internal_transfer',
          entityId: null,
          entityName: this.transferName(entry, names),
          description: entry.description,
          reference: entry.reference,
          performedBy: entry.performedBy,
        });
        continue;
      }

      const location = this.entryLocation(entry);
      if (!matchesScope(location.type, location.id)) continue;
      const kind = this.flowKind(entry);
      applyFlow(channelFor(location.type, location.id), kind, entry.amount);
      operations.push({
        id: entry.id,
        createdAt: entry.createdAt,
        category: entry.category,
        kind,
        amount: Math.abs(Number(entry.amount)),
        entityType: location.type,
        entityId: location.id,
        entityName:
          names.get(`${location.type}:${location.id}`) ?? entry.entityType,
        description: entry.description,
        reference: entry.reference,
        performedBy: entry.performedBy,
      });
    }

    const includeSales =
      scope.entityType === 'all' || scope.entityType === 'inventory';
    if (includeSales) {
      const inventoryChannel = channels.get('inventory:inventory');
      for (const sale of sales) {
        applyFlow(inventoryChannel, 'deposit', Number(sale.totalAmount));
        operations.push({
          id: sale.id,
          createdAt: sale.createdAt,
          category: 'inventory_sale',
          kind: 'sale',
          amount: Number(sale.totalAmount),
          entityType: 'inventory',
          entityId: 'inventory',
          entityName: 'خزنة المخزن',
          description: `بيع ${sale.quantity} × ${sale.product?.name ?? 'صنف'}`,
          reference: null,
          performedBy: sale.performedBy,
        });
      }
    }

    operations.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
    const visibleChannels = [...channels.values()]
      .filter((row) => matchesScope(row.entityType, row.entityId))
      .map((row) => ({
        ...row,
        deposits: round(row.deposits),
        withdrawals: round(row.withdrawals),
        commissions: round(row.commissions),
        net: round(row.deposits - row.withdrawals),
      }));

    // Across the whole system, internal transfers are neutral. For a selected
    // account/channel they are intentionally shown as money in or out.
    const deposits = round(
      scope.entityType === 'all'
        ? operations.reduce(
            (sum, row) =>
              sum +
              (row.kind === 'deposit' || row.kind === 'sale' ? row.amount : 0),
            0,
          )
        : visibleChannels.reduce((sum, row) => sum + row.deposits, 0),
    );
    const withdrawals = round(
      scope.entityType === 'all'
        ? operations.reduce(
            (sum, row) => sum + (row.kind === 'withdrawal' ? row.amount : 0),
            0,
          )
        : visibleChannels.reduce((sum, row) => sum + row.withdrawals, 0),
    );
    const commissions = round(
      scope.entityType === 'all'
        ? operations.reduce(
            (sum, row) => sum + (row.kind === 'commission' ? row.amount : 0),
            0,
          )
        : visibleChannels.reduce((sum, row) => sum + row.commissions, 0),
    );

    const scopedSales = includeSales ? sales : [];
    const scopedCollections = collections.filter((item) => {
      if (scope.entityType === 'all' || scope.entityType === 'treasury')
        return true;
      return (
        scope.entityType === 'account' &&
        (!scope.entityId || item.account?.id === scope.entityId)
      );
    });

    const daily = this.dailyRows(scope.start, scope.end, operations);
    const stockValue = products.reduce(
      (sum, product) =>
        sum + Number(product.stockQty) * Number(product.defaultPrice),
      0,
    );

    return {
      period: {
        from: scope.start.toISOString(),
        toExclusive: scope.end.toISOString(),
        days: Math.ceil(
          (scope.end.getTime() - scope.start.getTime()) / 86_400_000,
        ),
      },
      scope: { entityType: scope.entityType, entityId: scope.entityId ?? null },
      summary: {
        deposits,
        withdrawals,
        net: round(deposits - withdrawals),
        commissions,
        operationCount: operations.length,
        salesAmount: round(
          scopedSales.reduce((sum, sale) => sum + Number(sale.totalAmount), 0),
        ),
        salesCount: scopedSales.length,
        soldUnits: scopedSales.reduce((sum, sale) => sum + sale.quantity, 0),
        collectionsAmount: round(
          scopedCollections.reduce((sum, item) => sum + Number(item.amount), 0),
        ),
        collectionsCount: scopedCollections.length,
        pendingCollectionsCount: scopedCollections.filter(
          (item) => item.status === 'pending',
        ).length,
      },
      inventory: {
        currentBalance: round(Number(inventoryBox?.balance ?? 0)),
        stockUnits: products.reduce(
          (sum, product) => sum + product.stockQty,
          0,
        ),
        stockValue: round(stockValue),
      },
      channels: visibleChannels,
      daily,
      operations: operations.slice(0, 500),
      truncated: operations.length > 500,
    };
  }

  private entryLocation(entry: LedgerEntry) {
    if (entry.category === LedgerCategory.CASH_RECEIPT) {
      return { type: 'treasury', id: 'main' };
    }
    return { type: entry.entityType, id: entry.entityId };
  }

  private flowKind(entry: LedgerEntry): FlowKind {
    if (entry.category === LedgerCategory.COMMISSION) return 'commission';
    if (entry.category === LedgerCategory.COMPANY_EXECUTION)
      return 'withdrawal';
    if (entry.category === LedgerCategory.MACHINE_USAGE) return 'withdrawal';
    if (entry.category === LedgerCategory.REVERSAL) {
      return Number(entry.amount) >= 0 ? 'deposit' : 'withdrawal';
    }
    if (
      entry.category === LedgerCategory.TOP_UP ||
      entry.category === LedgerCategory.OPENING_BALANCE ||
      entry.category === LedgerCategory.CASH_RECEIPT
    ) {
      return 'deposit';
    }
    return 'neutral';
  }

  private transferName(entry: LedgerEntry, names: Map<string, string>) {
    if (
      !entry.sourceType ||
      !entry.sourceId ||
      !entry.targetType ||
      !entry.targetId
    ) {
      return 'تحويل داخلي (بيانات الأطراف غير متاحة)';
    }
    const source =
      names.get(`${entry.sourceType}:${entry.sourceId}`) ?? entry.sourceType;
    const target =
      names.get(`${entry.targetType}:${entry.targetId}`) ?? entry.targetType;
    return `${source} ← ${target}`;
  }

  private dailyRows(start: Date, end: Date, operations: ReportOperation[]) {
    const rows = new Map<
      string,
      {
        date: string;
        deposits: number;
        withdrawals: number;
        commissions: number;
        sales: number;
        operationCount: number;
      }
    >();
    for (const operation of operations) {
      const date = this.cairoDate(operation.createdAt);
      const row = rows.get(date) ?? {
        date,
        deposits: 0,
        withdrawals: 0,
        commissions: 0,
        sales: 0,
        operationCount: 0,
      };
      if (operation.kind === 'deposit') row.deposits += operation.amount;
      if (operation.kind === 'withdrawal') row.withdrawals += operation.amount;
      if (operation.kind === 'commission') row.commissions += operation.amount;
      if (operation.kind === 'sale') {
        row.deposits += operation.amount;
        row.sales += operation.amount;
      }
      row.operationCount += 1;
      rows.set(date, row);
    }

    const endDate = this.cairoDate(new Date(end.getTime() - 1));
    let date = this.cairoDate(start);
    while (date <= endDate) {
      if (!rows.has(date)) {
        rows.set(date, {
          date,
          deposits: 0,
          withdrawals: 0,
          commissions: 0,
          sales: 0,
          operationCount: 0,
        });
      }
      const cursor = new Date(`${date}T12:00:00Z`);
      cursor.setUTCDate(cursor.getUTCDate() + 1);
      date = cursor.toISOString().slice(0, 10);
    }

    return [...rows.values()]
      .sort((a, b) => b.date.localeCompare(a.date))
      .map((row) => ({
        ...row,
        deposits: round(row.deposits),
        withdrawals: round(row.withdrawals),
        commissions: round(row.commissions),
        sales: round(row.sales),
        net: round(row.deposits - row.withdrawals),
      }));
  }

  private cairoDate(value: Date) {
    const parts = new Intl.DateTimeFormat('en-US', {
      timeZone: 'Africa/Cairo',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).formatToParts(value);
    const part = (type: Intl.DateTimeFormatPartTypes) =>
      parts.find((item) => item.type === type)?.value ?? '';
    return `${part('year')}-${part('month')}-${part('day')}`;
  }
}
