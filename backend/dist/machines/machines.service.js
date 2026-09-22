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
import { BadRequestException, ConflictException, Injectable, NotFoundException, } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { DataSource, Repository } from 'typeorm';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { Machine } from '../database/entities/machine.entity.js';
import { LedgerCategory } from '../database/enums.js';
import { shouldSeedDemoData } from '../config/demo-data.js';
let MachinesService = class MachinesService {
    machines;
    dataSource;
    config;
    constructor(machines, dataSource, config) {
        this.machines = machines;
        this.dataSource = dataSource;
        this.config = config;
    }
    async onModuleInit() {
        if (!shouldSeedDemoData(this.config))
            return;
        if (await this.machines.count())
            return;
        await this.machines.save(this.machines.create({ name: 'ماكينة شحن 01', loadedBalance: 20000 }));
    }
    withRemaining(machine) {
        return Object.assign({}, machine, {
            remainingBalance: Number(machine.loadedBalance) - Number(machine.usedBalance),
        });
    }
    async findAll(includeInactive = false) {
        const machines = await this.machines.find({
            where: includeInactive ? {} : { active: true },
            order: { createdAt: 'ASC' },
        });
        return machines.map((machine) => this.withRemaining(machine));
    }
    async create(dto, username) {
        const name = dto.name.trim();
        if (!name)
            throw new BadRequestException('اسم الماكينة مطلوب');
        if (await this.machines.exists({ where: { name } })) {
            throw new ConflictException('يوجد ماكينة بنفس الاسم بالفعل');
        }
        const opening = Number(dto.openingBalance ?? 0);
        return this.dataSource.transaction(async (manager) => {
            const repo = manager.getRepository(Machine);
            const machine = await repo.save(repo.create({
                name,
                loadedBalance: opening,
                usedBalance: 0,
                commissionBalance: 0,
                active: true,
            }));
            if (opening > 0) {
                await manager.getRepository(LedgerEntry).save({
                    category: LedgerCategory.OPENING_BALANCE,
                    amount: opening,
                    entityType: 'machine',
                    entityId: machine.id,
                    reference: null,
                    description: `رصيد افتتاحي للماكينة ${machine.name}`,
                    performedBy: username,
                });
            }
            return this.withRemaining(machine);
        });
    }
    async load(id, dto, username) {
        return this.dataSource.transaction(async (manager) => {
            const repo = manager.getRepository(Machine);
            const machine = await repo.findOne({
                where: { id, active: true },
                lock: { mode: 'pessimistic_write' },
            });
            if (!machine)
                throw new NotFoundException('الماكينة غير موجودة أو موقوفة');
            machine.loadedBalance = Number(machine.loadedBalance) + Number(dto.amount);
            await repo.save(machine);
            await manager.getRepository(LedgerEntry).save({
                category: LedgerCategory.TOP_UP,
                amount: dto.amount,
                entityType: 'machine',
                entityId: machine.id,
                reference: dto.reference ?? null,
                description: `شحن رصيد الماكينة ${machine.name}`,
                performedBy: username,
            });
            return this.withRemaining(machine);
        });
    }
    async use(id, dto, username) {
        return this.dataSource.transaction(async (manager) => {
            const repo = manager.getRepository(Machine);
            const machine = await repo.findOne({
                where: { id, active: true },
                lock: { mode: 'pessimistic_write' },
            });
            if (!machine)
                throw new NotFoundException('الماكينة غير موجودة أو موقوفة');
            const remaining = Number(machine.loadedBalance) - Number(machine.usedBalance);
            if (remaining < Number(dto.amount)) {
                throw new BadRequestException('رصيد الماكينة غير كافٍ');
            }
            machine.usedBalance = Number(machine.usedBalance) + Number(dto.amount);
            machine.commissionBalance =
                Number(machine.commissionBalance) + Number(dto.commission);
            await repo.save(machine);
            await manager.getRepository(LedgerEntry).save({
                category: LedgerCategory.MACHINE_USAGE,
                amount: dto.amount,
                entityType: 'machine',
                entityId: machine.id,
                reference: dto.reference ?? null,
                description: `عملية شحن من ${machine.name} وعمولتها ${dto.commission}`,
                performedBy: username,
            });
            return this.withRemaining(machine);
        });
    }
    async setActive(id, active) {
        const machine = await this.machines.findOne({ where: { id } });
        if (!machine)
            throw new NotFoundException('الماكينة غير موجودة');
        machine.active = active;
        return this.withRemaining(await this.machines.save(machine));
    }
};
MachinesService = __decorate([
    Injectable(),
    __param(0, InjectRepository(Machine)),
    __metadata("design:paramtypes", [Repository,
        DataSource,
        ConfigService])
], MachinesService);
export { MachinesService };
//# sourceMappingURL=machines.service.js.map