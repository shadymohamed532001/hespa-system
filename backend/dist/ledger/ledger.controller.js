var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
import { Controller, Get, Query } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
let LedgerController = class LedgerController {
    ledger;
    constructor(ledger) {
        this.ledger = ledger;
    }
    findAll(limit) {
        const take = Math.min(Math.max(Number(limit) || 100, 1), 500);
        return this.ledger.find({ order: { createdAt: 'DESC' }, take });
    }
};
__decorate([
    Get(),
    __param(0, Query('limit')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], LedgerController.prototype, "findAll", null);
LedgerController = __decorate([
    Controller('ledger'),
    __param(0, InjectRepository(LedgerEntry)),
    __metadata("design:paramtypes", [Repository])
], LedgerController);
export { LedgerController };
//# sourceMappingURL=ledger.controller.js.map