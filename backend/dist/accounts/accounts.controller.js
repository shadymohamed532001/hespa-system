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
import { Body, Controller, Delete, Get, Param, ParseBoolPipe, Patch, Post, Query, Request } from '@nestjs/common';
import { RequirePermissions } from '../common/decorators/permissions.decorator.js';
import { AppPermission } from '../database/enums.js';
import { UsersService } from '../users/users.service.js';
import { AccountsService } from './accounts.service.js';
import { CreateAccountDto } from './dto/create-account.dto.js';
import { TopUpAccountDto } from './dto/top-up-account.dto.js';
let AccountsController = class AccountsController {
    accounts;
    users;
    constructor(accounts, users) {
        this.accounts = accounts;
        this.users = users;
    }
    findAll(includeInactive) {
        return this.accounts.findAll(includeInactive ?? false);
    }
    create(dto, request) {
        return this.accounts.create(dto, request.user.username);
    }
    async topUp(id, dto, request) {
        await this.users.assertAmountLimit(request.user.userId, 'maxTopUpAmount', dto.amount);
        return this.accounts.topUp(id, dto, request.user.username);
    }
    setStatus(id, active) {
        return this.accounts.setActive(id, active);
    }
    remove(id, request) {
        return this.accounts.remove(id, request.user.username);
    }
};
__decorate([
    Get(),
    __param(0, Query('includeInactive', new ParseBoolPipe({ optional: true }))),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Boolean]),
    __metadata("design:returntype", void 0)
], AccountsController.prototype, "findAll", null);
__decorate([
    RequirePermissions(AppPermission.MANAGE_ASSETS),
    Post(),
    __param(0, Body()),
    __param(1, Request()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [CreateAccountDto, Object]),
    __metadata("design:returntype", void 0)
], AccountsController.prototype, "create", null);
__decorate([
    RequirePermissions(AppPermission.TOP_UP_ASSETS),
    Post(':id/top-up'),
    __param(0, Param('id')),
    __param(1, Body()),
    __param(2, Request()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, TopUpAccountDto, Object]),
    __metadata("design:returntype", Promise)
], AccountsController.prototype, "topUp", null);
__decorate([
    RequirePermissions(AppPermission.MANAGE_ASSETS),
    Patch(':id/status'),
    __param(0, Param('id')),
    __param(1, Body('active')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Boolean]),
    __metadata("design:returntype", void 0)
], AccountsController.prototype, "setStatus", null);
__decorate([
    RequirePermissions(AppPermission.MANAGE_ASSETS),
    Delete(':id'),
    __param(0, Param('id')),
    __param(1, Request()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], AccountsController.prototype, "remove", null);
AccountsController = __decorate([
    Controller('accounts'),
    __metadata("design:paramtypes", [AccountsService,
        UsersService])
], AccountsController);
export { AccountsController };
//# sourceMappingURL=accounts.controller.js.map