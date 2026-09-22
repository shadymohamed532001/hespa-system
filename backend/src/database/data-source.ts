import { DataSource } from 'typeorm';
import {
  AppNotification,
  AuditEvent,
  Collection,
  FinancialAccount,
  IdempotencyRecord,
  InventoryProduct,
  InventorySale,
  InventoryTreasury,
  LedgerEntry,
  Machine,
  Treasury,
  User,
  Wallet,
} from './entities/index.js';

const AppDataSource = new DataSource({
  type: 'postgres',
  host: process.env.DB_HOST ?? 'localhost',
  port: Number(process.env.DB_PORT ?? 5432),
  username: process.env.DB_USER ?? 'hesba',
  password: process.env.DB_PASSWORD ?? '',
  database: process.env.DB_NAME ?? 'hesba',
  entities: [
    User,
    FinancialAccount,
    Wallet,
    Machine,
    Treasury,
    Collection,
    LedgerEntry,
    AppNotification,
    InventoryProduct,
    InventorySale,
    InventoryTreasury,
    IdempotencyRecord,
    AuditEvent,
  ],
  migrations: [`${import.meta.dirname}/migrations/*.js`],
  migrationsTableName: 'schema_migrations',
  migrationsTransactionMode: 'all',
  synchronize: false,
});

export default AppDataSource;
