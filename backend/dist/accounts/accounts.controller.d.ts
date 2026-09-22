import { UsersService } from '../users/users.service.js';
import { AccountsService } from './accounts.service.js';
import { CreateAccountDto } from './dto/create-account.dto.js';
import { TopUpAccountDto } from './dto/top-up-account.dto.js';
type UserRequest = {
    user: {
        userId: string;
        username: string;
    };
};
export declare class AccountsController {
    private readonly accounts;
    private readonly users;
    constructor(accounts: AccountsService, users: UsersService);
    findAll(includeInactive?: boolean): Promise<import("../database/entities/financial-account.entity.js").FinancialAccount[]>;
    create(dto: CreateAccountDto, request: UserRequest): Promise<import("../database/entities/financial-account.entity.js").FinancialAccount>;
    topUp(id: string, dto: TopUpAccountDto, request: UserRequest): Promise<import("../database/entities/financial-account.entity.js").FinancialAccount>;
    setStatus(id: string, active: boolean): Promise<import("../database/entities/financial-account.entity.js").FinancialAccount>;
    remove(id: string, request: UserRequest): Promise<{
        deleted: boolean;
        id: string;
        name: string;
        deletedBy: string;
        message: string;
    }>;
}
export {};
