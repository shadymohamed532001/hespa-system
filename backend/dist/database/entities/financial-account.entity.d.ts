import { AccountType } from '../enums.js';
export declare class FinancialAccount {
    id: string;
    name: string;
    type: AccountType;
    active: boolean;
    openingBalance: number;
    todayTopUp: number;
    balance: number;
    commissionBalance: number;
    createdAt: Date;
    updatedAt: Date;
}
