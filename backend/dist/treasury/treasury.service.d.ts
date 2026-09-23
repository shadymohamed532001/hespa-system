import { DataSource, Repository } from 'typeorm';
import { Collection } from '../database/entities/collection.entity.js';
import { Treasury } from '../database/entities/treasury.entity.js';
import { DailyClose } from '../database/entities/daily-close.entity.js';
import { InternalTransferDto } from './dto/internal-transfer.dto.js';
import { CloseDayDto, ReconcileDto } from './dto/reconcile.dto.js';
export declare class TreasuryService {
    private readonly treasury;
    private readonly collections;
    private readonly closes;
    private readonly dataSource;
    constructor(treasury: Repository<Treasury>, collections: Repository<Collection>, closes: Repository<DailyClose>, dataSource: DataSource);
    summary(): Promise<{
        actualBalance: number;
        pendingAmount: number;
        availableBalance: number;
    }>;
    private assetKey;
    private asset;
    transfer(dto: InternalTransferDto, username: string): Promise<{
        from: string;
        to: string;
        amount: number;
    }>;
    reconcile(dto: ReconcileDto, username: string): Promise<{
        id: string;
        asset: string;
        expectedBalance: number;
        countedBalance: number;
        difference: number;
    }>;
    dailyCloses(): Promise<DailyClose[]>;
    private cairoDay;
    closeDay(dto: CloseDayDto, username: string): Promise<{
        closed: boolean;
        alreadyClosed: boolean;
        close: DailyClose;
        accounts?: undefined;
        wallets?: undefined;
        machines?: undefined;
    } | {
        closed: boolean;
        close: {
            businessDate: string;
            snapshot: {
                treasury: {
                    id: string;
                    balance: number;
                };
                accounts: {
                    id: string;
                    name: string;
                    balance: number;
                    commissionBalance: number;
                }[];
                wallets: {
                    id: string;
                    name: string;
                    balance: number;
                    commissionBalance: number;
                }[];
                machines: {
                    id: string;
                    name: string;
                    loadedBalance: number;
                    usedBalance: number;
                    remainingBalance: number;
                    commissionBalance: number;
                }[];
            };
            totalAssets: number;
            pendingCollections: number;
            closedBy: string;
            note: string | null;
        } & DailyClose;
        accounts: number;
        wallets: number;
        machines: number;
        alreadyClosed?: undefined;
    }>;
    rollover(username: string): Promise<{
        closed: boolean;
        alreadyClosed: boolean;
        close: DailyClose;
        accounts?: undefined;
        wallets?: undefined;
        machines?: undefined;
    } | {
        closed: boolean;
        close: {
            businessDate: string;
            snapshot: {
                treasury: {
                    id: string;
                    balance: number;
                };
                accounts: {
                    id: string;
                    name: string;
                    balance: number;
                    commissionBalance: number;
                }[];
                wallets: {
                    id: string;
                    name: string;
                    balance: number;
                    commissionBalance: number;
                }[];
                machines: {
                    id: string;
                    name: string;
                    loadedBalance: number;
                    usedBalance: number;
                    remainingBalance: number;
                    commissionBalance: number;
                }[];
            };
            totalAssets: number;
            pendingCollections: number;
            closedBy: string;
            note: string | null;
        } & DailyClose;
        accounts: number;
        wallets: number;
        machines: number;
        alreadyClosed?: undefined;
    }>;
}
