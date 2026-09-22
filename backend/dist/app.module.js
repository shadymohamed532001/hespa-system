var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AccountsModule } from './accounts/accounts.module.js';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { AuthModule } from './auth/auth.module.js';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard.js';
import { PermissionsGuard } from './common/guards/permissions.guard.js';
import { RolesGuard } from './common/guards/roles.guard.js';
import { CollectionsModule } from './collections/collections.module.js';
import { AppNotification, Collection, FinancialAccount, InventoryProduct, InventorySale, InventoryTreasury, LedgerEntry, Machine, Treasury, User, Wallet, } from './database/entities/index.js';
import { InventoryModule } from './inventory/inventory.module.js';
import { LedgerModule } from './ledger/ledger.module.js';
import { MachinesModule } from './machines/machines.module.js';
import { NotificationsModule } from './notifications/notifications.module.js';
import { ReportsModule } from './reports/reports.module.js';
import { TreasuryModule } from './treasury/treasury.module.js';
import { UsersModule } from './users/users.module.js';
import { WalletsModule } from './wallets/wallets.module.js';
let AppModule = class AppModule {
};
AppModule = __decorate([
    Module({
        imports: [
            ConfigModule.forRoot({ isGlobal: true }),
            TypeOrmModule.forRootAsync({
                inject: [ConfigService],
                useFactory: (config) => ({
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
                    ],
                    synchronize: config.get('DB_SYNC', 'true') === 'true',
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
        ],
        controllers: [AppController],
        providers: [
            AppService,
            { provide: APP_GUARD, useClass: JwtAuthGuard },
            { provide: APP_GUARD, useClass: RolesGuard },
            { provide: APP_GUARD, useClass: PermissionsGuard },
        ],
    })
], AppModule);
export { AppModule };
//# sourceMappingURL=app.module.js.map