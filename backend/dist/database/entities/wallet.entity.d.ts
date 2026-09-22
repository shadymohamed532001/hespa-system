export declare class Wallet {
    id: string;
    name: string;
    type: string;
    active: boolean;
    openingBalance: number;
    todayTopUp: number;
    balance: number;
    dailyTopUp: number;
    monthlyTopUp: number;
    counterDay: string | null;
    counterMonth: string | null;
    commissionBalance: number;
    createdAt: Date;
    updatedAt: Date;
}
