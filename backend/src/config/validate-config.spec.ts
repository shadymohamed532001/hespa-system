import { describe, expect, it } from 'vitest';
import { validateConfig } from './validate-config.js';

const productionConfig = {
  NODE_ENV: 'production',
  JWT_SECRET: 'a-unique-production-secret-with-more-than-32-characters',
  DB_PASSWORD: 'a-unique-db-password',
  DB_SYNC: 'false',
};

describe('validateConfig', () => {
  it('accepts secure production configuration', () => {
    expect(validateConfig({ ...productionConfig })).toMatchObject(
      productionConfig,
    );
  });

  it.each([
    [{ JWT_SECRET: 'secret' }, 'JWT_SECRET'],
    [{ DB_PASSWORD: 'hesba' }, 'DB_PASSWORD'],
    [{ DB_SYNC: 'true' }, 'DB_SYNC'],
  ])('rejects unsafe production values', (override, message) => {
    expect(() => validateConfig({ ...productionConfig, ...override })).toThrow(
      message,
    );
  });

  it('keeps local development configuration permissive', () => {
    const local = { NODE_ENV: 'development', DB_SYNC: 'true' };
    expect(validateConfig(local)).toBe(local);
  });
});
