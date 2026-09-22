import { DataSource, Repository } from 'typeorm';
import { Collection } from '../database/entities/collection.entity.js';
import { Treasury } from '../database/entities/treasury.entity.js';
import { InternalTransferDto } from './dto/internal-transfer.dto.js';
export declare class TreasuryService {
    private readonly treasury;
    private readonly collections;
    private readonly dataSource;
    constructor(treasury: Repository<Treasury>, collections: Repository<Collection>, dataSource: DataSource);
    summary(): Promise<{
        actualBalance: number;
        pendingAmount: number;
        availableBalance: number;
    }>;
    private asset;
    transfer(dto: InternalTransferDto, username: string): Promise<{
        from: string;
        to: string;
        amount: number;
    }>;
    rollover(username: string): Promise<{
        rolledOver: boolean;
        accounts: number;
        wallets: number;
    }>;
}
