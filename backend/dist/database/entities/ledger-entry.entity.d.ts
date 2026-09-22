import { LedgerCategory } from '../enums.js';
export declare class LedgerEntry {
    id: string;
    category: LedgerCategory;
    amount: number;
    entityType: string;
    entityId: string | null;
    reference: string | null;
    description: string;
    performedBy: string;
    createdAt: Date;
}
