import {
  BadRequestException,
  Injectable,
  NotFoundException,
  OnModuleInit,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { DataSource, Repository } from 'typeorm';
import { Collection } from '../database/entities/collection.entity.js';
import { FinancialAccount } from '../database/entities/financial-account.entity.js';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { Treasury } from '../database/entities/treasury.entity.js';
import {
  CollectionStatus,
  ExecutionMode,
  LedgerCategory,
} from '../database/enums.js';
import { ExecuteHoldDto } from './dto/execute-hold.dto.js';
import { ReceiveCollectionDto } from './dto/receive-collection.dto.js';
import { shouldSeedDemoData } from '../config/demo-data.js';
import { ReversalDto } from '../common/dto/reversal.dto.js';

@Injectable()
export class CollectionsService implements OnModuleInit {
  constructor(
    @InjectRepository(Collection)
    private readonly collections: Repository<Collection>,
    @InjectRepository(Treasury) private readonly treasury: Repository<Treasury>,
    private readonly dataSource: DataSource,
    private readonly config: ConfigService,
  ) {}

  async onModuleInit() {
    if (!(await this.treasury.exists({ where: { id: 'main' } }))) {
      await this.treasury.save({
        id: 'main',
        balance: shouldSeedDemoData(this.config) ? 148750 : 0,
      });
    }
    if (!shouldSeedDemoData(this.config)) return;
    if (await this.collections.count()) return;
    await this.collections.save({
      reference: 'HLD-001',
      agentName: 'أحمد علي',
      companyName: 'جهينة',
      amount: 50000,
      executionMode: ExecutionMode.HOLD,
      status: CollectionStatus.PENDING,
      receivedAt: new Date(),
      executedAt: null,
      account: null,
      commission: 0,
    });
  }

  findAll() {
    return this.collections.find({
      relations: { account: true },
      order: { createdAt: 'DESC' },
    });
  }

  async findOne(id: string) {
    const collection = await this.collections.findOne({
      where: { id },
      relations: { account: true },
    });
    if (!collection) throw new NotFoundException('التحصيل غير موجود');
    return collection;
  }

  async receive(dto: ReceiveCollectionDto, username: string) {
    if (dto.executionMode === ExecutionMode.IMMEDIATE && !dto.accountId) {
      throw new BadRequestException('الحساب المستخدم مطلوب للتنفيذ الفوري');
    }
    return this.dataSource.transaction(async (manager) => {
      // Reference generation must be serialized. count()+1 outside the
      // transaction allowed two simultaneous receipts to choose the same
      // unique reference and made one of them fail.
      await manager.query(
        `SELECT pg_advisory_xact_lock(hashtext('hesba:collection-reference'))`,
      );
      const referenceNumber =
        (await manager.getRepository(Collection).count()) + 1;
      const reference = `${dto.executionMode === ExecutionMode.HOLD ? 'HLD' : 'COL'}-${String(referenceNumber).padStart(3, '0')}`;

      const treasuryRepo = manager.getRepository(Treasury);
      const treasury = await treasuryRepo.findOne({
        where: { id: 'main' },
        lock: { mode: 'pessimistic_write' },
      });
      if (!treasury) throw new NotFoundException('الخزنة غير مهيأة');
      treasury.balance += dto.amount;
      await treasuryRepo.save(treasury);

      let account: FinancialAccount | null = null;
      if (dto.executionMode === ExecutionMode.IMMEDIATE) {
        account = await manager.getRepository(FinancialAccount).findOne({
          where: { id: dto.accountId, active: true },
          lock: { mode: 'pessimistic_write' },
        });
        if (!account)
          throw new NotFoundException('الحساب المستخدم غير موجود أو موقوف');
        if (account.balance < dto.amount)
          throw new BadRequestException('رصيد الحساب غير كافٍ');
        account.balance -= dto.amount;
        account.commissionBalance += dto.commission;
        await manager.getRepository(FinancialAccount).save(account);
      }

      const collection = await manager.getRepository(Collection).save({
        reference,
        agentName: dto.agentName,
        companyName: dto.companyName,
        amount: dto.amount,
        executionMode: dto.executionMode,
        status:
          dto.executionMode === ExecutionMode.IMMEDIATE
            ? CollectionStatus.DONE
            : CollectionStatus.PENDING,
        receivedAt: dto.receivedAt ? new Date(dto.receivedAt) : new Date(),
        executedAt:
          dto.executionMode === ExecutionMode.IMMEDIATE ? new Date() : null,
        account,
        commission: dto.commission,
      });

      const ledger = manager.getRepository(LedgerEntry);
      await ledger.save({
        category: LedgerCategory.CASH_RECEIPT,
        amount: dto.amount,
        entityType: 'collection',
        entityId: collection.id,
        reference,
        description: `استلام كاش من ${dto.agentName} لصالح ${dto.companyName}`,
        performedBy: username,
      });
      if (account) {
        await ledger.save({
          category: LedgerCategory.COMPANY_EXECUTION,
          amount: -dto.amount,
          entityType: 'account',
          entityId: account.id,
          reference,
          description: `تنفيذ فوري لصالح ${dto.companyName}`,
          performedBy: username,
        });
        if (dto.commission > 0) {
          await ledger.save({
            category: LedgerCategory.COMMISSION,
            amount: dto.commission,
            entityType: 'account',
            entityId: account.id,
            reference,
            description: `عمولة تنفيذ لصالح ${dto.companyName}`,
            performedBy: username,
          });
        }
      }
      return collection;
    });
  }

  async execute(id: string, dto: ExecuteHoldDto, username: string) {
    return this.dataSource.transaction(async (manager) => {
      const collectionRepo = manager.getRepository(Collection);
      const collection = await collectionRepo.findOne({
        where: { id },
        lock: { mode: 'pessimistic_write' },
      });
      if (!collection) throw new NotFoundException('المعلّق غير موجود');
      if (collection.status !== CollectionStatus.PENDING)
        throw new BadRequestException('العملية منفذة بالفعل');
      const account = await manager.getRepository(FinancialAccount).findOne({
        where: { id: dto.accountId, active: true },
        lock: { mode: 'pessimistic_write' },
      });
      if (!account)
        throw new NotFoundException('الحساب المستخدم غير موجود أو موقوف');
      if (account.balance < collection.amount)
        throw new BadRequestException('رصيد الحساب غير كافٍ');
      account.balance -= collection.amount;
      account.commissionBalance += dto.commission;
      await manager.getRepository(FinancialAccount).save(account);
      collection.status = CollectionStatus.DONE;
      collection.executedAt = new Date();
      collection.account = account;
      collection.commission = dto.commission;
      await collectionRepo.save(collection);
      await manager.getRepository(LedgerEntry).save({
        category: LedgerCategory.COMPANY_EXECUTION,
        amount: -collection.amount,
        entityType: 'account',
        entityId: account.id,
        reference: collection.reference,
        description: `تنفيذ المعلّق لصالح ${collection.companyName}`,
        performedBy: username,
      });
      if (dto.commission > 0) {
        await manager.getRepository(LedgerEntry).save({
          category: LedgerCategory.COMMISSION,
          amount: dto.commission,
          entityType: 'account',
          entityId: account.id,
          reference: collection.reference,
          description: `عمولة تنفيذ المعلّق لصالح ${collection.companyName}`,
          performedBy: username,
        });
      }
      return collection;
    });
  }

  async reverse(id: string, dto: ReversalDto, username: string) {
    return this.dataSource.transaction(async (manager) => {
      const collectionRepo = manager.getRepository(Collection);
      const collection = await collectionRepo.findOne({
        where: { id },
        lock: { mode: 'pessimistic_write' },
      });
      if (!collection) throw new NotFoundException('التحصيل غير موجود');
      if (collection.status === CollectionStatus.REVERSED) {
        throw new BadRequestException('تم عكس التحصيل بالفعل');
      }

      const treasury = await manager.getRepository(Treasury).findOne({
        where: { id: 'main' },
        lock: { mode: 'pessimistic_write' },
      });
      if (!treasury) throw new NotFoundException('الخزنة غير مهيأة');
      if (treasury.balance < collection.amount) {
        throw new BadRequestException('رصيد الخزنة لا يكفي لعكس التحصيل');
      }

      let account: FinancialAccount | null = null;
      if (collection.status === CollectionStatus.DONE) {
        if (!collection.accountId) {
          throw new BadRequestException('التحصيل المنفذ غير مرتبط بحساب');
        }
        account = await manager.getRepository(FinancialAccount).findOne({
          where: { id: collection.accountId },
          lock: { mode: 'pessimistic_write' },
        });
        if (!account) throw new NotFoundException('الحساب المرتبط غير موجود');
        if (account.commissionBalance < collection.commission) {
          throw new BadRequestException(
            'رصيد العمولة الحالي لا يكفي لعكس عمولة التحصيل',
          );
        }
        account.balance += collection.amount;
        account.commissionBalance -= collection.commission;
        await manager.getRepository(FinancialAccount).save(account);
      }

      treasury.balance -= collection.amount;
      collection.status = CollectionStatus.REVERSED;
      collection.reversedAt = new Date();
      collection.reversalReason = dto.reason;
      await manager.getRepository(Treasury).save(treasury);
      await collectionRepo.save(collection);

      const originalEntries = await manager.getRepository(LedgerEntry).find({
        where: { reference: collection.reference },
        order: { createdAt: 'ASC' },
      });
      const reversalRepo = manager.getRepository(LedgerEntry);
      for (const original of originalEntries) {
        await reversalRepo.save({
          category: LedgerCategory.REVERSAL,
          amount: -original.amount,
          entityType: original.entityType,
          entityId: original.entityId,
          reference: collection.reference,
          description: `عكس ${original.description} — السبب: ${dto.reason}`,
          performedBy: username,
          sourceType: original.targetType,
          sourceId: original.targetId,
          targetType: original.sourceType,
          targetId: original.sourceId,
          reversesEntryId: original.id,
          metadata: {
            collectionId: collection.id,
            reason: dto.reason,
            originalCategory: original.category,
          },
        });
      }
      return {
        reversed: true,
        collectionId: collection.id,
        reference: collection.reference,
        reason: dto.reason,
      };
    });
  }
}
