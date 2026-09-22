import { AccountsService } from './accounts.service.js';
import { CreateAccountDto } from './dto/create-account.dto.js';
import { TopUpAccountDto } from './dto/top-up-account.dto.js';
type UserRequest = {
    user: {
        username: string;
    };
};
export declare class AccountsController {
    private readonly accounts;
    constructor(accounts: AccountsService);
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
