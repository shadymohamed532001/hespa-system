import { CreateMachineDto } from './dto/create-machine.dto.js';
import { LoadMachineDto } from './dto/load-machine.dto.js';
import { UseMachineDto } from './dto/use-machine.dto.js';
import { MachinesService } from './machines.service.js';
type UserRequest = {
    user: {
        username: string;
    };
};
export declare class MachinesController {
    private readonly machines;
    constructor(machines: MachinesService);
    findAll(includeInactive?: boolean): Promise<{
        remainingBalance: number;
        id: string;
        name: string;
        active: boolean;
        loadedBalance: number;
        usedBalance: number;
        commissionBalance: number;
        createdAt: Date;
        updatedAt: Date;
    }[]>;
    create(dto: CreateMachineDto): Promise<import("../database/entities/machine.entity.js").Machine>;
    load(id: string, dto: LoadMachineDto, request: UserRequest): Promise<{
        remainingBalance: number;
        id: string;
        name: string;
        active: boolean;
        loadedBalance: number;
        usedBalance: number;
        commissionBalance: number;
        createdAt: Date;
        updatedAt: Date;
    }>;
    use(id: string, dto: UseMachineDto, request: UserRequest): Promise<{
        remainingBalance: number;
        id: string;
        name: string;
        active: boolean;
        loadedBalance: number;
        usedBalance: number;
        commissionBalance: number;
        createdAt: Date;
        updatedAt: Date;
    }>;
    setStatus(id: string, active: boolean): Promise<import("../database/entities/machine.entity.js").Machine>;
}
export {};
