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
import { Injectable, Optional } from '@nestjs/common';
import { DataSource } from 'typeorm';
let AppService = class AppService {
    dataSource;
    constructor(dataSource) {
        this.dataSource = dataSource;
    }
    getHello() {
        return 'Hesba API is running';
    }
    async health() {
        const startedAt = Date.now();
        if (!this.dataSource?.isInitialized) {
            return { status: 'degraded', database: 'unavailable' };
        }
        await this.dataSource.query('SELECT 1');
        return {
            status: 'ok',
            database: 'up',
            latencyMs: Date.now() - startedAt,
            timestamp: new Date().toISOString(),
        };
    }
};
AppService = __decorate([
    Injectable(),
    __param(0, Optional()),
    __metadata("design:paramtypes", [DataSource])
], AppService);
export { AppService };
//# sourceMappingURL=app.service.js.map