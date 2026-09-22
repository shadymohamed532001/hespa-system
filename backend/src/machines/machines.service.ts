import { BadRequestException, Injectable, NotFoundException, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { Machine } from '../database/entities/machine.entity.js';
import { LedgerCategory } from '../database/enums.js';
import { CreateMachineDto } from './dto/create-machine.dto.js';
import { LoadMachineDto } from './dto/load-machine.dto.js';
import { UseMachineDto } from './dto/use-machine.dto.js';

@Injectable()
export class MachinesService implements OnModuleInit {
  constructor(
    @InjectRepository(Machine) private readonly machines: Repository<Machine>,
    private readonly dataSource: DataSource,
  ) {}

  async onModuleInit() {
    if (await this.machines.count()) return;
    await this.machines.save(this.machines.create({ name: 'ماكينة شحن 01', loadedBalance: 20000 }));
  }

  async findAll(includeInactive = false) {
    const machines = await this.machines.find({
      where: includeInactive ? {} : { active: true },
      order: { createdAt: 'ASC' },
    });
    return machines.map((machine) =>
      Object.assign({}, machine, {
        remainingBalance: machine.loadedBalance - machine.usedBalance,
      }),
    );
  }

  create(dto: CreateMachineDto) {
    return this.machines.save(this.machines.create({ name: dto.name, loadedBalance: dto.openingBalance }));
  }

  async load(id: string, dto: LoadMachineDto, username: string) {
    return this.dataSource.transaction(async (manager) => {
      const repo = manager.getRepository(Machine);
      const machine = await repo.findOne({ where: { id, active: true }, lock: { mode: 'pessimistic_write' } });
      if (!machine) throw new NotFoundException('الماكينة غير موجودة أو موقوفة');
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

  async use(id: string, dto: UseMachineDto, username: string) {
    return this.dataSource.transaction(async (manager) => {
      const repo = manager.getRepository(Machine);
      const machine = await repo.findOne({ where: { id, active: true }, lock: { mode: 'pessimistic_write' } });
      if (!machine) throw new NotFoundException('الماكينة غير موجودة أو موقوفة');
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

  async setActive(id: string, active: boolean) {
    const machine = await this.machines.findOne({ where: { id } });
    if (!machine) throw new NotFoundException('الماكينة غير موجودة');
    machine.active = active;
    return this.machines.save(machine);
  }
}
