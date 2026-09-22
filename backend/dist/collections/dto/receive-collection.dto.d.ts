import { ExecutionMode } from '../../database/enums.js';
export declare class ReceiveCollectionDto {
    agentName: string;
    companyName: string;
    amount: number;
    executionMode: ExecutionMode;
    receivedAt?: string;
    accountId?: string;
    commission: number;
}
