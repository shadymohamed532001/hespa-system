import { OnModuleInit } from '@nestjs/common';
import { DataSource, Repository } from 'typeorm';
import { FinancialAccount } from '../database/entities/financial-account.entity.js';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { CreateAccountDto } from './dto/create-account.dto.js';
import { TopUpAccountDto } from './dto/top-up-account.dto.js';
export declare const FAWRY_MAX_BALANCE = 5000000;
export declare class AccountsService implements OnModuleInit {
    private readonly accounts;
    private readonly ledger;
    private readonly dataSource;
    constructor(accounts: Repository<FinancialAccount>, ledger: Repository<LedgerEntry>, dataSource: DataSource);
    onModuleInit(): Promise<void>;
    findAll(includeInactive?: boolean): Promise<FinancialAccount[]>;
    create(dto: CreateAccountDto, username: string): Promise<FinancialAccount>;
    topUp(id: string, dto: TopUpAccountDto, username: string): Promise<FinancialAccount>;
    setActive(id: string, active: boolean): Promise<FinancialAccount>;
    remove(id: string): Promise<{
        deleted: boolean;
    }>;
}
