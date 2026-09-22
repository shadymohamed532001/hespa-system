import { Repository } from 'typeorm';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
export declare class LedgerController {
    private readonly ledger;
    constructor(ledger: Repository<LedgerEntry>);
    findAll(limit?: string): Promise<LedgerEntry[]>;
}
