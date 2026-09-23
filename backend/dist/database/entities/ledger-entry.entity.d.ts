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
    sourceType: string | null;
    sourceId: string | null;
    targetType: string | null;
    targetId: string | null;
    reversesEntryId: string | null;
    metadata: Record<string, unknown> | null;
    createdAt: Date;
}
