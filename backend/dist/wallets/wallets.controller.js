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
import { Body, Controller, Get, Param, Post, Request } from '@nestjs/common';
import { Roles } from '../common/decorators/roles.decorator.js';
import { UserRole } from '../database/enums.js';
import { CreateWalletDto } from './dto/create-wallet.dto.js';
import { TopUpWalletDto } from './dto/top-up-wallet.dto.js';
import { WalletsService } from './wallets.service.js';
let WalletsController = class WalletsController {
    wallets;
    constructor(wallets) {
        this.wallets = wallets;
    }
    findAll() {
        return this.wallets.findAll();
    }
    create(dto) {
        return this.wallets.create(dto);
    }
    topUp(id, dto, request) {
        return this.wallets.topUp(id, dto, request.user.username);
    }
};
__decorate([
    Get(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], WalletsController.prototype, "findAll", null);
__decorate([
    Roles(UserRole.ADMIN),
    Post(),
    __param(0, Body()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [CreateWalletDto]),
    __metadata("design:returntype", void 0)
], WalletsController.prototype, "create", null);
__decorate([
    Roles(UserRole.ADMIN),
    Post(':id/top-up'),
    __param(0, Param('id')),
    __param(1, Body()),
    __param(2, Request()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, TopUpWalletDto, Object]),
    __metadata("design:returntype", void 0)
], WalletsController.prototype, "topUp", null);
WalletsController = __decorate([
    Controller('wallets'),
    __metadata("design:paramtypes", [WalletsService])
], WalletsController);
export { WalletsController };
//# sourceMappingURL=wallets.controller.js.map