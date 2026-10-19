import { Injectable } from '@nestjs/common';
import { DataSource, EntitySubscriberInterface, InsertEvent } from 'typeorm';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';

export const CORRECTION_ENTRY_IDS = 'operationCorrectionEntryIds';

@Injectable()
export class CorrectionEntriesSubscriber implements EntitySubscriberInterface<LedgerEntry> {
  constructor(source: DataSource) {
    source.subscribers.push(this);
  }
  listenTo() {
    return LedgerEntry;
  }
  afterInsert(event: InsertEvent<LedgerEntry>) {
    const ids = event.queryRunner.data[CORRECTION_ENTRY_IDS] as
      string[] | undefined;
    if (ids && event.entity.id) ids.push(event.entity.id);
  }
}
