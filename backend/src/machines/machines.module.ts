import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { Machine } from '../database/entities/machine.entity.js';
import { MachinesController } from './machines.controller.js';
import { MachinesService } from './machines.service.js';

@Module({
  imports: [TypeOrmModule.forFeature([Machine, LedgerEntry])],
  controllers: [MachinesController],
  providers: [MachinesService],
})
export class MachinesModule {}
