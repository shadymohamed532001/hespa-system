import { UsersService } from '../users/users.service.js';
import { InternalTransferDto } from './dto/internal-transfer.dto.js';
import { CloseDayDto, ReconcileDto } from './dto/reconcile.dto.js';
import { TreasuryService } from './treasury.service.js';
type UserRequest = {
    user: {
        userId: string;
        username: string;
    };
};
export declare class TreasuryController {
    private readonly treasury;
    private readonly users;
    constructor(treasury: TreasuryService, users: UsersService);
    summary(): Promise<{
        actualBalance: number;
        pendingAmount: number;
        availableBalance: number;
    }>;
    transfer(dto: InternalTransferDto, request: UserRequest): Promise<{
        from: string;
        to: string;
        amount: number;
    }>;
    rollover(dto: CloseDayDto, request: UserRequest): Promise<{
        closed: boolean;
        alreadyClosed: boolean;
        close: import("../database/entities/daily-close.entity.js").DailyClose;
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
        } & import("../database/entities/daily-close.entity.js").DailyClose;
        accounts: number;
        wallets: number;
        machines: number;
        alreadyClosed?: undefined;
    }>;
    closeDay(dto: CloseDayDto, request: UserRequest): Promise<{
        closed: boolean;
        alreadyClosed: boolean;
        close: import("../database/entities/daily-close.entity.js").DailyClose;
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
        } & import("../database/entities/daily-close.entity.js").DailyClose;
        accounts: number;
        wallets: number;
        machines: number;
        alreadyClosed?: undefined;
    }>;
    dailyCloses(): Promise<import("../database/entities/daily-close.entity.js").DailyClose[]>;
    reconcile(dto: ReconcileDto, request: UserRequest): Promise<{
        id: string;
        asset: string;
        expectedBalance: number;
        countedBalance: number;
        difference: number;
    }>;
}
export {};
