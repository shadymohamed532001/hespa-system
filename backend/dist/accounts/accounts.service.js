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
import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { DataSource, Repository } from 'typeorm';
import { FinancialAccount } from '../database/entities/financial-account.entity.js';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { AccountType, LedgerCategory } from '../database/enums.js';
import { shouldSeedDemoData } from '../config/demo-data.js';
export const FAWRY_MAX_BALANCE = 5_000_000;
let AccountsService = class AccountsService {
    accounts;
    ledger;
    dataSource;
    config;
    constructor(accounts, ledger, dataSource, config) {
        this.accounts = accounts;
        this.ledger = ledger;
        this.dataSource = dataSource;
        this.config = config;
    }
    async onModuleInit() {
        if (!shouldSeedDemoData(this.config))
            return;
        if (await this.accounts.count())
            return;
        await this.accounts.save([
            this.accounts.create({ name: 'حساب فوري 01', type: AccountType.FAWRY, openingBalance: 82400, balance: 82400 }),
            this.accounts.create({ name: 'حساب شركة 01', type: AccountType.COMPANY, openingBalance: 36500, balance: 36500 }),
        ]);
    }
    findAll(includeInactive = false) {
        return this.accounts.find({
            where: includeInactive ? {} : { active: true },
            order: { createdAt: 'ASC' },
        });
    }
    async create(dto, username) {
        if (dto.type === AccountType.FAWRY && dto.openingBalance > FAWRY_MAX_BALANCE) {
            throw new BadRequestException('الرصيد الافتتاحي يتجاوز الحد الأقصى لحساب فوري');
        }
        return this.dataSource.transaction(async (manager) => {
            const repo = manager.getRepository(FinancialAccount);
            const account = await repo.save(repo.create({
                name: dto.name,
                type: dto.type,
                openingBalance: dto.openingBalance,
                balance: dto.openingBalance,
            }));
            if (dto.openingBalance > 0) {
                await manager.getRepository(LedgerEntry).save({
                    category: LedgerCategory.OPENING_BALANCE,
                    amount: dto.openingBalance,
                    entityType: 'account',
                    entityId: account.id,
                    reference: null,
                    description: `رصيد افتتاحي للحساب ${account.name}`,
                    performedBy: username,
                });
            }
            return account;
        });
    }
    async topUp(id, dto, username) {
        return this.dataSource.transaction(async (manager) => {
            const repo = manager.getRepository(FinancialAccount);
            const account = await repo.findOne({ where: { id, active: true }, lock: { mode: 'pessimistic_write' } });
            if (!account)
                throw new NotFoundException('الحساب غير موجود أو موقوف');
            if (account.type === AccountType.FAWRY && account.balance + dto.amount > FAWRY_MAX_BALANCE) {
                throw new BadRequestException({
                    message: 'سيتم تجاوز الحد الأقصى لحساب فوري',
                    limit: FAWRY_MAX_BALANCE,
                    available: Math.max(0, FAWRY_MAX_BALANCE - account.balance),
                });
            }
            account.balance += dto.amount;
            account.todayTopUp += dto.amount;
            await repo.save(account);
            await manager.getRepository(LedgerEntry).save({
                category: LedgerCategory.TOP_UP,
                amount: dto.amount,
                entityType: 'account',
                entityId: account.id,
                reference: dto.reference ?? null,
                description: `شحن مباشر للحساب ${account.name}`,
                performedBy: username,
            });
            return account;
        });
    }
    async setActive(id, active) {
        const account = await this.accounts.findOne({ where: { id } });
        if (!account)
            throw new NotFoundException('الحساب غير موجود');
        account.active = active;
        return this.accounts.save(account);
    }
    async remove(id, username) {
        const account = await this.accounts.findOne({ where: { id } });
        if (!account)
            throw new NotFoundException('الحساب غير موجود');
        const history = await this.ledger.count({
            where: { entityType: 'account', entityId: id },
        });
        if (account.balance !== 0 || account.commissionBalance !== 0 || history > 0) {
            throw new BadRequestException('لا يمكن الحذف النهائي إلا إذا كان الرصيد والعمولة صفرًا ولا توجد أي حركات مرتبطة بالحساب');
        }
        const name = account.name;
        await this.accounts.remove(account);
        return {
            deleted: true,
            id,
            name,
            deletedBy: username,
            message: `تم الحذف النهائي للحساب «${name}» بنجاح`,
        };
    }
};
AccountsService = __decorate([
    Injectable(),
    __param(0, InjectRepository(FinancialAccount)),
    __param(1, InjectRepository(LedgerEntry)),
    __metadata("design:paramtypes", [Repository,
        Repository,
        DataSource,
        ConfigService])
], AccountsService);
export { AccountsService };
//# sourceMappingURL=accounts.service.js.map