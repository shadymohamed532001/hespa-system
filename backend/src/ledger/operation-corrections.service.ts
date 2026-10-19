import { DailyClose } from '../database/entities/daily-close.entity.js';
import { cairoPeriod } from '../wallets/wallets.service.js';
import { CORRECTION_ENTRY_IDS } from './correction-entries.subscriber.js';
import { InventoryService } from '../inventory/inventory.service.js';
import { InventorySale } from '../database/entities/inventory-sale.entity.js';
import { InventoryProduct } from '../database/entities/inventory-product.entity.js';
import { SellProductDto } from '../inventory/dto/sell-product.dto.js';
import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { DataSource, EntityManager, In, Not } from 'typeorm';
import { plainToInstance } from 'class-transformer';
import { validate, isUUID } from 'class-validator';
import { AccountsService } from '../accounts/accounts.service.js';
import { WalletsService } from '../wallets/wallets.service.js';
import { MachinesService } from '../machines/machines.service.js';
import { TreasuryService } from '../treasury/treasury.service.js';
import { PurchaseVisasService } from '../purchase-visas/purchase-visas.service.js';
import { CollectionsService } from '../collections/collections.service.js';
import { LedgerService } from './ledger.service.js';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { FinancialAccount } from '../database/entities/financial-account.entity.js';
import { Wallet } from '../database/entities/wallet.entity.js';
import { Machine } from '../database/entities/machine.entity.js';
import { PurchaseVisa } from '../database/entities/purchase-visa.entity.js';
import { Treasury } from '../database/entities/treasury.entity.js';
import { Collection } from '../database/entities/collection.entity.js';
import { FawryDailyDrop } from '../database/entities/fawry-daily-drop.entity.js';
import { CollectionStatus, LedgerCategory } from '../database/enums.js';
import { TopUpAccountDto } from '../accounts/dto/top-up-account.dto.js';
import { RecordFawryDepositDto } from '../accounts/dto/record-fawry-deposit.dto.js';
import { ProfitQrCashOutDto } from '../accounts/dto/profit-qr-cash-out.dto.js';
import { CustomerWalletOperationDto } from '../wallets/dto/customer-wallet-operation.dto.js';
import { UseMachineDto } from '../machines/dto/use-machine.dto.js';
import { InternalTransferDto } from '../treasury/dto/internal-transfer.dto.js';
import { ReconcileDto } from '../treasury/dto/reconcile.dto.js';
import { WithdrawPurchaseVisaDto } from '../purchase-visas/dto/purchase-visa.dto.js';
import { ReceiveCollectionDto } from '../collections/dto/receive-collection.dto.js';
import { ReversalDto } from '../common/dto/reversal.dto.js';
import { CorrectionDto } from './correction.dto.js';
import {
  agentCreditBalance,
  lockAgentCredit,
} from '../collections/collections.service.js';
import { OpenAgentCreditDto } from '../collections/dto/open-agent-credit.dto.js';
import { PayAgentCreditDto } from '../collections/dto/pay-agent-credit.dto.js';
import { reverseCollection } from './collection-reversal.js';

// Forms describe business inputs; balances, computed commissions and ledger IDs
// never come from the client. Replacements use the same validated business logic.
type Field = {
  key: string;
  label: string;
  type: 'number' | 'text' | 'select' | 'boolean';
  options?: { value: string; label: string }[];
};
type Plan = {
  entry: LedgerEntry;
  kind: string;
  values: Record<string, any>;
  fields: Field[];
  collection?: Collection;
  blocked?: string;
};
const numberField = (key: string, label: string): Field => ({
  key,
  label,
  type: 'number',
});
const textField = (key: string, label: string): Field => ({
  key,
  label,
  type: 'text',
});
const choices = (
  key: string,
  label: string,
  values: Record<string, string>,
): Field => ({
  key,
  label,
  type: 'select',
  options: Object.entries(values).map(([value, label]) => ({ value, label })),
});
const relationKeys = [
  'profitSourceEntryId',
  'customerWalletTransferEntryId',
  'profitQrCashOutEntryId',
  'machineUsageEntryId',
  'walletUsageEntryId',
  'purchaseVisaUsageEntryId',
];

@Injectable()
export class OperationCorrectionsService {
  constructor(
    private readonly inventory: InventoryService,
    private readonly source: DataSource,
    private readonly ledger: LedgerService,
    private readonly accounts: AccountsService,
    private readonly wallets: WalletsService,
    private readonly machines: MachinesService,
    private readonly treasury: TreasuryService,
    private readonly visas: PurchaseVisasService,
    private readonly collections: CollectionsService,
  ) {}

  private async runCorrection<T>(
    work: (manager: EntityManager) => Promise<T>,
  ): Promise<T> {
    for (let attempt = 0; ; attempt++) {
      try {
        return await this.source.transaction('SERIALIZABLE', work);
      } catch (error) {
        const code = (error as { code?: string }).code;
        if (code !== '40001' && code !== '40P01') throw error;
        if (attempt >= 2)
          throw new ConflictException(
            'العملية اتغيرت أثناء الحفظ؛ افتحها من جديد وحاول مرة تانية',
          );
      }
    }
  }

  async describeSale(id: string) {
    const sale = await this.source
      .getRepository(InventorySale)
      .findOneBy({ id });
    if (!sale) throw new NotFoundException('عملية البيع غير موجودة');
    const products = await this.source
      .getRepository(InventoryProduct)
      .find({ order: { name: 'ASC' } });
    return {
      description: 'تصحيح بيع المخزون (خزنة المخزن مستقلة)',
      blocked: sale.reversedAt ? 'عملية البيع ملغية بالفعل' : null,
      values: {
        productId: sale.productId,
        quantity: sale.quantity,
        unitPrice: Number(sale.unitPrice),
        note: sale.note ?? '',
      },
      fields: [
        {
          key: 'productId',
          label: 'الصنف',
          type: 'select',
          options: products.map((p) => ({ value: p.id, label: p.name })),
        },
        numberField('quantity', 'الكمية'),
        numberField('unitPrice', 'سعر الوحدة'),
        textField('note', 'ملاحظات'),
      ],
    };
  }

  async cancelSale(id: string, dto: ReversalDto, username: string) {
    return this.runCorrection((manager) =>
      this.inventory.reverseSale(id, dto, username, manager),
    );
  }

  async correctSale(id: string, dto: CorrectionDto, username: string) {
    return this.runCorrection(async (manager) => {
      const sale = await manager
        .getRepository(InventorySale)
        .findOne({ where: { id }, lock: { mode: 'pessimistic_write' } });
      if (!sale) throw new NotFoundException('عملية البيع غير موجودة');
      if (
        Object.keys(dto.values).some(
          (k) => !['productId', 'quantity', 'unitPrice', 'note'].includes(k),
        )
      )
        throw new BadRequestException('حقول تعديل البيع غير صالحة');
      const { productId = sale.productId, ...values } = dto.values;
      if (typeof productId !== 'string' || !isUUID(productId))
        throw new BadRequestException('الصنف غير صالح');
      const input = await this.checked(SellProductDto, {
        quantity: sale.quantity,
        unitPrice: Number(sale.unitPrice),
        note: sale.note ?? '',
        ...values,
      });
      await this.inventory.reverseSale(
        id,
        { reason: dto.reason },
        username,
        manager,
      );
      return this.inventory.sell(
        productId,
        input,
        username,
        manager,
        productId === sale.productId ? Number(sale.unitCost) : undefined,
      );
    });
  }

  private async plan(id: string, manager: EntityManager): Promise<Plan> {
    const repo = manager.getRepository(LedgerEntry);
    let entry = await repo.findOne({ where: { id } });
    if (!entry) throw new NotFoundException('العملية غير موجودة');
    const parent = relationKeys
      .map((key) => entry!.metadata?.[key])
      .find((value) => typeof value === 'string');
    if (parent) {
      entry = await repo.findOne({ where: { id: String(parent) } });
      if (!entry)
        throw new BadRequestException('العملية الأصلية المرتبطة غير موجودة');
    }
    const m = entry.metadata ?? {};
    const p: Plan = { entry, kind: '', values: {}, fields: [] };
    if (
      entry.category === LedgerCategory.REVERSAL ||
      (await repo.exists({ where: { reversesEntryId: entry.id } }))
    ) {
      p.blocked = 'العملية ملغية بالفعل؛ اختار العملية البديلة لو عايز تصححها';
      return p;
    }
    const collectionId =
      m.collectionId ??
      (entry.entityType === 'collection' ? entry.entityId : undefined);
    let collection = collectionId
      ? await manager.getRepository(Collection).findOne({
          where: { id: typeof collectionId === 'string' ? collectionId : '' },
        })
      : null;
    if (
      !collection &&
      entry.reference &&
      [
        LedgerCategory.COMPANY_EXECUTION,
        LedgerCategory.COMMISSION,
        LedgerCategory.CASH_RECEIPT,
      ].includes(entry.category)
    )
      collection = await manager
        .getRepository(Collection)
        .findOne({ where: { reference: entry.reference } });
    if (collection) return this.collectionPlan(entry, collection, manager);
    if (entry.category === LedgerCategory.TOP_UP && m.fawryDeposit) {
      p.kind = 'fawry_deposit';
      p.values = {
        assetId: entry.entityId,
        depositorName: m.depositorName,
        cashCounts: m.cashCounts,
        reference: entry.reference ?? '',
      };
      p.fields = [
        await this.assetField(manager, 'assetId', 'الحساب', 'account'),
        textField('depositorName', 'اسم المودع'),
        ...[200, 100, 50, 20, 10, 5].map((n) =>
          numberField(`cashCounts.count${n}`, `عدد أوراق ${n} جنيه`),
        ),
        textField('reference', 'المرجع'),
      ];
    } else if (entry.category === LedgerCategory.TOP_UP) {
      p.kind = 'top_up';
      p.values = {
        assetId: entry.entityId,
        amount: Number(entry.amount),
        reference: entry.reference ?? '',
      };
      p.fields = [
        await this.assetField(
          manager,
          'assetId',
          'الحساب / المحفظة / الماكينة',
          entry.entityType,
        ),
        numberField('amount', 'المبلغ'),
        textField('reference', 'المرجع'),
      ];
    } else if (
      entry.category === LedgerCategory.INTERNAL_TRANSFER &&
      m.customerWalletOperation
    ) {
      p.kind = 'customer_wallet';
      p.values = {
        assetId:
          entry.sourceType === 'wallet' ? entry.sourceId : entry.targetId,
        amount: Number(entry.amount),
        direction: m.direction,
        feePaymentMode: m.feePaymentMode ?? 'deducted',
        purpose: m.purpose ?? '',
        reference: entry.reference ?? '',
      };
      p.fields = [
        await this.assetField(manager, 'assetId', 'المحفظة', 'wallet'),
        numberField('amount', 'المبلغ'),
        choices('direction', 'الاتجاه', {
          send: 'تحويل لعميل',
          receive: 'استلام من عميل',
        }),
        choices('feePaymentMode', 'عمولة الاستلام', {
          deducted: 'مخصومة من المبلغ',
          separate: 'منفصلة',
        }),
        textField('purpose', 'الغرض'),
        textField('reference', 'المرجع'),
      ];
    } else if (
      entry.category === LedgerCategory.INTERNAL_TRANSFER &&
      m.profitQrCashOut
    ) {
      p.kind = 'qr_cash_out';
      p.values = {
        assetId: entry.targetId,
        cashAmount: Number(entry.amount),
        commissionMethod: m.commissionMethod ?? 'deduct',
        reference: entry.reference ?? '',
      };
      p.fields = [
        await this.assetField(manager, 'assetId', 'حساب مكسب QR', 'account'),
        numberField('cashAmount', 'المبلغ'),
        choices('commissionMethod', 'تحصيل العمولة', {
          cash: 'نقدًا',
          deduct: 'خصم من الكاش',
        }),
        textField('reference', 'المرجع'),
      ];
    } else if (entry.category === LedgerCategory.INTERNAL_TRANSFER) {
      p.kind = 'transfer';
      p.values = {
        fromType: entry.sourceType,
        fromId: entry.sourceId,
        toType: entry.targetType,
        toId: entry.targetId,
        amount: Number(entry.amount),
        reference: entry.reference ?? '',
      };
      p.fields = [
        await this.assetField(
          manager,
          'fromId',
          'المصدر',
          String(entry.sourceType),
        ),
        await this.assetField(
          manager,
          'toId',
          'الوجهة',
          String(entry.targetType),
        ),
        numberField('amount', 'المبلغ'),
        textField('reference', 'المرجع'),
      ];
    } else if (entry.category === LedgerCategory.MACHINE_USAGE) {
      p.kind = 'machine_usage';
      p.values = {
        assetId: entry.entityId,
        amount: Number(entry.amount),
        commission: m.commission,
        serviceType: m.serviceType,
        customerNumber: m.customerNumber ?? '',
        reference: entry.reference ?? '',
      };
      p.fields = [
        await this.assetField(manager, 'assetId', 'الماكينة', 'machine'),
        numberField('amount', 'المبلغ'),
        numberField('commission', 'العمولة'),
        textField('customerNumber', 'رقم العميل'),
        choices('serviceType', 'الخدمة', {
          mobile_credit: 'رصيد موبايل',
          mobile_package: 'باقة موبايل',
          landline_internet: 'إنترنت أرضي',
          landline_phone: 'تليفون أرضي',
          other: 'أخرى',
        }),
        textField('reference', 'المرجع'),
      ];
    } else if (entry.category === LedgerCategory.PURCHASE_VISA_USAGE) {
      p.kind = 'visa_usage';
      p.values = {
        assetId: entry.sourceId ?? m.visaId,
        amount: Number(m.principal),
        agentName: m.agentName,
        withService: m.withService,
        note: '',
      };
      p.fields = [
        await this.assetField(manager, 'assetId', 'الفيزا', 'purchase_visa'),
        numberField('amount', 'المبلغ'),
        textField('agentName', 'اسم المندوب'),
        { key: 'withService', label: 'بخدمة ماكينة', type: 'boolean' },
        textField('note', 'ملاحظات'),
      ];
    } else if (entry.category === LedgerCategory.RECONCILIATION) {
      p.kind = 'reconciliation';
      p.values = {
        assetType: entry.entityType,
        assetId: entry.entityId,
        countedBalance: m.countedBalance,
        note: m.note ?? '',
      };
      p.fields = [
        numberField('countedBalance', 'الرصيد الفعلي الصحيح'),
        textField('note', 'ملاحظات'),
      ];
    } else if (entry.category === LedgerCategory.OWNER_WITHDRAWAL) {
      p.kind = 'withdrawal';
      p.values = { amount: Math.abs(Number(entry.amount)), note: m.note ?? '' };
      p.fields = [
        numberField('amount', 'المبلغ المسحوب'),
        textField('note', 'ملاحظات'),
      ];
    } else if (
      entry.category === LedgerCategory.COMMISSION &&
      m.fawryDailyDrop
    ) {
      p.kind = 'fawry_drop';
      p.values = { amount: Number(entry.amount) };
      p.fields = [numberField('amount', 'نزلة العمولة الصحيحة')];
    } else if (
      entry.entityType === 'agent_credit' &&
      entry.category === LedgerCategory.OPENING_BALANCE
    ) {
      p.kind = 'agent_opening';
      p.values = {
        agentName: m.agentName,
        amount: Number(entry.amount),
        note: m.note ?? '',
      };
      p.fields = [
        textField('agentName', 'اسم المندوب'),
        numberField('amount', 'الآجل الافتتاحي'),
        textField('note', 'ملاحظات'),
      ];
    } else if (entry.entityType === 'agent_credit' && m.agentCreditPayment) {
      p.kind = 'agent_payment';
      p.values = { agentName: m.agentName, amount: Number(entry.amount) };
      p.fields = [
        textField('agentName', 'اسم المندوب'),
        numberField('amount', 'مبلغ السداد'),
      ];
    } else if (
      entry.category === LedgerCategory.OPENING_BALANCE &&
      ['account', 'wallet', 'machine', 'purchase_visa', 'treasury'].includes(
        entry.entityType,
      )
    ) {
      p.kind = 'opening';
      p.values = { amount: Number(entry.amount) };
      p.fields = [numberField('amount', 'الرصيد الافتتاحي الصحيح')];
    } else if (entry.category === LedgerCategory.DAILY_ROLLOVER) {
      p.kind = 'rollover';
      p.values = { note: '' };
      p.fields = [textField('note', 'ملاحظات الإقفال الصحيح')];
      if (!m.beforeCounters)
        p.blocked =
          'هذا إقفال قديم لا يحتوي على العدادات السابقة؛ لا يمكن إرجاعها بدقة آليًا';
      else if (m.businessDate !== cairoPeriod().day)
        p.blocked =
          'إقفال اليوم مرتبط بيوم سابق؛ لا يمكن استعادة عداداته بعد تغيير اليوم';
    } else if (entry.category === LedgerCategory.WALLET_USAGE) {
      p.kind = 'wallet_usage';
      p.values = {
        amount: Number(entry.amount),
        commission: m.commission,
        reference: entry.reference ?? '',
      };
      p.fields = [
        numberField('amount', 'المبلغ'),
        numberField('commission', 'العمولة'),
        textField('reference', 'المرجع'),
      ];
    } else {
      p.blocked =
        'بيانات هذه العملية لا تسمح بتصحيح آلي كامل؛ يلزم معالجة ارتباطاتها من شاشتها الأصلية';
    }
    return p;
  }

  private async collectionPlan(
    entry: LedgerEntry,
    collection: Collection,
    manager: EntityManager,
  ): Promise<Plan> {
    const p: Plan = { entry, kind: 'collection', values: {}, fields: [] };
    p.kind = 'collection';
    p.collection = collection;
    if (collection.status === CollectionStatus.REVERSED)
      p.blocked = 'عملية الاستلام ملغية بالفعل';
    p.values = {
      agentName: collection.agentName,
      companyName: collection.companyName,
      amount: Number(collection.amount),
      cashAmount: Number(collection.cashAmount ?? collection.amount),
      commission: Math.max(0, Number(collection.commission)),
      executionMode:
        collection.status === CollectionStatus.DONE ? 'immediate' : 'hold',
      accountId: collection.accountId ?? '',
      purchaseVisaId: collection.purchaseVisaId ?? '',
      withService: collection.withService ?? false,
      useAgentCredit: Number(collection.agentCreditChange) !== 0,
      receivedAt: collection.receivedAt.toISOString(),
      incomingParts: (collection.incomingSplits ?? []).map((s) => ({
        ...(s.walletId ? { walletId: s.walletId } : { accountId: s.accountId }),
        amount: Number(s.amount),
      })),
    };
    p.fields = [
      textField('agentName', 'اسم المندوب'),
      textField('companyName', 'الشركة'),
      numberField('amount', 'مبلغ التنفيذ'),
      numberField('cashAmount', 'الكاش المستلم'),
      numberField(
        'commission',
        'العمولة (تُحسب تلقائيًا لحسابات المكسب والفيزا)',
      ),
      choices('executionMode', 'التنفيذ', { immediate: 'فوري', hold: 'معلّق' }),
      await this.assetField(
        manager,
        'accountId',
        'حساب التنفيذ',
        'account',
        true,
      ),
      await this.assetField(
        manager,
        'purchaseVisaId',
        'فيزا التنفيذ',
        'purchase_visa',
        true,
      ),
      { key: 'withService', label: 'بخدمة ماكينة للفيزا', type: 'boolean' },
      { key: 'useAgentCredit', label: 'استخدام آجل المندوب', type: 'boolean' },
    ];
    for (let i = 0; i < p.values.incomingParts.length; i++) {
      const split = p.values.incomingParts[i];
      const key = split.walletId ? 'walletId' : 'accountId';
      p.fields.push(
        await this.assetField(
          manager,
          `incomingParts.${i}.${key}`,
          `وجهة الجزء ${i + 1}`,
          key === 'walletId' ? 'wallet' : 'account',
        ),
        numberField(`incomingParts.${i}.amount`, `مبلغ الجزء ${i + 1}`),
      );
    }
    if (collection.status === CollectionStatus.PENDING)
      p.fields = p.fields.filter(
        (f) => !['cashAmount', 'useAgentCredit'].includes(f.key),
      );
    return p;
  }

  private async receiptPlan(id: string, manager: EntityManager, lock = false) {
    const collection = await manager.getRepository(Collection).findOne({
      where: { id },
      ...(lock ? { lock: { mode: 'pessimistic_write' as const } } : {}),
    });
    if (!collection) throw new NotFoundException('عملية الاستلام غير موجودة');
    const entry = await manager.getRepository(LedgerEntry).findOne({
      where: {
        reference: collection.reference,
        category: Not(LedgerCategory.REVERSAL),
      },
      order: { createdAt: 'ASC' },
    });
    const original =
      entry ??
      Object.assign(new LedgerEntry(), {
        id: collection.id,
        category: LedgerCategory.CASH_RECEIPT,
        amount: 0,
        entityType: 'collection',
        entityId: collection.id,
        reference: collection.reference,
        description: `استلام ${collection.reference}`,
        createdAt: collection.createdAt,
        metadata: { collectionId: collection.id },
      });
    return this.collectionPlan(original, collection, manager);
  }

  async describeCollection(id: string) {
    const p = await this.receiptPlan(id, this.source.manager);
    return this.form(p);
  }

  async cancelCollection(id: string, dto: ReversalDto, username: string) {
    return this.runCorrection(async (manager) => {
      const p = await this.receiptPlan(id, manager, true);
      if (p.blocked) throw new BadRequestException(p.blocked);
      await this.undo(p, dto.reason, username, manager);
      return { cancelled: true, collectionId: id };
    });
  }

  async correctCollection(id: string, dto: CorrectionDto, username: string) {
    return this.runCorrection(async (manager) =>
      this.applyCorrection(
        await this.receiptPlan(id, manager, true),
        dto,
        username,
        manager,
      ),
    );
  }

  private async assetField(
    manager: EntityManager,
    key: string,
    label: string,
    type: string,
    optional = false,
  ): Promise<Field> {
    const entity = {
      account: FinancialAccount,
      wallet: Wallet,
      machine: Machine,
      purchase_visa: PurchaseVisa,
    }[type];
    const options: { value: string; label: string }[] = optional
      ? [{ value: '', label: 'بدون' }]
      : [];
    if (type === 'treasury') options.push({ value: 'main', label: 'الخزنة' });
    else if (entity) {
      const rows = await manager
        .getRepository<{ id: string; name: string; active: boolean }>(entity)
        .find({ order: { name: 'ASC' } });
      options.push(
        ...rows.map((row) => ({
          value: row.id,
          label: `${row.name}${row.active ? '' : ' (موقوف)'}`,
        })),
      );
    }
    return { key, label, type: 'select', options };
  }

  async describe(id: string) {
    const p = await this.plan(id, this.source.manager);
    return this.form(p);
  }

  private form(p: Plan) {
    return {
      operationId: p.entry.id,
      description: p.collection
        ? `استلام ${p.collection.reference} — ${p.collection.agentName} (كل أجزاء العملية)`
        : p.entry.description,
      values: p.values,
      fields: p.fields,
      blocked: p.blocked ?? null,
    };
  }

  async cancel(id: string, dto: ReversalDto, username: string) {
    return this.runCorrection(async (manager) => {
      const p = await this.lockPlan(id, manager);
      await this.undo(p, dto.reason, username, manager);
      return { cancelled: true, originalEntryId: p.entry.id };
    });
  }

  async correct(id: string, dto: CorrectionDto, username: string) {
    return this.runCorrection(async (manager) =>
      this.applyCorrection(
        await this.lockPlan(id, manager),
        dto,
        username,
        manager,
      ),
    );
  }

  private async applyCorrection(
    p: Plan,
    dto: CorrectionDto,
    username: string,
    manager: EntityManager,
  ) {
    if (p.blocked) throw new BadRequestException(p.blocked);
    const values = structuredClone(p.values);
    // Reject hidden properties and stale forms, including nested object injection.
    const allowed = new Set(p.fields.map((f) => f.key));
    for (const [key, value] of Object.entries(dto.values)) {
      if (
        !allowed.has(key) ||
        (value !== null &&
          !['string', 'number', 'boolean'].includes(typeof value))
      )
        throw new BadRequestException(
          'حقول التعديل غير صالحة؛ افتح العملية من جديد',
        );
      const field = p.fields.find((f) => f.key === key)!;
      if (
        field.type === 'select' &&
        !field.options?.some((o) => o.value === value)
      )
        throw new BadRequestException('اختيار غير صالح');
      if (field.type === 'boolean' && typeof value !== 'boolean')
        throw new BadRequestException('قيمة الاختيار غير صالحة');
      if (
        field.type === 'number' &&
        (typeof value !== 'number' || !Number.isFinite(value))
      )
        throw new BadRequestException('المبلغ غير صالح');
      if (field.type === 'text' && typeof value !== 'string')
        throw new BadRequestException('النص غير صالح');
      const parts = key.split('.');
      let target = values;
      for (const part of parts.slice(0, -1)) target = target[part];
      target[parts[parts.length - 1]] = value;
    }
    await this.undo(p, dto.reason, username, manager);
    const insertedIds: string[] = [];
    const runner = manager.queryRunner!;
    runner.data[CORRECTION_ENTRY_IDS] = insertedIds;
    try {
      await this.replace(p, values, username, manager);
    } finally {
      delete runner.data[CORRECTION_ENTRY_IDS];
    }
    const added = insertedIds.length
      ? await manager.getRepository(LedgerEntry).findBy({ id: In(insertedIds) })
      : [];
    for (const entry of added) {
      entry.metadata = {
        ...entry.metadata,
        correctedEntryId: p.entry.id,
        correctionReason: dto.reason,
      };
      await manager.save(entry);
    }
    return {
      corrected: true,
      originalEntryId: p.entry.id,
      replacementEntryIds: added.map((e) => e.id),
    };
  }

  private async lockPlan(id: string, manager: EntityManager) {
    let p = await this.plan(id, manager);
    await manager.getRepository(LedgerEntry).findOne({
      where: { id: p.entry.id },
      lock: { mode: 'pessimistic_write' },
    });
    p = await this.plan(id, manager);
    if (p.blocked) throw new BadRequestException(p.blocked);
    return p;
  }

  private async undo(
    p: Plan,
    reason: string,
    username: string,
    manager: EntityManager,
  ) {
    if (p.collection)
      return reverseCollection(manager, p.collection.id, reason, username);
    if (p.kind === 'rollover') {
      const [later] = await manager.query(
        'SELECT 1 FROM ledger_entries WHERE created_at > (SELECT created_at FROM ledger_entries WHERE id = $1) LIMIT 1',
        [p.entry.id],
      );
      if (later)
        throw new BadRequestException(
          'فيه عمليات اتسجلت بعد الإقفال؛ لازم معالجة ارتباطاتها قبل إلغاء الإقفال',
        );
      const close = await manager.getRepository(DailyClose).findOne({
        where: { id: String(p.entry.metadata?.dailyCloseId) },
        lock: { mode: 'pessimistic_write' },
      });
      if (!close) throw new BadRequestException('سجل الإقفال غير موجود');
      const counters = p.entry.metadata!.beforeCounters as {
        accounts: { id: string; openingBalance: number; todayTopUp: number }[];
        wallets: {
          id: string;
          openingBalance: number;
          todayTopUp: number;
          dailyTopUp: number;
          counterDay: string | null;
        }[];
      };
      for (const previous of counters.accounts) {
        const item = await manager.getRepository(FinancialAccount).findOne({
          where: { id: previous.id },
          lock: { mode: 'pessimistic_write' },
        });
        if (!item)
          throw new BadRequestException('حساب مرتبط بالإقفال غير موجود');
        Object.assign(item, previous);
        await manager.save(item);
      }
      for (const previous of counters.wallets) {
        const item = await manager.getRepository(Wallet).findOne({
          where: { id: previous.id },
          lock: { mode: 'pessimistic_write' },
        });
        if (!item)
          throw new BadRequestException('محفظة مرتبطة بالإقفال غير موجودة');
        Object.assign(item, previous);
        await manager.save(item);
      }
      await manager.getRepository(DailyClose).delete(close.id);
      const reversal = await this.reversalEntry(
        p.entry,
        reason,
        username,
        manager,
      );
      reversal.metadata = { ...reversal.metadata, dailyCloseSnapshot: close };
      await manager.getRepository(LedgerEntry).save(reversal);
      return;
    }
    if (p.kind === 'agent_opening' || p.kind === 'agent_payment') {
      const agentName =
        typeof p.entry.metadata?.agentName === 'string'
          ? p.entry.metadata.agentName
          : '';
      await lockAgentCredit(manager, agentName);
      if (p.kind === 'agent_payment') {
        const treasury = await manager.getRepository(Treasury).findOne({
          where: { id: 'main' },
          lock: { mode: 'pessimistic_write' },
        });
        if (!treasury || Number(treasury.balance) < Number(p.entry.amount))
          throw new BadRequestException('رصيد الخزنة لا يكفي لإلغاء السداد');
        treasury.balance = Number(
          (Number(treasury.balance) - Number(p.entry.amount)).toFixed(2),
        );
        await manager.save(treasury);
      }
      await this.reversalEntry(p.entry, reason, username, manager);
      if ((await agentCreditBalance(manager, agentName)) < 0)
        throw new BadRequestException(
          'تم استخدام آجل المندوب في عملية لاحقة؛ الغِ الارتباط أولًا',
        );
      return;
    }
    if (p.kind === 'opening') {
      await this.changeOpening(p.entry, -Number(p.entry.amount), manager);
      await this.reversalEntry(p.entry, reason, username, manager);
      return;
    }
    if (p.kind === 'fawry_drop') {
      const account = await manager.getRepository(FinancialAccount).findOne({
        where: { id: p.entry.entityId! },
        lock: { mode: 'pessimistic_write' },
      });
      const amount = Number(p.entry.amount);
      if (
        !account ||
        Number(account.balance) < amount ||
        Number(account.commissionBalance) < amount
      )
        throw new BadRequestException(
          'أرصدة الحساب لا تسمح بإلغاء نزلة العمولة',
        );
      account.balance = Number((Number(account.balance) - amount).toFixed(2));
      account.commissionBalance = Number(
        (Number(account.commissionBalance) - amount).toFixed(2),
      );
      await manager.save(account);
      // Drop rows are the current daily booking; the immutable ledger preserves history.
      await manager
        .getRepository(FawryDailyDrop)
        .delete({ ledgerEntryId: p.entry.id });
      await manager.getRepository(LedgerEntry).save({
        category: LedgerCategory.REVERSAL,
        amount: -amount,
        entityType: p.entry.entityType,
        entityId: p.entry.entityId,
        reference: p.entry.reference,
        description: `إلغاء: ${p.entry.description} — ${reason}`,
        performedBy: username,
        reversesEntryId: p.entry.id,
        metadata: { reason, originalCategory: p.entry.category },
      });
      return;
    }
    return this.ledger.reverse(p.entry.id, { reason }, username, manager);
  }

  private async reversalEntry(
    entry: LedgerEntry,
    reason: string,
    username: string,
    manager: EntityManager,
  ) {
    return manager.getRepository(LedgerEntry).save({
      category: LedgerCategory.REVERSAL,
      amount: -Number(entry.amount),
      entityType: entry.entityType,
      entityId: entry.entityId,
      reference: entry.reference,
      description: `إلغاء: ${entry.description} — ${reason}`,
      performedBy: username,
      reversesEntryId: entry.id,
      metadata: { reason, originalCategory: entry.category },
    });
  }

  private async changeOpening(
    entry: LedgerEntry,
    delta: number,
    manager: EntityManager,
  ) {
    // Do not rewrite the opening balance of a later closed day.
    const [closed] = await manager.query(
      'SELECT 1 FROM daily_closes WHERE closed_at >= $1 LIMIT 1',
      [entry.createdAt],
    );
    if (closed)
      throw new BadRequestException(
        'الرصيد الافتتاحي مرتبط بيوم مقفول؛ يلزم إلغاء الإقفال المرتبط أولًا',
      );
    const entity = {
      account: FinancialAccount,
      wallet: Wallet,
      machine: Machine,
      purchase_visa: PurchaseVisa,
      treasury: Treasury,
    }[entry.entityType];
    if (!entity || !entry.entityId)
      throw new BadRequestException('بيانات الرصيد الافتتاحي ناقصة');
    const item: any = await manager.getRepository(entity).findOne({
      where: { id: entry.entityId },
      lock: { mode: 'pessimistic_write' },
    });
    if (!item) throw new NotFoundException('الأصل غير موجود');
    const key = entry.entityType === 'machine' ? 'loadedBalance' : 'balance';
    const available =
      Number(item[key]) -
      (entry.entityType === 'machine' ? Number(item.usedBalance) : 0);
    if (available + delta < 0)
      throw new BadRequestException(
        'تم استخدام الرصيد الافتتاحي؛ الرصيد الحالي لا يكفي للإلغاء',
      );
    item[key] = Number((Number(item[key]) + delta).toFixed(2));
    if ('openingBalance' in item)
      item.openingBalance = Number(
        (Number(item.openingBalance) + delta).toFixed(2),
      );
    if (entry.entityType === 'account') {
      const limit =
        item.type === 'fawry'
          ? 5000000
          : item.type === 'profit' && !item.openLimit
            ? 1000000
            : Infinity;
      if (item.balance > limit)
        throw new BadRequestException('الرصيد يتجاوز الحد الأقصى للحساب');
    }
    await manager.getRepository(entity).save(item);
  }

  private async checked<T extends object>(
    type: new () => T,
    values: Record<string, any>,
  ): Promise<T> {
    const dto = plainToInstance(type, values);
    const errors = await validate(dto, {
      whitelist: true,
      forbidNonWhitelisted: true,
    });
    if (errors.length)
      throw new BadRequestException(
        errors.map(
          (e) =>
            Object.values(e.constraints ?? {}).join('، ') ||
            `بيانات ${e.property} غير صالحة`,
        ),
      );
    return dto;
  }

  private async replace(
    p: Plan,
    raw: Record<string, any>,
    username: string,
    manager: EntityManager,
  ) {
    const { assetId, ...v } = raw;
    if (p.kind === 'top_up') {
      const dto = await this.checked(TopUpAccountDto, v);
      if (p.entry.entityType === 'account')
        return this.accounts.topUp(assetId, dto, username, manager);
      if (p.entry.entityType === 'wallet')
        return this.wallets.topUp(assetId, dto, username, manager);
      if (p.entry.entityType === 'machine')
        return this.machines.load(assetId, dto, username, manager);
      if (p.entry.entityType === 'purchase_visa')
        return this.visas.topUp(assetId, dto, username, manager);
    }
    if (p.kind === 'fawry_deposit')
      return this.accounts.recordFawryDeposit(
        assetId,
        await this.checked(RecordFawryDepositDto, v),
        username,
        manager,
      );
    if (p.kind === 'customer_wallet') {
      if (v.direction === 'send') delete v.feePaymentMode;
      return this.wallets.customerOperation(
        assetId,
        await this.checked(CustomerWalletOperationDto, v),
        username,
        manager,
      );
    }
    if (p.kind === 'qr_cash_out')
      return this.accounts.profitQrCashOut(
        assetId,
        await this.checked(ProfitQrCashOutDto, v),
        username,
        manager,
      );
    if (p.kind === 'transfer') {
      if (v.fromType === 'treasury') delete v.fromId;
      if (v.toType === 'treasury') delete v.toId;
      return this.treasury.transfer(
        await this.checked(InternalTransferDto, v),
        username,
        manager,
      );
    }
    if (p.kind === 'machine_usage')
      return this.machines.use(
        assetId,
        await this.checked(UseMachineDto, v),
        username,
        manager,
      );
    if (p.kind === 'visa_usage')
      return this.visas.withdraw(
        assetId,
        await this.checked(WithdrawPurchaseVisaDto, v),
        username,
        manager,
      );
    if (p.kind === 'reconciliation')
      return this.treasury.reconcile(
        await this.checked(ReconcileDto, { ...v, assetId }),
        username,
        manager,
      );
    if (p.kind === 'withdrawal') {
      const { amount } = await this.checked(TopUpAccountDto, {
        amount: v.amount,
      });
      if (typeof v.note !== 'string' || v.note.length > 300)
        throw new BadRequestException('الملاحظات غير صالحة');
      const treasury = await manager
        .getRepository(Treasury)
        .findOneByOrFail({ id: 'main' });
      return this.treasury.withdraw(
        {
          mode: 'leave',
          leaveAmount: Number((Number(treasury.balance) - amount).toFixed(2)),
          note: v.note,
        },
        username,
        manager,
      );
    }
    if (p.kind === 'collection') {
      if (v.executionMode === 'hold') {
        if (v.incomingParts?.length || v.useAgentCredit)
          throw new BadRequestException(
            'الاستلام المقسم أو الآجل يحتاج تنفيذ فوري',
          );
        delete v.cashAmount;
        delete v.incomingParts;
        delete v.accountId;
        delete v.purchaseVisaId;
        delete v.withService;
        v.commission = 0;
      } else if (p.collection?.status === CollectionStatus.PENDING) {
        v.cashAmount = v.amount;
      }
      if (!v.accountId) delete v.accountId;
      if (!v.purchaseVisaId) delete v.purchaseVisaId;
      return this.collections.receive(
        await this.checked(ReceiveCollectionDto, v),
        username,
        manager,
      );
    }
    if (p.kind === 'fawry_drop') {
      const { amount } = await this.checked(TopUpAccountDto, {
        amount: v.amount,
      });
      // Keep the original business date when correcting a historical drop.
      return this.accounts.recordDailyDrop(
        p.entry.entityId!,
        amount,
        username,
        new Date(`${String(p.entry.metadata!.businessDate)}T12:00:00+02:00`),
        manager,
      );
    }
    if (p.kind === 'rollover') {
      if (typeof v.note !== 'string' || v.note.length > 300)
        throw new BadRequestException('الملاحظات غير صالحة');
      return this.treasury.closeDay({ note: v.note }, username, manager);
    }
    if (p.kind === 'agent_opening')
      return this.collections.openAgentCredit(
        await this.checked(OpenAgentCreditDto, v),
        username,
        manager,
      );
    if (p.kind === 'agent_payment')
      return this.collections.payAgentCredit(
        await this.checked(PayAgentCreditDto, v),
        username,
        manager,
      );
    if (p.kind === 'opening') {
      const { amount } = await this.checked(TopUpAccountDto, {
        amount: v.amount,
      });
      await this.changeOpening(p.entry, amount, manager);
      await manager.getRepository(LedgerEntry).save({
        category: LedgerCategory.OPENING_BALANCE,
        amount,
        entityType: p.entry.entityType,
        entityId: p.entry.entityId,
        reference: p.entry.reference,
        description: p.entry.description,
        performedBy: username,
      });
      return;
    }
    if (p.kind === 'wallet_usage') {
      const dto = await this.checked(UseMachineDto, {
        ...v,
        serviceType: 'other',
        customerNumber: 'legacy-wallet',
      });
      const wallet = await manager.getRepository(Wallet).findOne({
        where: { id: p.entry.entityId! },
        lock: { mode: 'pessimistic_write' },
      });
      if (!wallet || Number(wallet.balance) < dto.amount)
        throw new BadRequestException('رصيد المحفظة لا يكفي');
      wallet.balance = Number((Number(wallet.balance) - dto.amount).toFixed(2));
      wallet.commissionBalance = Number(
        (Number(wallet.commissionBalance) + dto.commission).toFixed(2),
      );
      await manager.save(wallet);
      const usage = await manager.getRepository(LedgerEntry).save({
        category: LedgerCategory.WALLET_USAGE,
        amount: dto.amount,
        entityType: 'wallet',
        entityId: wallet.id,
        reference: dto.reference ?? null,
        description: p.entry.description,
        performedBy: username,
        metadata: { commission: dto.commission },
      });
      if (dto.commission > 0)
        await manager.getRepository(LedgerEntry).save({
          category: LedgerCategory.COMMISSION,
          amount: dto.commission,
          entityType: 'wallet',
          entityId: wallet.id,
          reference: dto.reference ?? null,
          description: 'عمولة استخدام محفظة',
          performedBy: username,
          metadata: { walletUsageEntryId: usage.id },
        });
      return;
    }
    throw new BadRequestException('نوع العملية غير مدعوم للتعديل');
  }
}
