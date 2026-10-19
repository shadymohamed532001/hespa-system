import {
  DataSource,
  InsertEvent,
  TransactionCommitEvent,
  TransactionRollbackEvent,
} from 'typeorm';
import { LedgerNotificationSubscriber } from './ledger-notification.subscriber.js';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { LedgerCategory } from '../database/enums.js';
import { FcmService } from './fcm.service.js';

function fixture() {
  const sendPush = vi.fn().mockResolvedValue(undefined);
  const subscriber = new LedgerNotificationSubscriber(
    { subscribers: [] } as unknown as DataSource,
    { sendPush } as unknown as FcmService,
  );
  const repo = {
    findOne: vi.fn().mockResolvedValue(null),
    create: (v: unknown) => v,
    save: vi.fn().mockResolvedValue({ id: 'notification' }),
  };
  const runner = {
    isTransactionActive: true,
    data: {} as Record<string, unknown>,
  };
  const event = {
    entity: Object.assign(new LedgerEntry(), {
      id: 'entry',
      category: LedgerCategory.TOP_UP,
      amount: 100,
      entityType: 'wallet',
      description: 'شحن',
      metadata: null,
    }),
    manager: { getRepository: () => repo },
    queryRunner: runner,
  };
  return { subscriber, sendPush, runner, event };
}

describe('ledger notifications during operation correction', () => {
  it('pushes only after the outer transaction commits', async () => {
    const f = fixture();
    await f.subscriber.afterInsert(
      f.event as unknown as InsertEvent<LedgerEntry>,
    );
    expect(f.sendPush).not.toHaveBeenCalled();
    await f.subscriber.afterTransactionCommit({
      queryRunner: f.runner,
    } as unknown as TransactionCommitEvent);
    expect(f.sendPush).not.toHaveBeenCalled();
    f.runner.isTransactionActive = false;
    await f.subscriber.afterTransactionCommit({
      queryRunner: f.runner,
    } as unknown as TransactionCommitEvent);
    expect(f.sendPush).toHaveBeenCalledTimes(2);
    expect(f.runner.data.ledgerPushAfterCommit).toBeUndefined();
  });

  it('discards notifications when a correction rolls back', async () => {
    const f = fixture();
    await f.subscriber.afterInsert(
      f.event as unknown as InsertEvent<LedgerEntry>,
    );
    f.subscriber.afterTransactionRollback({
      queryRunner: f.runner,
    } as unknown as TransactionRollbackEvent);
    f.runner.isTransactionActive = false;
    await f.subscriber.afterTransactionCommit({
      queryRunner: f.runner,
    } as unknown as TransactionCommitEvent);
    expect(f.sendPush).not.toHaveBeenCalled();
  });
});
