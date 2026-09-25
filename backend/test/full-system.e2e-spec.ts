import { randomUUID } from 'node:crypto';
import { loadEnvFile } from 'node:process';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { DataSource } from 'typeorm';

try {
  loadEnvFile('.env');
} catch {
  // CI supplies its database settings through the environment.
}

const databaseName = `hesba_full_${process.pid}_${randomUUID().replaceAll('-', '').slice(0, 12)}`;
const databaseSettings = {
  type: 'postgres' as const,
  host: process.env.DB_HOST ?? 'localhost',
  port: Number(process.env.DB_PORT ?? 5432),
  username: process.env.DB_USER ?? 'hesba',
  password: process.env.DB_PASSWORD ?? 'hesba',
};

describe.sequential('full system lifecycle (e2e)', () => {
  let app: INestApplication;
  let administrator: DataSource;
  let dataSource: DataSource;
  let adminToken = '';
  let employeeToken = '';
  let employeeId = '';
  let accountId = '';
  let walletId = '';
  let machineId = '';
  let productId = '';
  let reversedSaleId = '';

  const bearer = (token: string) => ({ Authorization: `Bearer ${token}` });
  const mutation = (token: string, label: string) => ({
    ...bearer(token),
    'Idempotency-Key': `full-${label}-${randomUUID()}`,
  });

  beforeAll(async () => {
    administrator = new DataSource({
      ...databaseSettings,
      database: 'postgres',
    });
    await administrator.initialize();
    await administrator.query(`CREATE DATABASE "${databaseName}"`);

    process.env.NODE_ENV = 'test';
    process.env.DB_NAME = databaseName;
    process.env.DB_SYNC = 'false';
    process.env.MIGRATIONS_RUN = 'true';
    process.env.SEED_DEMO_DATA = 'false';
    process.env.JWT_SECRET =
      'full-system-secret-that-is-longer-than-32-characters';
    process.env.BOOTSTRAP_ADMIN_USERNAME = 'full-admin';
    process.env.BOOTSTRAP_ADMIN_PASSWORD = 'FullSystemAdminPassword123!';

    const { AppModule } = await import('../src/app.module.js');
    const moduleFixture = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.set('trust proxy', true);
    app.setGlobalPrefix('api');
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    );
    await app.init();
    dataSource = app.get(DataSource);
  });

  afterAll(async () => {
    // Audit writes are intentionally non-blocking. Let the final write leave
    // the pool before closing it so teardown remains silent and deterministic.
    await new Promise((resolve) => setTimeout(resolve, 30));
    if (app) await app.close();
    if (administrator?.isInitialized) {
      await administrator.query(
        `SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = $1 AND pid <> pg_backend_pid()`,
        [databaseName],
      );
      await administrator.query(`DROP DATABASE IF EXISTS "${databaseName}"`);
      await administrator.destroy();
    }
  });

  it('boots from an empty database, migrates it, and protects the API', async () => {
    await request(app.getHttpServer())
      .get('/api/health')
      .expect(200)
      .expect(({ body }) => {
        expect(body).toMatchObject({ status: 'ok', database: 'up' });
        expect(body.latencyMs).toBeGreaterThanOrEqual(0);
      });
    await request(app.getHttpServer())
      .get('/api')
      .expect(200)
      .expect('Hesba API is running');
    await request(app.getHttpServer()).get('/api/accounts').expect(401);
    await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({
        username: 'full-admin',
        password: 'wrong-password',
        portal: 'admin',
      })
      .expect(401);

    const login = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({
        username: 'full-admin',
        password: 'FullSystemAdminPassword123!',
        portal: 'admin',
      })
      .expect(201);
    adminToken = login.body.accessToken as string;
    expect(login.body.refreshToken).toEqual(expect.any(String));
    expect(login.body.user.role).toBe('admin');
    expect(login.body.user.permissions).toEqual(
      expect.arrayContaining([
        'reverse_operations',
        'reconcile_balances',
        'daily_rollover',
      ]),
    );

    await request(app.getHttpServer())
      .get('/api/auth/me')
      .set(bearer(adminToken))
      .expect(200)
      .expect(({ body }) => expect(body.username).toBe('full-admin'));

    await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({
        username: 'full-admin',
        password: 'FullSystemAdminPassword123!',
        portal: 'employee',
      })
      .expect(401);
    const migrations = (await dataSource.query(
      `SELECT name FROM schema_migrations ORDER BY id`,
    )) as Array<{ name: string }>;
    expect(migrations.map((row) => row.name)).toEqual([
      'Schema1790087699416',
      'LegacySchemaRepair1790087699417',
      'OperationsHardening1790087699418',
      'RefreshTokens1790087699419',
      'WalletOperations1790087699420',
      'WalletOwner1790087699421',
      'DevicePushTokens1790087699422',
      'WalletCustomerCashFee1790087699424',
    ]);
  });

  it('enforces validation, idempotency, permissions, and employee limits', async () => {
    const catalog = await request(app.getHttpServer())
      .get('/api/users/permission-catalog')
      .set(bearer(adminToken))
      .expect(200);
    expect(catalog.body).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ key: 'reverse_operations' }),
        expect.objectContaining({ key: 'reconcile_balances' }),
      ]),
    );

    const employee = await request(app.getHttpServer())
      .post('/api/users')
      .set(mutation(adminToken, 'create-employee'))
      .send({
        username: 'full-employee',
        password: 'FullEmployeePassword123!',
        displayName: 'موظف الاختبار الشامل',
        role: 'employee',
        permissions: [
          'view_balances',
          'receive_collections',
          'top_up_assets',
          'sell_inventory',
          'use_machines',
        ],
        limits: {
          maxReceiveAmount: 75,
          maxTopUpAmount: 50,
          maxSaleAmount: 100,
          maxTransferAmount: 20,
        },
      })
      .expect(201);
    employeeId = employee.body.id as string;

    const employeeLogin = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({
        username: 'full-employee',
        password: 'FullEmployeePassword123!',
        portal: 'employee',
      })
      .expect(201);
    employeeToken = employeeLogin.body.accessToken as string;

    await request(app.getHttpServer())
      .post('/api/accounts')
      .set(bearer(adminToken))
      .send({ name: 'No idempotency', type: 'company', openingBalance: 0 })
      .expect(400);
    await request(app.getHttpServer())
      .post('/api/accounts')
      .set(mutation(adminToken, 'invalid-account'))
      .send({
        name: 'Invalid payload',
        type: 'not-an-account-type',
        openingBalance: -1,
        unexpected: true,
      })
      .expect(400);
    await request(app.getHttpServer())
      .post('/api/accounts')
      .set(mutation(employeeToken, 'forbidden-create-account'))
      .send({ name: 'Forbidden', type: 'company', openingBalance: 0 })
      .expect(403);

    const accountKey = `full-account-idempotency-${randomUUID()}`;
    const accountBody = {
      name: `الحساب الشامل ${randomUUID()}`,
      type: 'company',
      openingBalance: 1000,
    };
    const created = await request(app.getHttpServer())
      .post('/api/accounts')
      .set({ ...bearer(adminToken), 'Idempotency-Key': accountKey })
      .send(accountBody)
      .expect(201);
    accountId = created.body.id as string;
    const replay = await request(app.getHttpServer())
      .post('/api/accounts')
      .set({ ...bearer(adminToken), 'Idempotency-Key': accountKey })
      .send(accountBody)
      .expect(201);
    expect(replay.body.id).toBe(accountId);
    await request(app.getHttpServer())
      .post('/api/accounts')
      .set({ ...bearer(adminToken), 'Idempotency-Key': accountKey })
      .send({ ...accountBody, name: 'Different request body' })
      .expect(409);

    await request(app.getHttpServer())
      .post('/api/accounts')
      .set(mutation(adminToken, 'fawry-over-limit'))
      .send({
        name: `فوري فوق الحد ${randomUUID()}`,
        type: 'fawry',
        openingBalance: 5_000_001,
      })
      .expect(400);

    const disposable = await request(app.getHttpServer())
      .post('/api/accounts')
      .set(mutation(adminToken, 'disposable-account'))
      .send({
        name: `حساب قابل للحذف ${randomUUID()}`,
        type: 'operating',
        openingBalance: 0,
      })
      .expect(201);
    await request(app.getHttpServer())
      .patch(`/api/accounts/${disposable.body.id}/status`)
      .set(bearer(adminToken))
      .send({ active: false })
      .expect(200);
    const activeAccounts = await request(app.getHttpServer())
      .get('/api/accounts')
      .set(bearer(adminToken))
      .expect(200);
    expect(
      (activeAccounts.body as Array<{ id: string }>).some(
        (item) => item.id === disposable.body.id,
      ),
    ).toBe(false);
    const allAccounts = await request(app.getHttpServer())
      .get('/api/accounts?includeInactive=true')
      .set(bearer(adminToken))
      .expect(200);
    expect(
      (allAccounts.body as Array<{ id: string }>).some(
        (item) => item.id === disposable.body.id,
      ),
    ).toBe(true);
    await request(app.getHttpServer())
      .delete(`/api/accounts/${disposable.body.id}`)
      .set(mutation(adminToken, 'delete-disposable-account'))
      .expect(200)
      .expect(({ body }) => expect(body.deleted).toBe(true));

    const correctionKey = `full-corrected-topup-${randomUUID()}`;
    await request(app.getHttpServer())
      .post(`/api/accounts/${accountId}/top-up`)
      .set({ ...bearer(employeeToken), 'Idempotency-Key': correctionKey })
      .send({ amount: 60 })
      .expect(403);
    await request(app.getHttpServer())
      .post(`/api/accounts/${accountId}/top-up`)
      .set({ ...bearer(employeeToken), 'Idempotency-Key': correctionKey })
      .send({ amount: 40, reference: 'EMPLOYEE-TOPUP' })
      .expect(201)
      .expect(({ body }) => expect(body.balance).toBe(1040));
  });

  it('moves money through accounts, wallets, machines, reversals, and reconciliation', async () => {
    const wallet = await request(app.getHttpServer())
      .post('/api/wallets')
      .set(mutation(adminToken, 'create-wallet'))
      .send({
        name: `المحفظة الشاملة ${randomUUID()}`,
        ownerName: 'صاحب المحفظة التجريبية',
        type: 'vodafone_cash',
        openingBalance: 100,
      })
      .expect(201);
    walletId = wallet.body.id as string;

    const machine = await request(app.getHttpServer())
      .post('/api/machines')
      .set(mutation(adminToken, 'create-machine'))
      .send({
        name: `الماكينة الشاملة ${randomUUID()}`,
        openingBalance: 200,
      })
      .expect(201);
    machineId = machine.body.id as string;

    const topUpKey = `full-account-topup-${randomUUID()}`;
    const topUp = await request(app.getHttpServer())
      .post(`/api/accounts/${accountId}/top-up`)
      .set({ ...bearer(adminToken), 'Idempotency-Key': topUpKey })
      .send({ amount: 100, reference: 'ACCOUNT-TOPUP-100' })
      .expect(201);
    expect(topUp.body.balance).toBe(1140);
    const topUpReplay = await request(app.getHttpServer())
      .post(`/api/accounts/${accountId}/top-up`)
      .set({ ...bearer(adminToken), 'Idempotency-Key': topUpKey })
      .send({ amount: 100, reference: 'ACCOUNT-TOPUP-100' })
      .expect(201);
    expect(topUpReplay.body.balance).toBe(1140);

    await request(app.getHttpServer())
      .post(`/api/wallets/${walletId}/top-up`)
      .set(mutation(adminToken, 'wallet-topup'))
      .send({ amount: 200, reference: 'WALLET-TOPUP-200' })
      .expect(201)
      .expect(({ body }) => {
        expect(body.balance).toBe(300);
        expect(body.dailyTopUp).toBe(200);
        expect(body.monthlyTopUp).toBe(200);
      });
    await request(app.getHttpServer())
      .post(`/api/wallets/${walletId}/use`)
      .set(mutation(adminToken, 'wallet-use'))
      .send({
        amount: 40,
        reference: 'WALLET-USE-40',
        purpose: 'تحويل عميل تجريبي',
      })
      .expect(201)
      .expect(({ body }) => {
        expect(body.wallet.balance).toBe(260);
        expect(body.wallet.commissionBalance).toBe(5);
        expect(body.cashToCollect).toBe(45);
      });
    const walletLedger = await request(app.getHttpServer())
      .get('/api/ledger?limit=500')
      .set(bearer(adminToken))
      .expect(200);
    const walletUsage = (
      walletLedger.body as Array<{
        id: string;
        category: string;
        reference: string;
      }>
    ).find(
      (entry) =>
        entry.reference === 'WALLET-USE-40' &&
        entry.category === 'internal_transfer',
    );
    expect(walletUsage?.category).toBe('internal_transfer');
    await request(app.getHttpServer())
      .post(`/api/ledger/${walletUsage!.id}/reverse`)
      .set(mutation(adminToken, 'reverse-wallet-use'))
      .send({ reason: 'اختبار عكس استخدام المحفظة' })
      .expect(201);
    await request(app.getHttpServer())
      .get('/api/wallets')
      .set(bearer(adminToken))
      .expect(200)
      .expect(({ body }) => {
        const saved = (body as Array<Record<string, unknown>>).find(
          (item) => item.id === walletId,
        );
        expect(saved).toMatchObject({ balance: 300, commissionBalance: 0 });
      });
    await request(app.getHttpServer())
      .post(`/api/machines/${machineId}/load`)
      .set(mutation(adminToken, 'machine-load'))
      .send({ amount: 300, reference: 'MACHINE-LOAD-300' })
      .expect(201)
      .expect(({ body }) => expect(body.remainingBalance).toBe(500));
    await request(app.getHttpServer())
      .post(`/api/machines/${machineId}/use`)
      .set(mutation(employeeToken, 'machine-use'))
      .send({
        serviceType: 'mobile_package',
        customerNumber: '01012345678',
        amount: 120,
        commission: 12,
        reference: 'MACHINE-USE-120',
      })
      .expect(201)
      .expect(({ body }) => {
        expect(body.remainingBalance).toBe(380);
        expect(body.commissionBalance).toBeUndefined();
      });

    await request(app.getHttpServer())
      .post('/api/treasury/transfer')
      .set(mutation(adminToken, 'account-wallet-transfer'))
      .send({
        fromType: 'account',
        fromId: accountId,
        toType: 'wallet',
        toId: walletId,
        amount: 50,
        reference: 'TRANSFER-ACCOUNT-WALLET',
      })
      .expect(201);
    let ledger = await request(app.getHttpServer())
      .get('/api/ledger?limit=500')
      .set(bearer(adminToken))
      .expect(200);
    const transfer = (
      ledger.body as Array<{ id: string; category: string; reference: string }>
    ).find((entry) => entry.reference === 'TRANSFER-ACCOUNT-WALLET');
    expect(transfer?.category).toBe('internal_transfer');
    await request(app.getHttpServer())
      .post(`/api/ledger/${transfer!.id}/reverse`)
      .set(mutation(adminToken, 'reverse-transfer'))
      .send({ reason: 'اختبار عكس التحويل الداخلي' })
      .expect(201);

    await request(app.getHttpServer())
      .post(`/api/accounts/${accountId}/top-up`)
      .set(mutation(adminToken, 'reversible-topup'))
      .send({ amount: 25, reference: 'REVERSIBLE-TOPUP-25' })
      .expect(201);
    ledger = await request(app.getHttpServer())
      .get('/api/ledger?limit=500')
      .set(bearer(adminToken))
      .expect(200);
    const reversibleTopUp = (
      ledger.body as Array<{ id: string; category: string; reference: string }>
    ).find((entry) => entry.reference === 'REVERSIBLE-TOPUP-25');
    expect(reversibleTopUp?.category).toBe('top_up');
    await request(app.getHttpServer())
      .post(`/api/ledger/${reversibleTopUp!.id}/reverse`)
      .set(mutation(adminToken, 'reverse-topup'))
      .send({ reason: 'اختبار عكس شحن الحساب' })
      .expect(201);

    const beforeReconcile = await request(app.getHttpServer())
      .get('/api/treasury/summary')
      .set(bearer(adminToken))
      .expect(200);
    await request(app.getHttpServer())
      .post('/api/treasury/reconcile')
      .set(mutation(adminToken, 'reconcile-treasury'))
      .send({
        assetType: 'treasury',
        countedBalance: Number(beforeReconcile.body.actualBalance) + 5,
        note: 'فرق جرد للاختبار الشامل',
      })
      .expect(201)
      .expect(({ body }) => expect(body.difference).toBe(5));
    ledger = await request(app.getHttpServer())
      .get('/api/ledger?limit=500')
      .set(bearer(adminToken))
      .expect(200);
    const reconciliation = (
      ledger.body as Array<{ id: string; category: string }>
    ).find((entry) => entry.category === 'reconciliation');
    await request(app.getHttpServer())
      .post(`/api/ledger/${reconciliation!.id}/reverse`)
      .set(mutation(adminToken, 'reverse-reconciliation'))
      .send({ reason: 'إلغاء فرق الجرد التجريبي' })
      .expect(201);
    await request(app.getHttpServer())
      .post(`/api/ledger/${reconciliation!.id}/reverse`)
      .set(mutation(adminToken, 'repeat-reconciliation-reversal'))
      .send({ reason: 'محاولة عكس مكرر' })
      .expect(400);

    const machineUsage = (
      ledger.body as Array<{ id: string; category: string; reference: string }>
    ).find(
      (entry) =>
        entry.reference === 'MACHINE-USE-120' &&
        entry.category === 'machine_usage',
    );
    await request(app.getHttpServer())
      .post(`/api/ledger/${machineUsage!.id}/reverse`)
      .set(mutation(employeeToken, 'employee-reverse-machine'))
      .send({ reason: 'موظف بلا صلاحية عكس' })
      .expect(403);
    await request(app.getHttpServer())
      .post(`/api/ledger/${machineUsage!.id}/reverse`)
      .set(mutation(adminToken, 'reverse-machine'))
      .send({ reason: 'عكس استخدام الماكينة وعمولتها' })
      .expect(201);

    const machines = await request(app.getHttpServer())
      .get('/api/machines')
      .set(bearer(adminToken))
      .expect(200);
    expect(
      (machines.body as Array<Record<string, unknown>>).find(
        (item) => item.id === machineId,
      ),
    ).toMatchObject({ remainingBalance: 500, commissionBalance: 0 });
  });

  it('executes and reverses collections without breaking treasury or commission balances', async () => {
    const correctionKey = `full-corrected-collection-${randomUUID()}`;
    const largePayload = {
      agentName: 'مندوب الاختبار',
      companyName: 'شركة الاختبار',
      amount: 80,
      executionMode: 'hold',
    };
    await request(app.getHttpServer())
      .post('/api/collections/receive')
      .set({ ...bearer(employeeToken), 'Idempotency-Key': correctionKey })
      .send(largePayload)
      .expect(403);
    const hold = await request(app.getHttpServer())
      .post('/api/collections/receive')
      .set({ ...bearer(employeeToken), 'Idempotency-Key': correctionKey })
      .send({ ...largePayload, amount: 50 })
      .expect(201);
    expect(hold.body.status).toBe('pending');

    const pendingSummary = await request(app.getHttpServer())
      .get('/api/treasury/summary')
      .set(bearer(adminToken))
      .expect(200);
    expect(pendingSummary.body).toMatchObject({
      actualBalance: 50,
      pendingAmount: 50,
      availableBalance: 0,
    });

    await request(app.getHttpServer())
      .post(`/api/collections/${hold.body.id}/execute`)
      .set(mutation(adminToken, 'execute-hold'))
      .send({ accountId, commission: 5 })
      .expect(201)
      .expect(({ body }) => expect(body.status).toBe('done'));
    await request(app.getHttpServer())
      .post(`/api/collections/${hold.body.id}/reverse`)
      .set(mutation(adminToken, 'reverse-hold'))
      .send({ reason: 'إلغاء التحصيل المعلق بعد التنفيذ' })
      .expect(201);
    await request(app.getHttpServer())
      .post(`/api/collections/${hold.body.id}/reverse`)
      .set(mutation(adminToken, 'reverse-hold-twice'))
      .send({ reason: 'محاولة عكس التحصيل مرتين' })
      .expect(400);

    const immediate = await request(app.getHttpServer())
      .post('/api/collections/receive')
      .set(mutation(adminToken, 'immediate-collection'))
      .send({
        agentName: 'مندوب دائم',
        companyName: 'شركة دائمة',
        amount: 30,
        executionMode: 'immediate',
        accountId,
        commission: 3,
      })
      .expect(201);
    expect(immediate.body.status).toBe('done');

    const finalSummary = await request(app.getHttpServer())
      .get('/api/treasury/summary')
      .set(bearer(adminToken))
      .expect(200);
    expect(finalSummary.body).toMatchObject({
      actualBalance: 30,
      pendingAmount: 0,
      availableBalance: 30,
    });
    const accounts = await request(app.getHttpServer())
      .get('/api/accounts')
      .set(bearer(adminToken))
      .expect(200);
    expect(
      (accounts.body as Array<Record<string, unknown>>).find(
        (item) => item.id === accountId,
      ),
    ).toMatchObject({ balance: 1110, commissionBalance: 3 });
  });

  it('tracks weighted inventory cost, profit, stock movements, limits, and sale reversal', async () => {
    const product = await request(app.getHttpServer())
      .post('/api/inventory/products')
      .set(mutation(adminToken, 'create-product'))
      .send({
        name: `منتج الاختبار الشامل ${randomUUID()}`,
        category: 'mobile',
        openingStock: 5,
        defaultPrice: 180,
        costPrice: 100,
      })
      .expect(201);
    productId = product.body.id as string;
    await request(app.getHttpServer())
      .post(`/api/inventory/products/${productId}/stock-in`)
      .set(mutation(adminToken, 'stock-in'))
      .send({
        quantity: 5,
        unitCost: 200,
        supplier: 'مورد الاختبار',
        note: 'فاتورة توريد تجريبية',
      })
      .expect(201)
      .expect(({ body }) => {
        expect(body.stockQty).toBe(10);
        expect(body.costPrice).toBe(150);
      });

    const adminSale = await request(app.getHttpServer())
      .post(`/api/inventory/products/${productId}/sell`)
      .set(mutation(adminToken, 'admin-sale'))
      .send({ quantity: 2, unitPrice: 220, note: 'بيع سيُعكس' })
      .expect(201);
    reversedSaleId = adminSale.body.sale.id as string;
    expect(adminSale.body.sale).toMatchObject({
      unitCost: 150,
      totalAmount: 440,
      grossProfit: 140,
    });

    const correctionKey = `full-corrected-sale-${randomUUID()}`;
    await request(app.getHttpServer())
      .post(`/api/inventory/products/${productId}/sell`)
      .set({ ...bearer(employeeToken), 'Idempotency-Key': correctionKey })
      .send({ quantity: 2, unitPrice: 80 })
      .expect(403);
    const employeeSale = await request(app.getHttpServer())
      .post(`/api/inventory/products/${productId}/sell`)
      .set({ ...bearer(employeeToken), 'Idempotency-Key': correctionKey })
      .send({ quantity: 1, unitPrice: 80, note: 'بيع داخل الحد' })
      .expect(201);
    expect(employeeSale.body.sale.grossProfit).toBeUndefined();

    await request(app.getHttpServer())
      .post(`/api/inventory/products/${productId}/sell`)
      .set(mutation(adminToken, 'oversell'))
      .send({ quantity: 1000, unitPrice: 220 })
      .expect(400);
    await request(app.getHttpServer())
      .post(`/api/inventory/sales/${reversedSaleId}/reverse`)
      .set(mutation(adminToken, 'reverse-sale'))
      .send({ reason: 'إلغاء البيع وإرجاع القطعتين' })
      .expect(201);

    const products = await request(app.getHttpServer())
      .get('/api/inventory/products')
      .set(bearer(adminToken))
      .expect(200);
    expect(
      (products.body as Array<Record<string, unknown>>).find(
        (item) => item.id === productId,
      ),
    ).toMatchObject({ stockQty: 9, soldQty: 1, costPrice: 150 });

    const summary = await request(app.getHttpServer())
      .get('/api/inventory/treasury/summary')
      .set(bearer(adminToken))
      .expect(200);
    expect(summary.body).toMatchObject({
      balance: 80,
      salesCount: 1,
      salesTotal: 80,
      grossProfit: -70,
      soldUnitsRecorded: 1,
    });
    const movements = await request(app.getHttpServer())
      .get('/api/inventory/movements?limit=100')
      .set(bearer(adminToken))
      .expect(200);
    expect(
      (movements.body as Array<{ type: string }>).map((row) => row.type),
    ).toEqual(
      expect.arrayContaining(['opening', 'stock_in', 'sale', 'reversal']),
    );
  });

  it('keeps ledger, reports, notifications, and audit data consistent', async () => {
    const range = {
      from: new Date(Date.now() - 86_400_000).toISOString(),
      to: new Date(Date.now() + 86_400_000).toISOString(),
      entityType: 'all',
    };
    const report = await request(app.getHttpServer())
      .get('/api/reports/summary')
      .set(bearer(adminToken))
      .query(range)
      .expect(200);
    expect(report.body.summary).toMatchObject({
      commissions: 3,
      salesAmount: 80,
      salesCount: 1,
      soldUnits: 1,
      grossProfit: -70,
      collectionsAmount: 30,
      collectionsCount: 1,
      pendingCollectionsCount: 0,
    });
    expect(report.body.inventory).toMatchObject({
      currentBalance: 80,
      stockUnits: 9,
      stockValue: 1350,
    });
    expect(report.body.operations.length).toBeGreaterThan(10);
    expect(report.body.daily).toHaveLength(3);
    expect(
      (report.body.daily as Array<{ operationCount: number }>).some(
        (row) => row.operationCount > 10,
      ),
    ).toBe(true);
    await request(app.getHttpServer())
      .get('/api/reports/summary')
      .set(bearer(adminToken))
      .query({
        from: '2024-01-01T00:00:00.000Z',
        to: '2026-01-03T00:00:00.000Z',
        entityType: 'all',
      })
      .expect(400);

    const inventoryReport = await request(app.getHttpServer())
      .get('/api/reports/summary')
      .set(bearer(adminToken))
      .query({ ...range, entityType: 'inventory' })
      .expect(200);
    expect(inventoryReport.body.summary).toMatchObject({
      salesAmount: 80,
      salesCount: 1,
    });
    expect(
      (inventoryReport.body.operations as Array<{ entityType: string }>).every(
        (row) => row.entityType === 'inventory',
      ),
    ).toBe(true);

    const notifications = await request(app.getHttpServer())
      .get('/api/notifications?limit=100')
      .set(bearer(adminToken))
      .expect(200);
    expect(notifications.body.length).toBeGreaterThan(10);
    expect(
      (notifications.body as Array<{ title: string }>).some((item) =>
        item.title.includes('عمولة'),
      ),
    ).toBe(true);
    await request(app.getHttpServer())
      .patch(`/api/notifications/${notifications.body[0].id}/read`)
      .set(bearer(adminToken))
      .expect(200)
      .expect(({ body }) => expect(body.isRead).toBe(true));
    await request(app.getHttpServer())
      .post('/api/notifications/read-all')
      .set(bearer(adminToken))
      .expect(201);
    await request(app.getHttpServer())
      .get('/api/notifications/unread-count')
      .set(bearer(adminToken))
      .expect(200)
      .expect(({ body }) => expect(body.count).toBe(0));

    await request(app.getHttpServer())
      .get('/api/audit-events')
      .set(bearer(employeeToken))
      .expect(403);
    const audit = await request(app.getHttpServer())
      .get('/api/audit-events?limit=500')
      .set(bearer(adminToken))
      .expect(200);
    expect(audit.body.length).toBeGreaterThan(20);
    expect(
      (audit.body as Array<{ success: boolean }>).some(
        (event) => event.success === false,
      ),
    ).toBe(true);
    expect(JSON.stringify(audit.body)).not.toContain(
      'FullSystemAdminPassword123!',
    );
    expect(JSON.stringify(audit.body)).not.toContain(
      'FullEmployeePassword123!',
    );
  });

  it('closes the day once, revokes stale sessions, and satisfies database invariants', async () => {
    const close = await request(app.getHttpServer())
      .post('/api/treasury/close-day')
      .set(mutation(adminToken, 'close-day'))
      .send({ note: 'إقفال الاختبار الشامل' })
      .expect(201);
    expect(close.body).toMatchObject({
      closed: true,
      accounts: 1,
      wallets: 1,
      machines: 1,
    });
    expect(close.body.close).toMatchObject({
      totalAssets: 1940,
      pendingCollections: 0,
      closedBy: 'full-admin',
    });
    expect(close.body.close.snapshot).toMatchObject({
      treasury: { balance: 30 },
    });
    await request(app.getHttpServer())
      .post('/api/treasury/close-day')
      .set(mutation(adminToken, 'repeat-close-day'))
      .send({})
      .expect(201)
      .expect(({ body }) =>
        expect(body).toMatchObject({ closed: false, alreadyClosed: true }),
      );
    await request(app.getHttpServer())
      .get('/api/treasury/daily-closes')
      .set(bearer(adminToken))
      .expect(200)
      .expect(({ body }) => expect(body).toHaveLength(1));

    const accountsAfterClose = await request(app.getHttpServer())
      .get('/api/accounts')
      .set(bearer(adminToken))
      .expect(200);
    expect(
      (accountsAfterClose.body as Array<Record<string, unknown>>).find(
        (item) => item.id === accountId,
      ),
    ).toMatchObject({ balance: 1110, openingBalance: 1110, todayTopUp: 0 });

    await request(app.getHttpServer())
      .patch(`/api/users/${employeeId}`)
      .set(mutation(adminToken, 'change-employee-permissions'))
      .send({ permissions: ['view_balances'] })
      .expect(200);
    await request(app.getHttpServer())
      .get('/api/auth/me')
      .set(bearer(employeeToken))
      .expect(401);
    const renewedLogin = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({
        username: 'full-employee',
        password: 'FullEmployeePassword123!',
        portal: 'employee',
      })
      .expect(201);
    const renewedToken = renewedLogin.body.accessToken as string;
    await request(app.getHttpServer())
      .post(`/api/accounts/${accountId}/top-up`)
      .set(mutation(renewedToken, 'removed-topup-permission'))
      .send({ amount: 1 })
      .expect(403);
    await request(app.getHttpServer())
      .patch(`/api/users/${employeeId}/status`)
      .set(mutation(adminToken, 'disable-employee'))
      .send({ active: false })
      .expect(200);
    await request(app.getHttpServer())
      .get('/api/auth/me')
      .set(bearer(renewedToken))
      .expect(401);
    await request(app.getHttpServer())
      .post('/api/auth/login')
      .set('X-Forwarded-For', '198.51.100.24')
      .send({
        username: 'full-employee',
        password: 'FullEmployeePassword123!',
        portal: 'employee',
      })
      .expect(401);

    const currentAdmin = await request(app.getHttpServer())
      .get('/api/auth/me')
      .set(bearer(adminToken))
      .expect(200);
    await request(app.getHttpServer())
      .delete(`/api/users/${currentAdmin.body.id}`)
      .set(mutation(adminToken, 'reject-self-delete'))
      .expect(400)
      .expect(({ body }) =>
        expect(body.message).toBe('لا يمكنك حذف حسابك الحالي'),
      );

    await request(app.getHttpServer())
      .delete(`/api/users/${employeeId}`)
      .set(mutation(adminToken, 'delete-employee'))
      .expect(200)
      .expect(({ body }) =>
        expect(body).toMatchObject({ ok: true, id: employeeId }),
      );
    await request(app.getHttpServer())
      .get('/api/users')
      .set(bearer(adminToken))
      .expect(200)
      .expect(({ body }) =>
        expect(body).not.toEqual(
          expect.arrayContaining([expect.objectContaining({ id: employeeId })]),
        ),
      );

    const [{ refresh_tokens: deletedUserRefreshTokens }] =
      (await dataSource.query(
        `SELECT count(*) AS refresh_tokens FROM refresh_tokens WHERE user_id = $1`,
        [employeeId],
      )) as Array<{ refresh_tokens: string }>;
    expect(deletedUserRefreshTokens).toBe('0');

    const [invariants] = (await dataSource.query(`
      SELECT
        (SELECT count(*) FROM financial_accounts WHERE balance < 0 OR commission_balance < 0) AS negative_accounts,
        (SELECT count(*) FROM wallets WHERE balance < 0 OR commission_balance < 0) AS negative_wallets,
        (SELECT count(*) FROM machines WHERE loaded_balance < used_balance OR commission_balance < 0) AS invalid_machines,
        (SELECT count(*) FROM inventory_products WHERE stock_qty < 0 OR sold_qty < 0) AS invalid_stock,
        (SELECT count(*) FROM idempotency_records WHERE status <> 'completed') AS unfinished_idempotency,
        (SELECT count(*) FROM daily_closes) AS close_count,
        (SELECT count(*) FROM ledger_entries WHERE reverses_entry_id IS NOT NULL) AS reversal_count,
        (SELECT count(*) FROM inventory_sales WHERE reversed_at IS NOT NULL) AS reversed_sales,
        (SELECT count(*) FROM inventory_stock_movements movement LEFT JOIN inventory_products product ON product.id = movement.product_id WHERE product.id IS NULL) AS orphan_movements,
        (SELECT count(*) FROM audit_events WHERE details::text LIKE '%FullSystem%Password%') AS leaked_passwords
    `)) as Array<Record<string, string>>;
    expect(invariants).toMatchObject({
      negative_accounts: '0',
      negative_wallets: '0',
      invalid_machines: '0',
      invalid_stock: '0',
      unfinished_idempotency: '0',
      close_count: '1',
      reversed_sales: '1',
      orphan_movements: '0',
      leaked_passwords: '0',
    });
    expect(Number(invariants.reversal_count)).toBeGreaterThanOrEqual(7);
  });
});
