import { ReversalDto } from '../common/dto/reversal.dto.js';
import { LedgerService } from './ledger.service.js';
type UserRequest = {
    user: {
        username: string;
    };
};
export declare class LedgerController {
    private readonly ledger;
    constructor(ledger: LedgerService);
    findAll(limit?: string): Promise<import("../database/entities/ledger-entry.entity.js").LedgerEntry[]>;
    reverse(id: string, dto: ReversalDto, request: UserRequest): Promise<{
        reversed: boolean;
        originalEntryId: string;
        reversal: {
            category: import("../database/enums.js").LedgerCategory.REVERSAL;
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
            reversesEntryId: string;
            metadata: {
                reason: string;
                originalCategory: import("../database/enums.js").LedgerCategory.TOP_UP | import("../database/enums.js").LedgerCategory.INTERNAL_TRANSFER | import("../database/enums.js").LedgerCategory.MACHINE_USAGE | import("../database/enums.js").LedgerCategory.RECONCILIATION;
            };
        } & import("../database/entities/ledger-entry.entity.js").LedgerEntry;
    }>;
}
export {};
