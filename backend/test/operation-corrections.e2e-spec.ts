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

const databaseName = `hesba_corrections_${process.pid}_${randomUUID().replaceAll('-', '').slice(0, 12)}`;
const databaseSettings = {
  type: 'postgres' as const,
  host: process.env.DB_HOST ?? 'localhost',
  port: Number(process.env.DB_PORT ?? 5432),
  username: process.env.DB_USER ?? 'hesba',
  password: process.env.DB_PASSWORD ?? 'hesba',
};

describe.sequential('admin operation corrections (e2e)', () => {
  let app: INestApplication;
  let administrator: DataSource;
  let dataSource: DataSource;
  let adminToken = '';
  let employeeToken = '';
  let accountId = '';
  let walletId = '';
  let machineId = '';
  let productId = '';

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

  const post = (path: string, body: object, status = 201, token?: string) =>
    request(app.getHttpServer())
      .post(`/api${path}`)
      .set(mutation(token ?? adminToken, 'correction'))
      .send(body)
      .expect(status);
  const get = (path: string, token?: string) =>
    request(app.getHttpServer())
      .get(`/api${path}`)
      .set(bearer(token ?? adminToken))
      .expect(200);
  const entry = async (reference: string, category?: string) => {
    const rows = (await get('/ledger?limit=500')).body;
    const found = rows.find(
      (e: any) =>
        e.reference === reference &&
        (!category || e.category === category) &&
        !e.isReversed &&
        e.category !== 'reversal',
    );
    expect(found).toBeTruthy();
    return found;
  };
  const balance = async (path: string, id: string) =>
    (await get(path)).body.find((a: any) => a.id === id);

  beforeAll(async () => {
    const login = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({
        username: 'full-admin',
        password: 'FullSystemAdminPassword123!',
        portal: 'admin',
      })
      .expect(201);
    adminToken = login.body.accessToken;
    await post('/treasury/reconcile', {
      assetType: 'treasury',
      countedBalance: 100000,
    });
    accountId = (
      await post('/accounts', {
        name: 'Correction company',
        type: 'company',
        openingBalance: 10000,
      })
    ).body.id;
    walletId = (
      await post('/wallets', {
        name: 'Correction wallet',
        type: 'vodafone_cash',
        openingBalance: 10000,
      })
    ).body.id;
    machineId = (
      await post('/machines', {
        name: 'Correction machine',
        openingBalance: 10000,
      })
    ).body.id;
    productId = (
      await post('/inventory/products', {
        name: 'Correction product',
        category: 'mobile',
        openingStock: 20,
        defaultPrice: 100,
        costPrice: 50,
      })
    ).body.id;
    await post('/users', {
      username: 'correction-employee',
      password: 'EmployeePassword123!',
      displayName: 'Employee',
      role: 'employee',
      permissions: ['view_balances', 'reverse_operations'],
    });
    const employee = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({
        username: 'correction-employee',
        password: 'EmployeePassword123!',
        portal: 'employee',
      })
      .expect(201);
    employeeToken = employee.body.accessToken;
  });

  it('restricts every correction endpoint to administrators', async () => {
    const opening = (await get('/ledger')).body.find(
      (e: any) => e.entityId === machineId,
    );
    await request(app.getHttpServer())
      .get(`/api/ledger/${opening.id}/correction`)
      .set(bearer(employeeToken))
      .expect(403);
    await post(
      `/ledger/${opening.id}/cancel`,
      { reason: 'not allowed' },
      403,
      employeeToken,
    );
    await post(
      `/ledger/${opening.id}/correct`,
      { reason: 'not allowed', values: { amount: 1 } },
      403,
      employeeToken,
    );
  });

  it('corrects machine principal and linked commission atomically, then cancels once', async () => {
    await post(`/machines/${machineId}/use`, {
      amount: 100,
      commission: 5,
      serviceType: 'mobile_credit',
      customerNumber: '01012345678',
      reference: 'COR-MACHINE',
    });
    const original = await entry('COR-MACHINE', 'machine_usage');
    const commission = await entry('COR-MACHINE', 'commission');
    expect(
      (await get(`/ledger/${commission.id}/correction`)).body.operationId,
    ).toBe(original.id);
    const corrected = await post(`/ledger/${commission.id}/correct`, {
      reason: 'تصحيح المبلغ والعمولة',
      values: { amount: 150, commission: 8 },
    });
    expect(corrected.body.replacementEntryIds.length).toBe(2);
    let machine = await balance('/machines', machineId);
    expect(machine.usedBalance).toBe(150);
    expect(machine.commissionBalance).toBe(8);
    const replacement = await entry('COR-MACHINE', 'machine_usage');
    expect(replacement.metadata.correctedEntryId).toBe(original.id);
    await post(
      `/ledger/${replacement.id}/correct`,
      { reason: 'رصيد غير كاف', values: { amount: 999999 } },
      400,
    );
    machine = await balance('/machines', machineId);
    expect(machine.usedBalance).toBe(150);
    expect(machine.commissionBalance).toBe(8);
    await post(`/ledger/${replacement.id}/cancel`, { reason: 'إلغاء العملية' });
    await post(
      `/ledger/${replacement.id}/cancel`,
      { reason: 'إلغاء مكرر' },
      400,
    );
    machine = await balance('/machines', machineId);
    expect(machine.usedBalance).toBe(0);
    expect(machine.commissionBalance).toBe(0);
  });

  it('corrects account top-ups and preserves unrelated later operations', async () => {
    await post(`/accounts/${accountId}/top-up`, {
      amount: 200,
      reference: 'COR-TOPUP',
    });
    const original = await entry('COR-TOPUP', 'top_up');
    await post(`/accounts/${accountId}/top-up`, {
      amount: 50,
      reference: 'UNRELATED',
    });
    await post(`/ledger/${original.id}/correct`, {
      reason: 'تصحيح الشحن',
      values: { amount: 300 },
    });
    expect((await balance('/accounts', accountId)).balance).toBe(10350);
    const replacement = await entry('COR-TOPUP', 'top_up');
    await post(`/ledger/${replacement.id}/cancel`, { reason: 'إلغاء الشحن' });
    expect((await balance('/accounts', accountId)).balance).toBe(10050);
    await post(`/ledger/${(await entry('UNRELATED', 'top_up')).id}/cancel`, {
      reason: 'تنظيف الاختبار',
    });
  });

  it('restores wallet cash, fees and period counters', async () => {
    const before = await balance('/wallets', walletId);
    const treasuryBefore = (await get('/treasury/summary')).body.actualBalance;
    await post(`/wallets/${walletId}/customer-operation`, {
      direction: 'receive',
      amount: 500,
      reference: 'COR-WALLET',
    });
    const original = await entry('COR-WALLET', 'internal_transfer');
    await post(`/ledger/${original.id}/cancel`, {
      reason: 'إلغاء تحويل العميل',
    });
    const after = await balance('/wallets', walletId);
    expect(after.balance).toBe(before.balance);
    expect(after.commissionBalance).toBe(before.commissionBalance);
    expect(after.dailyTopUp).toBe(before.dailyTopUp);
    expect(after.monthlyTopUp).toBe(before.monthlyTopUp);
    expect((await get('/treasury/summary')).body.actualBalance).toBe(
      treasuryBefore,
    );
  });

  it('corrects and cancels a whole split collection through any linked entry', async () => {
    const beforeWallet = await balance('/wallets', walletId);
    const receipt = (
      await post('/collections/receive', {
        agentName: 'Correction agent',
        companyName: 'Company',
        amount: 1000,
        cashAmount: 400,
        incomingParts: [{ walletId, amount: 600 }],
        executionMode: 'immediate',
        accountId,
        commission: 10,
      })
    ).body;
    const execution = await entry(receipt.reference, 'company_execution');
    await post(`/ledger/${execution.id}/correct`, {
      reason: 'تصحيح الاستلام',
      values: { amount: 1200, cashAmount: 600, commission: 12 },
    });
    expect((await balance('/accounts', accountId)).balance).toBe(8800);
    expect((await balance('/accounts', accountId)).commissionBalance).toBe(12);
    const collections = (await get('/collections')).body;
    expect(collections.find((r: any) => r.id === receipt.id).status).toBe(
      'reversed',
    );
    const replacement = collections.find(
      (r: any) => r.id !== receipt.id && r.agentName === 'Correction agent',
    );
    const split = await entry(replacement.reference, 'top_up');
    await post(`/ledger/${split.id}/cancel`, {
      reason: 'إلغاء الاستلام بالكامل',
    });
    expect((await balance('/accounts', accountId)).balance).toBe(10000);
    expect((await balance('/accounts', accountId)).commissionBalance).toBe(0);
    const afterWallet = await balance('/wallets', walletId);
    for (const key of [
      'balance',
      'commissionBalance',
      'todayTopUp',
      'dailyTopUp',
      'monthlyTopUp',
    ])
      expect(afterWallet[key]).toBe(beforeWallet[key]);
  });

  it('keeps agent credit aggregates consistent and blocks dependent cancellation', async () => {
    const opening = (
      await post('/collections/agent-credits/opening', {
        agentName: 'Credit correction agent',
        amount: 100,
      })
    ).body.entry;
    await post('/collections/agent-credits/payments', {
      agentName: 'Credit correction agent',
      amount: 40,
    });
    await post(
      `/ledger/${opening.id}/cancel`,
      { reason: 'إلغاء رصيد مستخدم' },
      400,
    );
    const payment = (await get('/ledger')).body.find(
      (e: any) =>
        e.metadata?.agentCreditPayment &&
        e.metadata.agentName === 'Credit correction agent',
    );
    await post(`/ledger/${payment.id}/cancel`, { reason: 'إلغاء السداد' });
    let credit = (await get('/collections/agent-credits')).body.find(
      (r: any) => r.agentName === 'Credit correction agent',
    );
    expect(credit.balance).toBe(100);
    await post(`/ledger/${opening.id}/correct`, {
      reason: 'تصحيح الآجل القديم',
      values: { amount: 150 },
    });
    credit = (await get('/collections/agent-credits')).body.find(
      (r: any) => r.agentName === 'Credit correction agent',
    );
    expect(credit.balance).toBe(150);
  });

  it('corrects sales with stock, inventory treasury and historical cost together', async () => {
    const sale = (
      await post(`/inventory/products/${productId}/sell`, {
        quantity: 2,
        unitPrice: 100,
      })
    ).body.sale;
    await post(`/ledger/inventory-sales/${sale.id}/correct`, {
      reason: 'تصحيح البيع',
      values: { quantity: 3, unitPrice: 120 },
    });
    const rows = (await get('/inventory/sales')).body;
    expect(rows.find((s: any) => s.id === sale.id).reversedAt).toBeTruthy();
    const replacement = rows.find(
      (s: any) => s.id !== sale.id && !s.reversedAt,
    );
    expect(replacement.totalAmount).toBe(360);
    expect(replacement.grossProfit).toBe(210);
    expect((await balance('/inventory/products', productId)).stockQty).toBe(17);
    await post(
      `/ledger/inventory-sales/${replacement.id}/correct`,
      { reason: 'تعديل غير صالح', values: { quantity: 1000 } },
      400,
    );
    expect((await balance('/inventory/products', productId)).stockQty).toBe(17);
    await post(`/ledger/inventory-sales/${replacement.id}/cancel`, {
      reason: 'إلغاء البيع',
    });
    expect((await balance('/inventory/products', productId)).stockQty).toBe(20);
  });
  it('restores profit deposits and automatic commissions, including a corrected transfer', async () => {
    const profit = (
      await post('/accounts', {
        name: 'Correction profit',
        type: 'profit',
        openingBalance: 1000,
      })
    ).body;
    const cash = (await get('/treasury/summary')).body.actualBalance;
    await post(`/accounts/${profit.id}/top-up`, {
      amount: 1000,
      reference: 'COR-PROFIT',
    });
    await post(`/ledger/${(await entry('COR-PROFIT', 'top_up')).id}/correct`, {
      reason: 'تصحيح إيداع مكسب',
      values: { amount: 2000 },
    });
    expect((await balance('/accounts', profit.id)).balance).toBe(3010);
    await post(`/ledger/${(await entry('COR-PROFIT', 'top_up')).id}/cancel`, {
      reason: 'إلغاء إيداع مكسب',
    });
    expect((await balance('/accounts', profit.id)).balance).toBe(1000);
    expect((await get('/treasury/summary')).body.actualBalance).toBe(cash);
    await post('/treasury/transfer', {
      fromType: 'account',
      fromId: profit.id,
      toType: 'treasury',
      amount: 100,
      reference: 'COR-TRANSFER',
    });
    await post(
      `/ledger/${(await entry('COR-TRANSFER', 'internal_transfer')).id}/correct`,
      { reason: 'تصحيح التحويل', values: { amount: 200 } },
    );
    await post(
      `/ledger/${(await entry('COR-TRANSFER', 'internal_transfer')).id}/cancel`,
      { reason: 'إلغاء التحويل' },
    );
    expect((await balance('/accounts', profit.id)).balance).toBe(1000);
    expect((await balance('/accounts', profit.id)).commissionBalance).toBe(0);
    expect((await get('/treasury/summary')).body.actualBalance).toBe(cash);
  });

  it('corrects QR customer cash-outs and reverses provider and customer fees', async () => {
    const qr = (
      await post('/accounts', {
        name: 'Correction QR',
        type: 'profit_qr',
        openingBalance: 0,
      })
    ).body;
    const cash = (await get('/treasury/summary')).body.actualBalance;
    await post(`/accounts/${qr.id}/profit-qr-cash-out`, {
      cashAmount: 1000,
      reference: 'COR-QR',
    });
    await post(
      `/ledger/${(await entry('COR-QR', 'internal_transfer')).id}/correct`,
      { reason: 'تصحيح سحب كاش', values: { cashAmount: 2000 } },
    );
    expect((await balance('/accounts', qr.id)).balance).toBe(1996);
    await post(
      `/ledger/${(await entry('COR-QR', 'internal_transfer')).id}/cancel`,
      { reason: 'إلغاء سحب الكاش' },
    );
    const after = await balance('/accounts', qr.id);
    expect(after.balance).toBe(0);
    expect(after.commissionBalance).toBe(0);
    expect((await get('/treasury/summary')).body.actualBalance).toBe(cash);
  });

  it('corrects Fawry cash breakdown and daily drops without losing their ledger history', async () => {
    const fawry = (
      await post('/accounts', {
        name: 'Correction Fawry',
        type: 'fawry',
        openingBalance: 0,
      })
    ).body;
    const cash = (await get('/treasury/summary')).body.actualBalance;
    await post(`/accounts/${fawry.id}/fawry-deposit`, {
      depositorName: 'Cash depositor',
      cashCounts: {
        count200: 2,
        count100: 0,
        count50: 0,
        count20: 0,
        count10: 0,
        count5: 0,
      },
      reference: 'COR-FAWRY',
    });
    await post(`/ledger/${(await entry('COR-FAWRY', 'top_up')).id}/correct`, {
      reason: 'تصحيح عدد الأوراق',
      values: { 'cashCounts.count200': 3 },
    });
    expect((await balance('/accounts', fawry.id)).balance).toBe(600);
    await post(`/ledger/${(await entry('COR-FAWRY', 'top_up')).id}/cancel`, {
      reason: 'إلغاء الإيداع',
    });
    expect((await balance('/accounts', fawry.id)).balance).toBe(0);
    expect((await get('/treasury/summary')).body.actualBalance).toBe(cash);
    await post(`/accounts/${fawry.id}/fawry-daily-drop`, { amount: 50 });
    const drop = (await get('/ledger')).body.find(
      (e: any) =>
        e.entityId === fawry.id && e.metadata?.fawryDailyDrop && !e.isReversed,
    );
    await post(`/ledger/${drop.id}/correct`, {
      reason: 'تصحيح نزلة العمولة',
      values: { amount: 75 },
    });
    expect((await balance('/accounts', fawry.id)).balance).toBe(75);
    const replacement = (await get('/ledger')).body.find(
      (e: any) =>
        e.entityId === fawry.id && e.metadata?.fawryDailyDrop && !e.isReversed,
    );
    await post(`/ledger/${replacement.id}/cancel`, {
      reason: 'إلغاء نزلة العمولة',
    });
    expect((await balance('/accounts', fawry.id)).commissionBalance).toBe(0);
  });

  it('corrects visa withdrawals and whole visa-funded collections', async () => {
    const visa = (
      await post('/purchase-visas', {
        name: 'Correction visa',
        ownerName: 'Visa owner',
        cardNumber: '4111111111111111',
        expiry: '12/30',
        openingBalance: 5000,
      })
    ).body;
    const cash = (await get('/treasury/summary')).body.actualBalance;
    const withdrawal = (
      await post(`/purchase-visas/${visa.id}/withdraw`, {
        amount: 1000,
        agentName: 'Visa agent',
        withService: true,
      })
    ).body;
    await post(`/ledger/${withdrawal.id}/correct`, {
      reason: 'تصحيح سحب الفيزا',
      values: { amount: 1500, withService: false },
    });
    const replacement = (await get('/ledger')).body.find(
      (e: any) =>
        e.category === 'purchase_visa_usage' &&
        e.sourceId === visa.id &&
        !e.isReversed,
    );
    expect((await balance('/purchase-visas', visa.id)).balance).toBe(3500);
    await post(`/ledger/${replacement.id}/cancel`, {
      reason: 'إلغاء سحب الفيزا',
    });
    expect((await balance('/purchase-visas', visa.id)).balance).toBe(5000);
    expect((await get('/treasury/summary')).body.actualBalance).toBe(cash);
    const receipt = (
      await post('/collections/receive', {
        agentName: 'Visa receipt agent',
        companyName: 'Visa company',
        amount: 1000,
        executionMode: 'immediate',
        purchaseVisaId: visa.id,
        withService: true,
      })
    ).body;
    const ledger = await entry(receipt.reference, 'purchase_visa_usage');
    await post(`/ledger/${ledger.id}/cancel`, {
      reason: 'إلغاء استلام الفيزا',
    });
    expect((await balance('/purchase-visas', visa.id)).balance).toBe(5000);
    expect((await balance('/purchase-visas', visa.id)).commissionBalance).toBe(
      0,
    );
    expect((await get('/treasury/summary')).body.actualBalance).toBe(cash);
  });

  it('corrects treasury withdrawals by amount and rejects forged hidden values', async () => {
    const cash = (await get('/treasury/summary')).body.actualBalance;
    const withdrawal = (
      await post('/treasury/withdraw', {
        mode: 'leave',
        leaveAmount: cash - 100,
      })
    ).body;
    await post(`/ledger/${withdrawal.id}/correct`, {
      reason: 'تصحيح سحب صاحب المحل',
      values: { amount: 200 },
    });
    expect((await get('/treasury/summary')).body.actualBalance).toBe(
      cash - 200,
    );
    const replacement = (await get('/ledger')).body.find(
      (e: any) => e.category === 'owner_withdrawal' && !e.isReversed,
    );
    await post(
      `/ledger/${replacement.id}/correct`,
      { reason: 'بيانات مزورة', values: { balance: 99999 } },
      400,
    );
    await post(`/ledger/${replacement.id}/cancel`, { reason: 'إلغاء السحب' });
    expect((await get('/treasury/summary')).body.actualBalance).toBe(cash);
  });

  it('corrects an opening balance and a reconciliation without changing unrelated balances', async () => {
    const account = (
      await post('/accounts', {
        name: 'Opening correction account',
        type: 'company',
        openingBalance: 100,
      })
    ).body;
    const opening = (await get('/ledger')).body.find(
      (e: any) => e.entityId === account.id && e.category === 'opening_balance',
    );
    await post(`/ledger/${opening.id}/correct`, {
      reason: 'تصحيح الرصيد الافتتاحي',
      values: { amount: 200 },
    });
    expect((await balance('/accounts', account.id)).openingBalance).toBe(200);
    const rec = (
      await post('/treasury/reconcile', {
        assetType: 'account',
        assetId: account.id,
        countedBalance: 250,
      })
    ).body;
    await post(`/ledger/${rec.id}/correct`, {
      reason: 'تصحيح الجرد',
      values: { countedBalance: 230 },
    });
    expect((await balance('/accounts', account.id)).balance).toBe(230);
    const replacement = (await get('/ledger')).body.find(
      (e: any) =>
        e.entityId === account.id &&
        e.category === 'reconciliation' &&
        !e.isReversed,
    );
    await post(`/ledger/${replacement.id}/cancel`, { reason: 'إلغاء التسوية' });
    expect((await balance('/accounts', account.id)).balance).toBe(200);
  });

  it('handles replayed requests and concurrent cancellations without applying effects twice', async () => {
    await post(`/accounts/${accountId}/top-up`, {
      amount: 100,
      reference: 'COR-IDEMPOTENT',
    });
    const original = await entry('COR-IDEMPOTENT', 'top_up');
    const headers = {
      ...bearer(adminToken),
      'Idempotency-Key': `correction-${randomUUID()}`,
    };
    const body = { reason: 'تصحيح مرة واحدة', values: { amount: 150 } };
    const first = await request(app.getHttpServer())
      .post(`/api/ledger/${original.id}/correct`)
      .set(headers)
      .send(body)
      .expect(201);
    const replay = await request(app.getHttpServer())
      .post(`/api/ledger/${original.id}/correct`)
      .set(headers)
      .send(body)
      .expect(201);
    expect(replay.body).toEqual(first.body);
    expect((await balance('/accounts', accountId)).balance).toBe(10150);
    const replacement = await entry('COR-IDEMPOTENT', 'top_up');
    const replies = await Promise.all(
      [1, 2].map(() =>
        request(app.getHttpServer())
          .post(`/api/ledger/${replacement.id}/cancel`)
          .set(mutation(adminToken, 'concurrent'))
          .send({ reason: 'إلغاء مرة واحدة' }),
      ),
    );
    expect(replies.map((r) => r.status).sort((a, b) => a - b)).toEqual([
      201, 400,
    ]);
    expect((await balance('/accounts', accountId)).balance).toBe(10000);
    const [count] = await dataSource.query(
      'SELECT COUNT(*)::int AS total FROM ledger_entries WHERE reverses_entry_id = $1',
      [replacement.id],
    );
    expect(count.total).toBe(1);
  });

  it('corrects wallet and machine top-ups with their counters and rejects invalid asset IDs', async () => {
    for (const [path, id, action] of [
      ['wallets', walletId, 'top-up'],
      ['machines', machineId, 'load'],
    ]) {
      const before = await balance(`/${path}`, id);
      const reference = `COR-TOPUP-${path}`;
      await post(`/${path}/${id}/${action}`, { amount: 100, reference });
      let current = await entry(reference, 'top_up');
      await post(
        `/ledger/${current.id}/correct`,
        { reason: 'وجهة غير صالحة', values: { assetId: 'not-a-uuid' } },
        400,
      );
      await post(`/ledger/${current.id}/correct`, {
        reason: 'تصحيح شحن الأصل',
        values: { amount: 150 },
      });
      current = await entry(reference, 'top_up');
      await post(`/ledger/${current.id}/cancel`, { reason: 'إلغاء شحن الأصل' });
      const after = await balance(`/${path}`, id);
      for (const key of path === 'wallets'
        ? ['balance', 'todayTopUp', 'dailyTopUp', 'monthlyTopUp']
        : ['loadedBalance', 'usedBalance'])
        expect(after[key]).toBe(before[key]);
    }
  });

  it('corrects pending receipts directly and cancels both held and executed receipts', async () => {
    const cash = (await get('/treasury/summary')).body.actualBalance;
    const receipt = (
      await post('/collections/receive', {
        agentName: 'Held correction agent',
        companyName: 'Held company',
        amount: 100,
        executionMode: 'hold',
      })
    ).body;
    await request(app.getHttpServer())
      .get(`/api/ledger/collections/${receipt.id}/correction`)
      .set(bearer(employeeToken))
      .expect(403);
    await post(`/ledger/collections/${receipt.id}/correct`, {
      reason: 'تصحيح مبلغ المعلق',
      values: { amount: 150 },
    });
    let replacement = (await get('/collections')).body.find(
      (r: any) =>
        r.agentName === 'Held correction agent' && r.status === 'pending',
    );
    expect(replacement.amount).toBe(150);
    expect((await get('/treasury/summary')).body.actualBalance).toBe(
      cash + 150,
    );
    await post(`/collections/${replacement.id}/execute`, {
      accountId,
      commission: 0,
    });
    await post(`/ledger/collections/${replacement.id}/cancel`, {
      reason: 'إلغاء استلام تم تنفيذه',
    });
    expect((await balance('/accounts', accountId)).balance).toBe(10000);
    expect((await get('/treasury/summary')).body.actualBalance).toBe(cash);
    const credit = (
      await post('/collections/receive', {
        agentName: 'Full credit receipt',
        companyName: 'Credit company',
        amount: 100,
        cashAmount: 0,
        useAgentCredit: true,
        executionMode: 'immediate',
        accountId,
      })
    ).body;
    await post(`/ledger/collections/${credit.id}/cancel`, {
      reason: 'إلغاء استلام آجل بالكامل',
    });
    expect((await balance('/accounts', accountId)).balance).toBe(10000);
  });

  it('corrects a QR receipt whose incoming destination is also its execution source', async () => {
    const qr = (
      await post('/accounts', {
        name: 'Same-source QR correction',
        type: 'profit_qr',
        openingBalance: 5000,
      })
    ).body;
    const cash = (await get('/treasury/summary')).body.actualBalance;
    const receipt = (
      await post('/collections/receive', {
        agentName: 'QR same-source agent',
        companyName: 'QR company',
        amount: 1000,
        cashAmount: 100,
        incomingParts: [{ accountId: qr.id, amount: 900 }],
        executionMode: 'immediate',
        accountId: qr.id,
      })
    ).body;
    await post(`/ledger/collections/${receipt.id}/correct`, {
      reason: 'تصحيح استلام مكسب QR',
      values: { amount: 1200, cashAmount: 200, 'incomingParts.0.amount': 1000 },
    });
    expect((await balance('/accounts', qr.id)).balance).toBe(4795.2);
    const current = (await get('/collections')).body.find(
      (r: any) => r.agentName === 'QR same-source agent' && r.status === 'done',
    );
    await post(`/ledger/collections/${current.id}/cancel`, {
      reason: 'إلغاء استلام مكسب QR',
    });
    const restored = await balance('/accounts', qr.id);
    expect(restored.balance).toBe(5000);
    expect(restored.commissionBalance).toBe(0);
    expect(restored.todayTopUp).toBe(0);
    expect((await get('/treasury/summary')).body.actualBalance).toBe(cash);
  });

  it('restores exact pre-close counters and blocks closing cancellation after a later operation', async () => {
    const before = await balance('/accounts', accountId);
    await post('/treasury/close-day', { note: 'Correction test close' });
    let close = (await get('/ledger')).body.find(
      (e: any) => e.category === 'daily_rollover' && !e.isReversed,
    );
    await post(`/ledger/${close.id}/correct`, {
      reason: 'تصحيح ملاحظات الإقفال',
      values: { note: 'Corrected close' },
    });
    expect((await get('/treasury/daily-closes')).body[0].note).toBe(
      'Corrected close',
    );
    close = (await get('/ledger')).body.find(
      (e: any) => e.category === 'daily_rollover' && !e.isReversed,
    );
    await post(`/ledger/${close.id}/cancel`, { reason: 'إلغاء الإقفال' });
    const after = await balance('/accounts', accountId);
    expect(after.todayTopUp).toBe(before.todayTopUp);
    expect(after.openingBalance).toBe(before.openingBalance);
    await post('/treasury/close-day', {});
    close = (await get('/ledger')).body.find(
      (e: any) => e.category === 'daily_rollover' && !e.isReversed,
    );
    await post(`/accounts/${accountId}/top-up`, {
      amount: 10,
      reference: 'AFTER-CLOSE',
    });
    await post(
      `/ledger/${close.id}/cancel`,
      { reason: 'لا تلغى إقفال مرتبط' },
      400,
    );
    expect((await get('/treasury/daily-closes')).body.length).toBe(1);
  });
});
