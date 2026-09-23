import { UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { createHash } from 'node:crypto';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { RefreshToken } from '../database/entities/refresh-token.entity.js';
import { User } from '../database/entities/user.entity.js';
import { ALL_PERMISSIONS, UserRole } from '../database/enums.js';
import { AuthService } from './auth.service.js';

function makeUser(overrides: Partial<User> = {}): User {
  return {
    id: 'user-1',
    username: 'demo',
    displayName: 'Demo',
    passwordHash: 'hash',
    role: UserRole.ADMIN,
    permissions: [],
    limits: {},
    active: true,
    tokenVersion: 0,
    createdAt: new Date(),
    updatedAt: new Date(),
    ...overrides,
  } as User;
}

function hash(raw: string) {
  return createHash('sha256').update(raw).digest('hex');
}

describe('AuthService refresh rotation', () => {
  const users = {
    findOne: vi.fn(),
    exists: vi.fn(),
    save: vi.fn(),
    create: vi.fn(),
  };
  const refreshTokens = {
    findOne: vi.fn(),
    save: vi.fn(async (row: RefreshToken) => row),
    create: vi.fn((value: Partial<RefreshToken>) => ({
      id: 'rt-new',
      ...value,
    })),
    update: vi.fn(),
  };
  const usersService = {
    toPublic: vi.fn((user: User) => ({
      id: user.id,
      username: user.username,
      role: user.role,
    })),
    findActiveById: vi.fn(),
  };
  const jwt = {
    signAsync: vi.fn().mockResolvedValue('access.jwt'),
  };

  let service: AuthService;

  beforeEach(() => {
    vi.clearAllMocks();
    refreshTokens.save.mockImplementation(async (row: RefreshToken) => row);
    refreshTokens.create.mockImplementation((value: Partial<RefreshToken>) => ({
      id: 'rt-new',
      ...value,
    }));
    service = new AuthService(
      users as never,
      refreshTokens as never,
    usersService as never,
      jwt as unknown as JwtService,
      new ConfigService({
        JWT_SECRET: 'unit-test-secret-with-enough-length',
        REFRESH_TOKEN_EXPIRES_IN: '30d',
        SEED_DEMO_DATA: 'false',
        NODE_ENV: 'test',
        ADMIN_RECOVERY_KEY: 'recovery-key-with-at-least-32-characters',
      }),
    );
  });

  it('rotates refresh tokens and returns a new pair', async () => {
    const user = makeUser();
    const raw = 'a'.repeat(48);
    const stored = {
      id: 'rt-old',
      userId: user.id,
      tokenHash: hash(raw),
      tokenVersion: 0,
      expiresAt: new Date(Date.now() + 60_000),
      revokedAt: null,
      replacedById: null,
      createdAt: new Date(),
    } as RefreshToken;

    refreshTokens.findOne.mockResolvedValueOnce(stored);
    users.findOne.mockResolvedValueOnce(user);

    const result = await service.refresh(raw);

    expect(result.accessToken).toBe('access.jwt');
    expect(result.refreshToken).toEqual(expect.any(String));
    expect(result.refreshToken).not.toBe(raw);
    expect(stored.revokedAt).toBeInstanceOf(Date);
    expect(stored.replacedById).toBe('rt-new');
  });

  it('revokes the whole family when a rotated token is reused', async () => {
    const raw = 'b'.repeat(48);
    const stored = {
      id: 'rt-old',
      userId: 'user-1',
      tokenHash: hash(raw),
      tokenVersion: 0,
      expiresAt: new Date(Date.now() + 60_000),
      revokedAt: new Date(),
      replacedById: 'rt-new',
      createdAt: new Date(),
    } as RefreshToken;

    refreshTokens.findOne.mockResolvedValueOnce(stored);

    await expect(service.refresh(raw)).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
    expect(refreshTokens.update).toHaveBeenCalled();
  });

  it('creates a full-permission admin with the configured recovery key', async () => {
    users.exists.mockResolvedValueOnce(false);
    users.create.mockImplementationOnce((value: Partial<User>) => value);
    users.save.mockImplementationOnce(async (value: Partial<User>) =>
      makeUser({
        ...value,
        id: 'recovered-admin',
        createdAt: new Date(),
        updatedAt: new Date(),
      }),
    );

    const result = await service.recoverAdmin({
      recoveryKey: 'recovery-key-with-at-least-32-characters',
      username: 'NewAdmin',
      displayName: 'مدير احتياطي',
      password: 'strong-password',
    });

    expect(result.ok).toBe(true);
    expect(users.create).toHaveBeenCalledWith(
      expect.objectContaining({
        username: 'newadmin',
        role: UserRole.ADMIN,
        permissions: ALL_PERMISSIONS,
        active: true,
      }),
    );
  });

  it('rejects admin recovery with an invalid key', async () => {
    await expect(
      service.recoverAdmin({
        recoveryKey: 'wrong-recovery-key-value',
        username: 'newadmin',
        password: 'strong-password',
      }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    expect(users.exists).not.toHaveBeenCalled();
  });
});
