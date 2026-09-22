var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Collection } from '../database/entities/collection.entity.js';
import { FinancialAccount } from '../database/entities/financial-account.entity.js';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { Machine } from '../database/entities/machine.entity.js';
import { Treasury } from '../database/entities/treasury.entity.js';
import { Wallet } from '../database/entities/wallet.entity.js';
import { TreasuryController } from './treasury.controller.js';
import { TreasuryService } from './treasury.service.js';
let TreasuryModule = class TreasuryModule {
};
TreasuryModule = __decorate([
    Module({
        imports: [TypeOrmModule.forFeature([Treasury, Collection, FinancialAccount, Wallet, Machine, LedgerEntry])],
        controllers: [TreasuryController],
        providers: [TreasuryService],
    })
], TreasuryModule);
export { TreasuryModule };
//# sourceMappingURL=treasury.module.js.map