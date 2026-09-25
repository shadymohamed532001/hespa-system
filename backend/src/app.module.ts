import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Schema1790087699416 } from './database/migrations/1790087699416-Schema.js';
import { LegacySchemaRepair1790087699417 } from './database/migrations/1790087699417-LegacySchemaRepair.js';
import { OperationsHardening1790087699418 } from './database/migrations/1790087699418-OperationsHardening.js';
import { RefreshTokens1790087699419 } from './database/migrations/1790087699419-RefreshTokens.js';
import { WalletOperations1790087699420 } from './database/migrations/1790087699420-WalletOperations.js';
import { WalletOwner1790087699421 } from './database/migrations/1790087699421-WalletOwner.js';
import { DevicePushTokens1790087699422 } from './database/migrations/1790087699422-DevicePushTokens.js';
import { WalletCustomerCashFee1790087699424 } from './database/migrations/1790087699424-WalletCustomerCashFee.js';
import { AccountsModule } from './accounts/accounts.module.js';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { AuthModule } from './auth/auth.module.js';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard.js';
import { PermissionsGuard } from './common/guards/permissions.guard.js';
import { RolesGuard } from './common/guards/roles.guard.js';
import { LocaleMiddleware } from './common/i18n/locale.middleware.js';
import { SecurityModule } from './common/security.module.js';
import { ProfitVisibilityInterceptor } from './common/interceptors/profit-visibility.interceptor.js';
import { validateConfig } from './config/validate-config.js';
import { CollectionsModule } from './collections/collections.module.js';
import {
  AppNotification,
  AuditEvent,
  DailyClose,
  Collection,
  DevicePushToken,
  FinancialAccount,
  InventoryProduct,
  InventorySale,
  InventoryStockMovement,
  InventoryTreasury,
  IdempotencyRecord,
  LedgerEntry,
  Machine,
  RefreshToken,
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
          DevicePushToken,
          InventoryProduct,
          InventorySale,
          InventoryTreasury,
          IdempotencyRecord,
          AuditEvent,
          DailyClose,
          InventoryStockMovement,
          RefreshToken,
        ],
        synchronize:
          config.get('NODE_ENV', 'development') !== 'production' &&
          config.get('DB_SYNC', 'true') === 'true',
        migrations: [
          Schema1790087699416,
          LegacySchemaRepair1790087699417,
          OperationsHardening1790087699418,
          RefreshTokens1790087699419,
          WalletOperations1790087699420,
          WalletOwner1790087699421,
          DevicePushTokens1790087699422,
          WalletCustomerCashFee1790087699424,
        ],
        migrationsTableName: 'schema_migrations',
        migrationsRun: config.get('MIGRATIONS_RUN', 'false') === 'true',
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
    { provide: APP_INTERCEPTOR, useClass: ProfitVisibilityInterceptor },
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(LocaleMiddleware).forRoutes('*');
  }
}
