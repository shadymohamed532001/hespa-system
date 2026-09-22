import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AccountsModule } from './accounts/accounts.module.js';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { AuthModule } from './auth/auth.module.js';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard.js';
import { PermissionsGuard } from './common/guards/permissions.guard.js';
import { RolesGuard } from './common/guards/roles.guard.js';
import { SecurityModule } from './common/security.module.js';
import { validateConfig } from './config/validate-config.js';
import { CollectionsModule } from './collections/collections.module.js';
import {
  AppNotification,
  AuditEvent,
  Collection,
  FinancialAccount,
  InventoryProduct,
  InventorySale,
  InventoryTreasury,
  IdempotencyRecord,
  LedgerEntry,
  Machine,
  Treasury,
  User,
  Wallet,
} from './database/entities/index.js';
import { InventoryModule } from './inventory/inventory.module.js';
import { LedgerModule } from './ledger/ledger.module.js';
import { MachinesModule } from './machines/machines.module.js';
import { NotificationsModule } from './notifications/notifications.module.js';
import { ReportsModule } from './reports/reports.module.js';
import { TreasuryModule } from './treasury/treasury.module.js';
import { UsersModule } from './users/users.module.js';
import { WalletsModule } from './wallets/wallets.module.js';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, validate: validateConfig }),
    ThrottlerModule.forRoot([
      {
        name: 'default',
        ttl: 60_000,
        limit: 120,
        blockDuration: 60_000,
      },
    ]),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        type: 'postgres',
        host: config.get('DB_HOST', 'localhost'),
        port: Number(config.get('DB_PORT', 5432)),
        username: config.get('DB_USER', 'hesba'),
        password: config.get('DB_PASSWORD', 'hesba'),
        database: config.get('DB_NAME', 'hesba'),
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
        synchronize:
          config.get('NODE_ENV', 'development') !== 'production' &&
          config.get('DB_SYNC', 'true') === 'true',
      }),
    }),
    AuthModule,
    UsersModule,
    AccountsModule,
    WalletsModule,
    MachinesModule,
    CollectionsModule,
    TreasuryModule,
    LedgerModule,
    NotificationsModule,
    InventoryModule,
    ReportsModule,
    SecurityModule,
  ],
  controllers: [AppController],
  providers: [
    AppService,
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
    { provide: APP_GUARD, useClass: PermissionsGuard },
  ],
})
export class AppModule {}
