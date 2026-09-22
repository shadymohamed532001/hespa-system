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
    findAll(includeInactive?: boolean): Promise<(import("../database/entities/machine.entity.js").Machine & {
        remainingBalance: number;
    })[]>;
    create(dto: CreateMachineDto): Promise<import("../database/entities/machine.entity.js").Machine>;
    load(id: string, dto: LoadMachineDto, request: UserRequest): Promise<import("../database/entities/machine.entity.js").Machine & {
        remainingBalance: number;
    }>;
    use(id: string, dto: UseMachineDto, request: UserRequest): Promise<import("../database/entities/machine.entity.js").Machine & {
        remainingBalance: number;
    }>;
    setStatus(id: string, active: boolean): Promise<import("../database/entities/machine.entity.js").Machine>;
}
export {};
