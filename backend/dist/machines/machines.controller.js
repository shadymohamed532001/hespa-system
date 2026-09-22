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
import { Body, Controller, Get, Param, ParseBoolPipe, Patch, Post, Query, Request, } from '@nestjs/common';
import { RequirePermissions } from '../common/decorators/permissions.decorator.js';
import { AppPermission } from '../database/enums.js';
import { CreateMachineDto } from './dto/create-machine.dto.js';
import { LoadMachineDto } from './dto/load-machine.dto.js';
import { UseMachineDto } from './dto/use-machine.dto.js';
import { MachinesService } from './machines.service.js';
let MachinesController = class MachinesController {
    machines;
    constructor(machines) {
        this.machines = machines;
    }
    findAll(includeInactive) {
        return this.machines.findAll(includeInactive ?? false);
    }
    create(dto, request) {
        return this.machines.create(dto, request.user.username);
    }
    load(id, dto, request) {
        return this.machines.load(id, dto, request.user.username);
    }
    use(id, dto, request) {
        return this.machines.use(id, dto, request.user.username);
    }
    setStatus(id, active) {
        return this.machines.setActive(id, active);
    }
};
__decorate([
    Get(),
    __param(0, Query('includeInactive', new ParseBoolPipe({ optional: true }))),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Boolean]),
    __metadata("design:returntype", void 0)
], MachinesController.prototype, "findAll", null);
__decorate([
    RequirePermissions(AppPermission.MANAGE_ASSETS),
    Post(),
    __param(0, Body()),
    __param(1, Request()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [CreateMachineDto, Object]),
    __metadata("design:returntype", void 0)
], MachinesController.prototype, "create", null);
__decorate([
    RequirePermissions(AppPermission.TOP_UP_ASSETS),
    Post(':id/load'),
    __param(0, Param('id')),
    __param(1, Body()),
    __param(2, Request()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, LoadMachineDto, Object]),
    __metadata("design:returntype", void 0)
], MachinesController.prototype, "load", null);
__decorate([
    RequirePermissions(AppPermission.USE_MACHINES),
    Post(':id/use'),
    __param(0, Param('id')),
    __param(1, Body()),
    __param(2, Request()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, UseMachineDto, Object]),
    __metadata("design:returntype", void 0)
], MachinesController.prototype, "use", null);
__decorate([
    RequirePermissions(AppPermission.MANAGE_ASSETS),
    Patch(':id/status'),
    __param(0, Param('id')),
    __param(1, Body('active')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Boolean]),
    __metadata("design:returntype", void 0)
], MachinesController.prototype, "setStatus", null);
MachinesController = __decorate([
    Controller('machines'),
    __metadata("design:paramtypes", [MachinesService])
], MachinesController);
export { MachinesController };
//# sourceMappingURL=machines.controller.js.map