import { describe, expect, it, vi } from 'vitest';
import { Repository } from 'typeorm';
import { AppNotification } from '../database/entities/notification.entity.js';
import { Wallet } from '../database/entities/wallet.entity.js';
import { FcmService } from '../notifications/fcm.service.js';
import { WalletLimitNoticeService } from './wallet-limit-notice.service.js';

describe('WalletLimitNoticeService', () => {
  it('does not fail a completed wallet operation when notification lookup fails', async () => {
    const findOne = vi.fn().mockRejectedValue(new Error('temporary database error'));
    const save = vi.fn();
    const sendPush = vi.fn();
    const service = new WalletLimitNoticeService(
      { findOne, save } as unknown as Repository<AppNotification>,
      { sendPush } as unknown as FcmService,
    );
    const wallet = Object.assign(new Wallet(), {
      id: 'wallet-1',
      name: 'test wallet',
      ownerName: '',
      counterDay: '2026-09-30',
      dailyTopUp: 50_000,
    });

    await expect(service.notifyDailyThreshold(wallet)).resolves.toBeUndefined();
    expect(save).not.toHaveBeenCalled();
    expect(sendPush).not.toHaveBeenCalled();
  });
});
