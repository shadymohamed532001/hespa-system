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
import { Treasury } from '../database/entities/treasury.entity.js';
import { CollectionsController } from './collections.controller.js';
import { CollectionsService } from './collections.service.js';
let CollectionsModule = class CollectionsModule {
};
CollectionsModule = __decorate([
    Module({
        imports: [TypeOrmModule.forFeature([Collection, FinancialAccount, LedgerEntry, Treasury])],
        controllers: [CollectionsController],
        providers: [CollectionsService],
    })
], CollectionsModule);
export { CollectionsModule };
//# sourceMappingURL=collections.module.js.map