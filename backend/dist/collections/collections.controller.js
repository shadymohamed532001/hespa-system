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
import { RequirePermissions } from '../common/decorators/permissions.decorator.js';
import { Idempotent } from '../common/decorators/idempotent.decorator.js';
import { AppPermission } from '../database/enums.js';
import { UsersService } from '../users/users.service.js';
import { CollectionsService } from './collections.service.js';
import { ExecuteHoldDto } from './dto/execute-hold.dto.js';
import { ReceiveCollectionDto } from './dto/receive-collection.dto.js';
let CollectionsController = class CollectionsController {
    collections;
    users;
    constructor(collections, users) {
        this.collections = collections;
        this.users = users;
    }
    findAll() {
        return this.collections.findAll();
    }
    async receive(dto, request) {
        await this.users.assertAmountLimit(request.user.userId, 'maxReceiveAmount', dto.amount);
        return this.collections.receive(dto, request.user.username);
    }
    async execute(id, dto, request) {
        const hold = await this.collections.findOne(id);
        await this.users.assertAmountLimit(request.user.userId, 'maxReceiveAmount', Number(hold.amount));
        return this.collections.execute(id, dto, request.user.username);
    }
};
__decorate([
    Get(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], CollectionsController.prototype, "findAll", null);
__decorate([
    RequirePermissions(AppPermission.RECEIVE_COLLECTIONS),
    Idempotent(),
    Post('receive'),
    __param(0, Body()),
    __param(1, Request()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [ReceiveCollectionDto, Object]),
    __metadata("design:returntype", Promise)
], CollectionsController.prototype, "receive", null);
__decorate([
    RequirePermissions(AppPermission.RECEIVE_COLLECTIONS),
    Idempotent(),
    Post(':id/execute'),
    __param(0, Param('id')),
    __param(1, Body()),
    __param(2, Request()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, ExecuteHoldDto, Object]),
    __metadata("design:returntype", Promise)
], CollectionsController.prototype, "execute", null);
CollectionsController = __decorate([
    Controller('collections'),
    RequirePermissions(AppPermission.VIEW_BALANCES),
    __metadata("design:paramtypes", [CollectionsService,
        UsersService])
], CollectionsController);
export { CollectionsController };
//# sourceMappingURL=collections.controller.js.map