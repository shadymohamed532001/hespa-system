var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
import { BadRequestException, Injectable, NotFoundException, } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { DataSource, Repository } from 'typeorm';
import { Collection } from '../database/entities/collection.entity.js';
import { FinancialAccount } from '../database/entities/financial-account.entity.js';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { Treasury } from '../database/entities/treasury.entity.js';
import { CollectionStatus, ExecutionMode, LedgerCategory, } from '../database/enums.js';
import { shouldSeedDemoData } from '../config/demo-data.js';
let CollectionsService = class CollectionsService {
    collections;
    treasury;
    dataSource;
    config;
    constructor(collections, treasury, dataSource, config) {
        this.collections = collections;
        this.treasury = treasury;
        this.dataSource = dataSource;
        this.config = config;
    }
    async onModuleInit() {
        if (!(await this.treasury.exists({ where: { id: 'main' } }))) {
            await this.treasury.save({
                id: 'main',
                balance: shouldSeedDemoData(this.config) ? 148750 : 0,
            });
        }
        if (!shouldSeedDemoData(this.config))
            return;
        if (await this.collections.count())
            return;
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
    async findOne(id) {
        const collection = await this.collections.findOne({
            where: { id },
            relations: { account: true },
        });
        if (!collection)
            throw new NotFoundException('التحصيل غير موجود');
        return collection;
    }
    async nextReference(mode) {
        const count = await this.collections.count();
        return `${mode === ExecutionMode.HOLD ? 'HLD' : 'COL'}-${String(count + 1).padStart(3, '0')}`;
    }
    async receive(dto, username) {
        if (dto.executionMode === ExecutionMode.IMMEDIATE && !dto.accountId) {
            throw new BadRequestException('الحساب المستخدم مطلوب للتنفيذ الفوري');
        }
        const reference = await this.nextReference(dto.executionMode);
        return this.dataSource.transaction(async (manager) => {
            const treasuryRepo = manager.getRepository(Treasury);
            const treasury = await treasuryRepo.findOne({
                where: { id: 'main' },
                lock: { mode: 'pessimistic_write' },
            });
            if (!treasury)
                throw new NotFoundException('الخزنة غير مهيأة');
            treasury.balance += dto.amount;
            await treasuryRepo.save(treasury);
            let account = null;
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
                status: dto.executionMode === ExecutionMode.IMMEDIATE
                    ? CollectionStatus.DONE
                    : CollectionStatus.PENDING,
                receivedAt: dto.receivedAt ? new Date(dto.receivedAt) : new Date(),
                executedAt: dto.executionMode === ExecutionMode.IMMEDIATE ? new Date() : null,
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
    async execute(id, dto, username) {
        return this.dataSource.transaction(async (manager) => {
            const collectionRepo = manager.getRepository(Collection);
            const collection = await collectionRepo.findOne({
                where: { id },
                lock: { mode: 'pessimistic_write' },
            });
            if (!collection)
                throw new NotFoundException('المعلّق غير موجود');
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
};
CollectionsService = __decorate([
    Injectable(),
    __param(0, InjectRepository(Collection)),
    __param(1, InjectRepository(Treasury)),
    __metadata("design:paramtypes", [Repository,
        Repository,
        DataSource,
        ConfigService])
], CollectionsService);
export { CollectionsService };
//# sourceMappingURL=collections.service.js.map