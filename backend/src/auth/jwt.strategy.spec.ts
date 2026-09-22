import { UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { describe, expect, it, vi } from 'vitest';
import { UserRole } from '../database/enums.js';
import { JwtStrategy } from './jwt.strategy.js';

function strategyWith(user: unknown) {
  const users = {
    findActiveById: vi.fn().mockResolvedValue(user),
  };
  return new JwtStrategy(
    new ConfigService({ JWT_SECRET: 'unit-test-secret' }),
    users as never,
  );
}

describe('JwtStrategy', () => {
  it('uses the current database role instead of trusting the token role', async () => {
    const strategy = strategyWith({
      id: 'user-1',
      username: 'employee',
      role: UserRole.EMPLOYEE,
      tokenVersion: 2,
    });

    await expect(
      strategy.validate({
        sub: 'user-1',
        username: 'old-name',
        role: UserRole.ADMIN,
        ver: 2,
      }),
    ).resolves.toEqual({
      userId: 'user-1',
      username: 'employee',
      role: UserRole.EMPLOYEE,
    });
  });

  it('rejects a token after the session version changes', async () => {
    const strategy = strategyWith({
      id: 'user-1',
      username: 'employee',
      role: UserRole.EMPLOYEE,
      tokenVersion: 3,
    });

    await expect(
      strategy.validate({
        sub: 'user-1',
        username: 'employee',
        role: UserRole.EMPLOYEE,
        ver: 2,
      }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });
});
