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
import { Machine } from '../database/entities/machine.entity.js';
import { LedgerCategory } from '../database/enums.js';
let MachinesService = class MachinesService {
    machines;
    dataSource;
    constructor(machines, dataSource) {
        this.machines = machines;
        this.dataSource = dataSource;
    }
    async onModuleInit() {
        if (await this.machines.count())
            return;
        await this.machines.save(this.machines.create({ name: 'ماكينة شحن 01', loadedBalance: 20000 }));
    }
    async findAll(includeInactive = false) {
        const machines = await this.machines.find({
            where: includeInactive ? {} : { active: true },
            order: { createdAt: 'ASC' },
        });
        return machines.map((machine) => Object.assign({}, machine, {
            remainingBalance: machine.loadedBalance - machine.usedBalance,
        }));
    }
    create(dto) {
        return this.machines.save(this.machines.create({ name: dto.name, loadedBalance: dto.openingBalance }));
    }
    async load(id, dto, username) {
        return this.dataSource.transaction(async (manager) => {
            const repo = manager.getRepository(Machine);
            const machine = await repo.findOne({ where: { id, active: true }, lock: { mode: 'pessimistic_write' } });
            if (!machine)
                throw new NotFoundException('الماكينة غير موجودة أو موقوفة');
            machine.loadedBalance += dto.amount;
            await repo.save(machine);
            await manager.getRepository(LedgerEntry).save({
                category: LedgerCategory.TOP_UP,
                amount: dto.amount,
                entityType: 'machine', entityId: machine.id, reference: dto.reference ?? null,
                description: `شحن رصيد الماكينة ${machine.name}`,
                performedBy: username,
            });
            return Object.assign({}, machine, {
                remainingBalance: machine.loadedBalance - machine.usedBalance,
            });
        });
    }
    async use(id, dto, username) {
        return this.dataSource.transaction(async (manager) => {
            const repo = manager.getRepository(Machine);
            const machine = await repo.findOne({ where: { id, active: true }, lock: { mode: 'pessimistic_write' } });
            if (!machine)
                throw new NotFoundException('الماكينة غير موجودة أو موقوفة');
            if (machine.loadedBalance - machine.usedBalance < dto.amount) {
                throw new BadRequestException('رصيد الماكينة غير كافٍ');
            }
            machine.usedBalance += dto.amount;
            machine.commissionBalance += dto.commission;
            await repo.save(machine);
            await manager.getRepository(LedgerEntry).save({
                category: LedgerCategory.MACHINE_USAGE,
                amount: dto.amount,
                entityType: 'machine', entityId: machine.id, reference: dto.reference ?? null,
                description: `عملية شحن من ${machine.name} وعمولتها ${dto.commission}`,
                performedBy: username,
            });
            return Object.assign({}, machine, {
                remainingBalance: machine.loadedBalance - machine.usedBalance,
            });
        });
    }
    async setActive(id, active) {
        const machine = await this.machines.findOne({ where: { id } });
        if (!machine)
            throw new NotFoundException('الماكينة غير موجودة');
        machine.active = active;
        return this.machines.save(machine);
    }
};
MachinesService = __decorate([
    Injectable(),
    __param(0, InjectRepository(Machine)),
    __metadata("design:paramtypes", [Repository,
        DataSource])
], MachinesService);
export { MachinesService };
//# sourceMappingURL=machines.service.js.map