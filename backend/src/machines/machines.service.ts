import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  OnModuleInit,
} from '@nestjs/common';
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
    await this.machines.save(
      this.machines.create({ name: 'ماكينة شحن 01', loadedBalance: 20000 }),
    );
  }

  private withRemaining(machine: Machine) {
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

  async create(dto: CreateMachineDto, username: string) {
    const name = dto.name.trim();
    if (!name) throw new BadRequestException('اسم الماكينة مطلوب');
    if (await this.machines.exists({ where: { name } })) {
      throw new ConflictException('يوجد ماكينة بنفس الاسم بالفعل');
    }

    const opening = Number(dto.openingBalance ?? 0);
    return this.dataSource.transaction(async (manager) => {
      const repo = manager.getRepository(Machine);
      const machine = await repo.save(
        repo.create({
          name,
          loadedBalance: opening,
          usedBalance: 0,
          commissionBalance: 0,
          active: true,
        }),
      );

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

  async load(id: string, dto: LoadMachineDto, username: string) {
    return this.dataSource.transaction(async (manager) => {
      const repo = manager.getRepository(Machine);
      const machine = await repo.findOne({
        where: { id, active: true },
        lock: { mode: 'pessimistic_write' },
      });
      if (!machine) throw new NotFoundException('الماكينة غير موجودة أو موقوفة');
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

  async use(id: string, dto: UseMachineDto, username: string) {
    return this.dataSource.transaction(async (manager) => {
      const repo = manager.getRepository(Machine);
      const machine = await repo.findOne({
        where: { id, active: true },
        lock: { mode: 'pessimistic_write' },
      });
      if (!machine) throw new NotFoundException('الماكينة غير موجودة أو موقوفة');
      const remaining =
        Number(machine.loadedBalance) - Number(machine.usedBalance);
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

  async setActive(id: string, active: boolean) {
    const machine = await this.machines.findOne({ where: { id } });
    if (!machine) throw new NotFoundException('الماكينة غير موجودة');
    machine.active = active;
    return this.withRemaining(await this.machines.save(machine));
  }
}
