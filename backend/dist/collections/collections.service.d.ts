import { OnModuleInit } from '@nestjs/common';
import { DataSource, Repository } from 'typeorm';
import { Collection } from '../database/entities/collection.entity.js';
import { FinancialAccount } from '../database/entities/financial-account.entity.js';
import { Treasury } from '../database/entities/treasury.entity.js';
import { CollectionStatus, ExecutionMode } from '../database/enums.js';
import { ExecuteHoldDto } from './dto/execute-hold.dto.js';
import { ReceiveCollectionDto } from './dto/receive-collection.dto.js';
export declare class CollectionsService implements OnModuleInit {
    private readonly collections;
    private readonly treasury;
    private readonly dataSource;
    constructor(collections: Repository<Collection>, treasury: Repository<Treasury>, dataSource: DataSource);
    onModuleInit(): Promise<void>;
    findAll(): Promise<Collection[]>;
    findOne(id: string): Promise<Collection>;
    private nextReference;
    receive(dto: ReceiveCollectionDto, username: string): Promise<{
        reference: string;
        agentName: string;
        companyName: string;
        amount: number;
        executionMode: ExecutionMode;
        status: CollectionStatus;
        receivedAt: Date;
        executedAt: Date | null;
        account: FinancialAccount | null;
        commission: number;
    } & Collection>;
    execute(id: string, dto: ExecuteHoldDto, username: string): Promise<Collection>;
}
