import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { readFileSync } from 'node:fs';
import { getApps, initializeApp, cert, type App } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { Repository } from 'typeorm';
import { DevicePushToken } from '../database/entities/device-push-token.entity.js';

@Injectable()
export class FcmService implements OnModuleInit {
  private readonly logger = new Logger(FcmService.name);
  private app: App | null = null;
  private enabled = false;

  constructor(
    private readonly config: ConfigService,
    @InjectRepository(DevicePushToken)
    private readonly tokens: Repository<DevicePushToken>,
  ) {}

  async onModuleInit() {
    try {
      if (getApps().length) {
        this.app = getApps()[0]!;
        this.enabled = true;
        return;
      }

      const serviceAccount = this.resolveServiceAccount();
      if (!serviceAccount) {
        this.logger.warn(
          'Firebase push disabled: set FIREBASE_SERVICE_ACCOUNT_JSON or FIREBASE_SERVICE_ACCOUNT_PATH',
        );
        return;
      }

      this.app = initializeApp({
        credential: cert(serviceAccount),
        projectId:
          this.config.get<string>('FIREBASE_PROJECT_ID') ?? 'hespa-system',
      });
      this.enabled = true;
      this.logger.log('Firebase Admin initialized for FCM');
    } catch (error) {
      this.logger.warn(
        `Firebase Admin init failed: ${error instanceof Error ? error.message : error}`,
      );
    }
  }

  private resolveServiceAccount(): Record<string, string> | null {
    const json = this.config.get<string>('FIREBASE_SERVICE_ACCOUNT_JSON')?.trim();
    if (json) {
      return JSON.parse(json) as Record<string, string>;
    }

    const path = this.config.get<string>('FIREBASE_SERVICE_ACCOUNT_PATH')?.trim();
    if (path) {
      const raw = readFileSync(path, 'utf8');
      return JSON.parse(raw) as Record<string, string>;
    }

    return null;
  }

  async registerToken(userId: string, token: string, platform: string) {
    const normalized = token.trim();
    if (!normalized) return { ok: false };

    const existing = await this.tokens.findOne({
      where: { token: normalized },
    });
    if (existing) {
      existing.userId = userId;
      existing.platform = platform || existing.platform;
      await this.tokens.save(existing);
      return { ok: true, id: existing.id };
    }

    const saved = await this.tokens.save(
      this.tokens.create({
        userId,
        token: normalized,
        platform: platform || 'unknown',
      }),
    );
    return { ok: true, id: saved.id };
  }

  async unregisterToken(token: string, userId?: string) {
    const normalized = token.trim();
    if (!normalized) return { ok: true };
    const where = userId
      ? { token: normalized, userId }
      : { token: normalized };
    await this.tokens.delete(where);
    return { ok: true };
  }

  async sendPush(input: {
    title: string;
    body: string;
    data?: Record<string, string>;
  }) {
    if (!this.enabled || !this.app) return { sent: 0, skipped: true };

    const rows = await this.tokens.find({ order: { updatedAt: 'DESC' } });
    if (!rows.length) return { sent: 0 };

    const uniqueTokens = [...new Set(rows.map((row) => row.token))];
    let sent = 0;
    const stale: string[] = [];
    const messaging = getMessaging(this.app);

    for (let i = 0; i < uniqueTokens.length; i += 500) {
      const batch = uniqueTokens.slice(i, i + 500);
      try {
        const result = await messaging.sendEachForMulticast({
          tokens: batch,
          notification: {
            title: input.title,
            body: input.body,
          },
          data: input.data,
          apns: {
            payload: {
              aps: {
                sound: 'default',
                contentAvailable: true,
              },
            },
          },
        });

        result.responses.forEach((response, index) => {
          if (response.success) {
            sent += 1;
            return;
          }
          const code = response.error?.code ?? '';
          if (
            code.includes('registration-token-not-registered') ||
            code.includes('invalid-registration-token')
          ) {
            stale.push(batch[index]);
          }
        });
      } catch (error) {
        this.logger.warn(
          `FCM send failed: ${error instanceof Error ? error.message : error}`,
        );
      }
    }

    if (stale.length) {
      await this.tokens
        .createQueryBuilder()
        .delete()
        .where('token IN (:...tokens)', { tokens: stale })
        .execute();
    }

    return { sent };
  }
}
