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
import { DataSource, Repository } from 'typeorm';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { Wallet } from '../database/entities/wallet.entity.js';
import { LedgerCategory } from '../database/enums.js';
export const WALLET_DAILY_TOP_UP_LIMIT = 60_000;
export const WALLET_MONTHLY_TOP_UP_LIMIT = 200_000;
function cairoPeriod() {
    const day = new Intl.DateTimeFormat('en-CA', {
        timeZone: 'Africa/Cairo', year: 'numeric', month: '2-digit', day: '2-digit',
    }).format(new Date());
    return { day, month: day.slice(0, 7) };
}
let WalletsService = class WalletsService {
    wallets;
    dataSource;
    constructor(wallets, dataSource) {
        this.wallets = wallets;
        this.dataSource = dataSource;
    }
    async onModuleInit() {
        if (await this.wallets.count())
            return;
        await this.wallets.save([
            this.wallets.create({ name: 'محفظة 01', type: 'wallet', openingBalance: 11250, balance: 11250 }),
            this.wallets.create({ name: 'InstaPay 01', type: 'instapay', openingBalance: 16550, balance: 16550 }),
        ]);
    }
    findAll() {
        return this.wallets.find({ where: { active: true }, order: { createdAt: 'ASC' } });
    }
    async create(dto) {
        return this.wallets.save(this.wallets.create({
            name: dto.name,
            type: dto.type,
            openingBalance: dto.openingBalance,
            balance: dto.openingBalance,
        }));
    }
    async topUp(id, dto, username) {
        return this.dataSource.transaction(async (manager) => {
            const repo = manager.getRepository(Wallet);
            const wallet = await repo.findOne({ where: { id, active: true }, lock: { mode: 'pessimistic_write' } });
            if (!wallet)
                throw new NotFoundException('المحفظة غير موجودة أو موقوفة');
            const period = cairoPeriod();
            if (wallet.counterDay !== period.day) {
                wallet.counterDay = period.day;
                wallet.dailyTopUp = 0;
                wallet.todayTopUp = 0;
                wallet.openingBalance = wallet.balance;
            }
            if (wallet.counterMonth !== period.month) {
                wallet.counterMonth = period.month;
                wallet.monthlyTopUp = 0;
            }
            if (wallet.dailyTopUp + dto.amount > WALLET_DAILY_TOP_UP_LIMIT) {
                throw new BadRequestException({
                    message: 'سيتم تجاوز حد شحن المحفظة اليومي',
                    limit: WALLET_DAILY_TOP_UP_LIMIT,
                    available: Math.max(0, WALLET_DAILY_TOP_UP_LIMIT - wallet.dailyTopUp),
                });
            }
            if (wallet.monthlyTopUp + dto.amount > WALLET_MONTHLY_TOP_UP_LIMIT) {
                throw new BadRequestException({
                    message: 'سيتم تجاوز حد شحن المحفظة الشهري',
                    limit: WALLET_MONTHLY_TOP_UP_LIMIT,
                    available: Math.max(0, WALLET_MONTHLY_TOP_UP_LIMIT - wallet.monthlyTopUp),
                });
            }
            wallet.balance += dto.amount;
            wallet.todayTopUp += dto.amount;
            wallet.dailyTopUp += dto.amount;
            wallet.monthlyTopUp += dto.amount;
            await repo.save(wallet);
            await manager.getRepository(LedgerEntry).save({
                category: LedgerCategory.TOP_UP,
                amount: dto.amount,
                entityType: 'wallet',
                entityId: wallet.id,
                reference: dto.reference ?? null,
                description: `شحن ${wallet.name}`,
                performedBy: username,
            });
            return wallet;
        });
    }
};
WalletsService = __decorate([
    Injectable(),
    __param(0, InjectRepository(Wallet)),
    __metadata("design:paramtypes", [Repository,
        DataSource])
], WalletsService);
export { WalletsService };
//# sourceMappingURL=wallets.service.js.map