import { CollectionStatus, ExecutionMode } from '../enums.js';
import { FinancialAccount } from './financial-account.entity.js';
export declare class Collection {
    id: string;
    reference: string;
    agentName: string;
    companyName: string;
    amount: number;
    executionMode: ExecutionMode;
    status: CollectionStatus;
    receivedAt: Date;
    executedAt: Date | null;
    reversedAt: Date | null;
    reversalReason: string | null;
    account: FinancialAccount | null;
    accountId: string | null;
    commission: number;
    createdAt: Date;
}
