import { randomUUID } from 'node:crypto';
import { loadEnvFile } from 'node:process';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { DataSource } from 'typeorm';

try {
  loadEnvFile('.env');
} catch {
  // CI may provide every setting directly through its environment.
}

const databaseName = `hesba_e2e_${process.pid}_${randomUUID().replaceAll('-', '').slice(0, 12)}`;
const databaseSettings = {
  type: 'postgres' as const,
  host: process.env.DB_HOST ?? 'localhost',
  port: Number(process.env.DB_PORT ?? 5432),
  username: process.env.DB_USER ?? 'hesba',
  password: process.env.DB_PASSWORD ?? 'hesba',
};

describe('financial operations (e2e)', () => {
  let app: INestApplication;
  let administrator: DataSource;
  let token: string;

  beforeAll(async () => {
    administrator = new DataSource({
      ...databaseSettings,
      database: 'postgres',
    });
    await administrator.initialize();
    await administrator.query(`CREATE DATABASE "${databaseName}"`);

    // Start from a representative synchronize-era database. The migrations
    // must adopt it without dropping this table or its data.
    const legacy = new DataSource({
      ...databaseSettings,
      database: databaseName,
    });
    await legacy.initialize();
    await legacy.query(`CREATE EXTENSION IF NOT EXISTS "uuid-ossp"`);
    await legacy.query(
      `CREATE TYPE "public"."users_role_enum" AS ENUM('admin', 'employee')`,
    );
    await legacy.query(`
      CREATE TABLE "users" (
        "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        "username" varchar(80) NOT NULL UNIQUE,
        "password_hash" varchar NOT NULL,
        "role" "public"."users_role_enum" NOT NULL,
        "active" boolean NOT NULL DEFAULT true,
        "created_at" timestamp NOT NULL DEFAULT now(),
        "updated_at" timestamp NOT NULL DEFAULT now()
      )
    `);
    await legacy.query(`
      INSERT INTO "users" ("username", "password_hash", "role")
      VALUES ('legacy-user', 'legacy-password-hash', 'employee')
    `);
    await legacy.destroy();

    process.env.NODE_ENV = 'test';
    process.env.DB_NAME = databaseName;
    process.env.DB_SYNC = 'false';
    process.env.MIGRATIONS_RUN = 'true';
    process.env.SEED_DEMO_DATA = 'false';
    process.env.JWT_SECRET =
      process.env.JWT_SECRET ??
      'e2e-only-secret-that-is-longer-than-32-characters';
    process.env.BOOTSTRAP_ADMIN_USERNAME = 'e2e-admin';
    process.env.BOOTSTRAP_ADMIN_PASSWORD = 'e2e-password-123';

    const { AppModule } = await import('../src/app.module.js');
    const moduleFixture = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.setGlobalPrefix('api');
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    );
    await app.init();

    const login = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ username: 'e2e-admin', password: 'e2e-password-123' })
      .expect(201);
    token = login.body.accessToken as string;
  }, 30_000);

  afterAll(async () => {
    if (app) await app.close();
    if (administrator?.isInitialized) {
      await administrator.query(
        `SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = $1 AND pid <> pg_backend_pid()`,
        [databaseName],
      );
      await administrator.query(`DROP DATABASE IF EXISTS "${databaseName}"`);
      await administrator.destroy();
    }
  }, 30_000);

  const mutation = (key: string) => ({
    Authorization: `Bearer ${token}`,
    'Idempotency-Key': key,
  });

  it('migrates a legacy database and exposes the protected API', async () => {
    await request(app.getHttpServer())
      .get('/api/auth/me')
      .set('Authorization', `Bearer ${token}`)
      .expect(200)
      .expect(({ body }) => {
        expect(body.username).toBe('e2e-admin');
        expect(body.permissions).toContain('manage_assets');
      });

    await request(app.getHttpServer())
      .get('/api/users')
      .set('Authorization', `Bearer ${token}`)
      .expect(200)
      .expect(({ body }) => {
        expect(
          (body as Array<{ username: string }>).some(
            (user) => user.username === 'legacy-user',
          ),
        ).toBe(true);
      });
  });

  it('applies a concurrent idempotent top-up only once and replays it', async () => {
    const created = await request(app.getHttpServer())
      .post('/api/accounts')
      .set(mutation(`create-account-${randomUUID()}`))
      .send({
        name: `Idempotency ${randomUUID()}`,
        type: 'company',
        openingBalance: 1000,
      })
      .expect(201);
    const id = created.body.id as string;
    const key = `same-top-up-${randomUUID()}`;

    const responses = await Promise.all([
      request(app.getHttpServer())
        .post(`/api/accounts/${id}/top-up`)
        .set(mutation(key))
        .send({ amount: 100 }),
      request(app.getHttpServer())
        .post(`/api/accounts/${id}/top-up`)
        .set(mutation(key))
        .send({ amount: 100 }),
    ]);
    expect(
      responses.every((response) => [201, 409].includes(response.status)),
    ).toBe(true);

    await request(app.getHttpServer())
      .post(`/api/accounts/${id}/top-up`)
      .set(mutation(key))
      .send({ amount: 100 })
      .expect(201);

    const accounts = await request(app.getHttpServer())
      .get('/api/accounts')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    const account = (
      accounts.body as Array<{ id: string; balance: number }>
    ).find((item) => item.id === id);
    expect(account?.balance).toBe(1100);
  });

  it('finishes reverse concurrent transfers without deadlock or lost money', async () => {
    const suffix = randomUUID();
    const [left, right] = await Promise.all(
      ['Left', 'Right'].map((label) =>
        request(app.getHttpServer())
          .post('/api/accounts')
          .set(mutation(`create-${label}-${suffix}`))
          .send({
            name: `${label} ${suffix}`,
            type: 'company',
            openingBalance: 500,
          }),
      ),
    );
    expect(left.status).toBe(201);
    expect(right.status).toBe(201);

    const transfers = await Promise.all([
      request(app.getHttpServer())
        .post('/api/treasury/transfer')
        .set(mutation(`transfer-left-${suffix}`))
        .send({
          fromType: 'account',
          fromId: left.body.id,
          toType: 'account',
          toId: right.body.id,
          amount: 75,
        }),
      request(app.getHttpServer())
        .post('/api/treasury/transfer')
        .set(mutation(`transfer-right-${suffix}`))
        .send({
          fromType: 'account',
          fromId: right.body.id,
          toType: 'account',
          toId: left.body.id,
          amount: 75,
        }),
    ]);
    expect(transfers.map((response) => response.status)).toEqual([201, 201]);

    const accounts = await request(app.getHttpServer())
      .get('/api/accounts')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    const balances = new Map<string, number>(
      (accounts.body as Array<{ id: string; balance: number }>).map((item) => [
        item.id,
        item.balance,
      ]),
    );
    expect(balances.get(left.body.id)).toBe(500);
    expect(balances.get(right.body.id)).toBe(500);
  });

  it('allocates unique references for concurrent collection receipts', async () => {
    const suffix = randomUUID();
    const account = await request(app.getHttpServer())
      .post('/api/accounts')
      .set(mutation(`create-collection-account-${suffix}`))
      .send({
        name: `Collections ${suffix}`,
        type: 'company',
        openingBalance: 1000,
      })
      .expect(201);

    const receipts = await Promise.all(
      [1, 2].map((number) =>
        request(app.getHttpServer())
          .post('/api/collections/receive')
          .set(mutation(`collection-${number}-${suffix}`))
          .send({
            agentName: `Agent ${number}`,
            companyName: 'Concurrent company',
            amount: 25,
            executionMode: 'immediate',
            accountId: account.body.id,
            commission: 1,
          }),
      ),
    );
    expect(receipts.map((response) => response.status)).toEqual([201, 201]);
    expect(
      new Set(receipts.map((response) => response.body.reference)).size,
    ).toBe(2);
  });

  it('enforces the wallet daily limit under concurrent top-ups', async () => {
    const suffix = randomUUID();
    const wallet = await request(app.getHttpServer())
      .post('/api/wallets')
      .set(mutation(`create-wallet-${suffix}`))
      .send({ name: `Wallet ${suffix}`, type: 'wallet', openingBalance: 0 })
      .expect(201);

    const topUps = await Promise.all(
      [1, 2].map((number) =>
        request(app.getHttpServer())
          .post(`/api/wallets/${wallet.body.id}/top-up`)
          .set(mutation(`wallet-top-up-${number}-${suffix}`))
          .send({ amount: 40000 }),
      ),
    );
    expect(
      topUps.map((response) => response.status).sort((a, b) => a - b),
    ).toEqual([201, 400]);

    const wallets = await request(app.getHttpServer())
      .get('/api/wallets')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    const saved = (wallets.body as Array<{ id: string; balance: number }>).find(
      (item) => item.id === wallet.body.id,
    );
    expect(saved?.balance).toBe(40000);
  });

  it('prevents concurrent machine usage from overspending its balance', async () => {
    const suffix = randomUUID();
    const machine = await request(app.getHttpServer())
      .post('/api/machines')
      .set(mutation(`create-machine-${suffix}`))
      .send({ name: `Machine ${suffix}`, openingBalance: 100 })
      .expect(201);

    const uses = await Promise.all(
      [1, 2].map((number) =>
        request(app.getHttpServer())
          .post(`/api/machines/${machine.body.id}/use`)
          .set(mutation(`machine-use-${number}-${suffix}`))
          .send({ amount: 80, commission: 2 }),
      ),
    );
    expect(
      uses.map((response) => response.status).sort((a, b) => a - b),
    ).toEqual([201, 400]);

    const machines = await request(app.getHttpServer())
      .get('/api/machines')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    const saved = (
      machines.body as Array<{ id: string; remainingBalance: number }>
    ).find((item) => item.id === machine.body.id);
    expect(saved?.remainingBalance).toBe(20);
  });

  it('prevents two concurrent sales from consuming the same stock unit', async () => {
    const suffix = randomUUID();
    const product = await request(app.getHttpServer())
      .post('/api/inventory/products')
      .set(mutation(`create-product-${suffix}`))
      .send({
        name: `Product ${suffix}`,
        category: 'accessory',
        openingStock: 1,
        defaultPrice: 125,
      })
      .expect(201);

    const sales = await Promise.all(
      [1, 2].map((number) =>
        request(app.getHttpServer())
          .post(`/api/inventory/products/${product.body.id}/sell`)
          .set(mutation(`inventory-sale-${number}-${suffix}`))
          .send({ quantity: 1, unitPrice: 125 }),
      ),
    );
    expect(
      sales.map((response) => response.status).sort((a, b) => a - b),
    ).toEqual([201, 400]);

    const products = await request(app.getHttpServer())
      .get('/api/inventory/products')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    const saved = (
      products.body as Array<{ id: string; stockQty: number }>
    ).find((item) => item.id === product.body.id);
    expect(saved?.stockQty).toBe(0);
  });

  it('records and reverses machine usage with its commission', async () => {
    const suffix = randomUUID();
    const machine = await request(app.getHttpServer())
      .post('/api/machines')
      .set(mutation(`commission-machine-${suffix}`))
      .send({ name: `Commission ${suffix}`, openingBalance: 500 })
      .expect(201);
    await request(app.getHttpServer())
      .post(`/api/machines/${machine.body.id}/use`)
      .set(mutation(`commission-use-${suffix}`))
      .send({ amount: 100, commission: 7, reference: `USE-${suffix}` })
      .expect(201);

    const before = await request(app.getHttpServer())
      .get('/api/ledger?limit=500')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    const usage = (
      before.body as Array<{
        id: string;
        category: string;
        entityId: string;
      }>
    ).find(
      (entry) =>
        entry.category === 'machine_usage' && entry.entityId === machine.body.id,
    );
    expect(usage).toBeTruthy();

    await request(app.getHttpServer())
      .post(`/api/ledger/${usage!.id}/reverse`)
      .set(mutation(`reverse-machine-${suffix}`))
      .send({ reason: 'اختبار عكس عملية الماكينة' })
      .expect(201);

    const machines = await request(app.getHttpServer())
      .get('/api/machines')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    const saved = (
      machines.body as Array<{
        id: string;
        remainingBalance: number;
        commissionBalance: number;
      }>
    ).find((item) => item.id === machine.body.id);
    expect(saved?.remainingBalance).toBe(500);
    expect(saved?.commissionBalance).toBe(0);
  });

  it('tracks inventory cost and restores stock when a sale is reversed', async () => {
    const suffix = randomUUID();
    const product = await request(app.getHttpServer())
      .post('/api/inventory/products')
      .set(mutation(`profit-product-${suffix}`))
      .send({
        name: `Profit ${suffix}`,
        category: 'mobile',
        openingStock: 2,
        defaultPrice: 150,
        costPrice: 90,
      })
      .expect(201);
    const sold = await request(app.getHttpServer())
      .post(`/api/inventory/products/${product.body.id}/sell`)
      .set(mutation(`profit-sale-${suffix}`))
      .send({ quantity: 1, unitPrice: 150 })
      .expect(201);
    expect(sold.body.sale.grossProfit).toBe(60);

    await request(app.getHttpServer())
      .post(`/api/inventory/sales/${sold.body.sale.id}/reverse`)
      .set(mutation(`profit-reversal-${suffix}`))
      .send({ reason: 'إلغاء البيع التجريبي' })
      .expect(201);
    const products = await request(app.getHttpServer())
      .get('/api/inventory/products')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    const restored = (
      products.body as Array<{ id: string; stockQty: number; soldQty: number }>
    ).find((item) => item.id === product.body.id);
    expect(restored).toMatchObject({ stockQty: 2, soldQty: 0 });
  });

  it('reverses a collection atomically and preserves its audit trail', async () => {
    const suffix = randomUUID();
    const account = await request(app.getHttpServer())
      .post('/api/accounts')
      .set(mutation(`reverse-collection-account-${suffix}`))
      .send({
        name: `Reverse collection ${suffix}`,
        type: 'company',
        openingBalance: 1000,
      })
      .expect(201);
    const receipt = await request(app.getHttpServer())
      .post('/api/collections/receive')
      .set(mutation(`reverse-collection-${suffix}`))
      .send({
        agentName: 'مندوب اختبار',
        companyName: 'شركة اختبار',
        amount: 100,
        executionMode: 'immediate',
        accountId: account.body.id,
        commission: 5,
      })
      .expect(201);
    await request(app.getHttpServer())
      .post(`/api/collections/${receipt.body.id}/reverse`)
      .set(mutation(`reverse-collection-action-${suffix}`))
      .send({ reason: 'تحصيل مسجل بالخطأ' })
      .expect(201);

    const collections = await request(app.getHttpServer())
      .get('/api/collections')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    const reversed = (
      collections.body as Array<{ id: string; status: string }>
    ).find((item) => item.id === receipt.body.id);
    expect(reversed?.status).toBe('reversed');
  });

  it('reconciles the treasury and closes a business day only once', async () => {
    const current = await request(app.getHttpServer())
      .get('/api/treasury/summary')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    const counted = Number(current.body.actualBalance) + 10;
    await request(app.getHttpServer())
      .post('/api/treasury/reconcile')
      .set(mutation(`reconcile-${randomUUID()}`))
      .send({
        assetType: 'treasury',
        countedBalance: counted,
        note: 'جرد اختبار',
      })
      .expect(201)
      .expect(({ body }) => expect(body.difference).toBe(10));

    const first = await request(app.getHttpServer())
      .post('/api/treasury/close-day')
      .set(mutation(`close-day-${randomUUID()}`))
      .send({ note: 'إقفال اختبار' })
      .expect(201);
    expect(first.body.closed).toBe(true);
    expect(first.body.close.snapshot).toBeTruthy();

    const second = await request(app.getHttpServer())
      .post('/api/treasury/close-day')
      .set(mutation(`close-day-repeat-${randomUUID()}`))
      .send({})
      .expect(201);
    expect(second.body).toMatchObject({ closed: false, alreadyClosed: true });
  });
});
