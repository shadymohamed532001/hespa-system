import { OnModuleInit } from '@nestjs/common';
import { DataSource, Repository } from 'typeorm';
import { Machine } from '../database/entities/machine.entity.js';
import { CreateMachineDto } from './dto/create-machine.dto.js';
import { LoadMachineDto } from './dto/load-machine.dto.js';
import { UseMachineDto } from './dto/use-machine.dto.js';
export declare class MachinesService implements OnModuleInit {
    private readonly machines;
    private readonly dataSource;
    constructor(machines: Repository<Machine>, dataSource: DataSource);
    onModuleInit(): Promise<void>;
    findAll(includeInactive?: boolean): Promise<(Machine & {
        remainingBalance: number;
    })[]>;
    create(dto: CreateMachineDto): Promise<Machine>;
    load(id: string, dto: LoadMachineDto, username: string): Promise<Machine & {
        remainingBalance: number;
    }>;
    use(id: string, dto: UseMachineDto, username: string): Promise<Machine & {
        remainingBalance: number;
    }>;
    setActive(id: string, active: boolean): Promise<Machine>;
}
