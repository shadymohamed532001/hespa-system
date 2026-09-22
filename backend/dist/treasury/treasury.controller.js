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
import { Body, Controller, Get, Post, Request } from '@nestjs/common';
import { RequirePermissions } from '../common/decorators/permissions.decorator.js';
import { AppPermission } from '../database/enums.js';
import { UsersService } from '../users/users.service.js';
import { InternalTransferDto } from './dto/internal-transfer.dto.js';
import { TreasuryService } from './treasury.service.js';
let TreasuryController = class TreasuryController {
    treasury;
    users;
    constructor(treasury, users) {
        this.treasury = treasury;
        this.users = users;
    }
    summary() {
        return this.treasury.summary();
    }
    async transfer(dto, request) {
        await this.users.assertAmountLimit(request.user.userId, 'maxTransferAmount', dto.amount);
        return this.treasury.transfer(dto, request.user.username);
    }
    rollover(request) {
        return this.treasury.rollover(request.user.username);
    }
};
__decorate([
    Get('summary'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], TreasuryController.prototype, "summary", null);
__decorate([
    RequirePermissions(AppPermission.INTERNAL_TRANSFER),
    Post('transfer'),
    __param(0, Body()),
    __param(1, Request()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [InternalTransferDto, Object]),
    __metadata("design:returntype", Promise)
], TreasuryController.prototype, "transfer", null);
__decorate([
    RequirePermissions(AppPermission.DAILY_ROLLOVER),
    Post('rollover'),
    __param(0, Request()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], TreasuryController.prototype, "rollover", null);
TreasuryController = __decorate([
    Controller('treasury'),
    __metadata("design:paramtypes", [TreasuryService,
        UsersService])
], TreasuryController);
export { TreasuryController };
//# sourceMappingURL=treasury.controller.js.map