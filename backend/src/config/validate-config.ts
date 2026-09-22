const INSECURE_JWT_SECRETS = new Set([
  'change-this-secret-before-production',
  'secret',
  'hesba',
]);

export function validateConfig(config: Record<string, unknown>) {
  const readString = (key: string, fallback = '') => {
    const value = config[key];
    return typeof value === 'string' || typeof value === 'number'
      ? String(value)
      : fallback;
  };

  const environment = readString('NODE_ENV', 'development');
  if (environment !== 'production') return config;

  const jwtSecret = readString('JWT_SECRET');
  if (jwtSecret.length < 32 || INSECURE_JWT_SECRETS.has(jwtSecret)) {
    throw new Error(
      'Production requires a unique JWT_SECRET of at least 32 characters',
    );
  }

  const databasePassword = readString('DB_PASSWORD');
  if (databasePassword.length < 16 || databasePassword === 'hesba') {
    throw new Error(
      'Production requires a unique DB_PASSWORD of at least 16 characters',
    );
  }

  if (readString('DB_SYNC', 'false') === 'true') {
    throw new Error(
      'DB_SYNC must be false in production; run migrations instead',
    );
  }

  return config;
}
