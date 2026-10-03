import { describe, expect, it } from 'vitest';
import { LedgerCategory } from '../database/enums.js';
import {
  fawryOperationStatus,
  matchingFawryAccountId,
} from './accounts.service.js';

const blank = {
  sourceType: null,
  sourceId: null,
  targetType: null,
  targetId: null,
};

describe('fawry today operations', () => {
  it('matches the fawry account on the entry, source, or target', () => {
    expect(
      matchingFawryAccountId(
        { ...blank, entityType: 'account', entityId: 'fawry-1' },
        ['fawry-1'],
      ),
    ).toBe('fawry-1');
    expect(
      matchingFawryAccountId(
        {
          ...blank,
          entityType: 'treasury',
          entityId: 'main',
          targetType: 'account',
          targetId: 'fawry-2',
        },
        ['fawry-1', 'fawry-2'],
      ),
    ).toBe('fawry-2');
    expect(
      matchingFawryAccountId(
        { ...blank, entityType: 'account', entityId: 'profit-1' },
        ['fawry-1'],
      ),
    ).toBeNull();
  });

  it('marks a completed movement as done and a reversed one as reversed', () => {
    const done = {
      id: 'entry-1',
      category: LedgerCategory.COMPANY_EXECUTION,
      reversesEntryId: null,
    };
    expect(fawryOperationStatus(done, new Set())).toBe('done');
    expect(fawryOperationStatus(done, new Set(['entry-1']))).toBe('reversed');
    expect(
      fawryOperationStatus(
        {
          id: 'entry-2',
          category: LedgerCategory.REVERSAL,
          reversesEntryId: 'entry-1',
        },
        new Set(),
      ),
    ).toBe('reversed');
  });
});
