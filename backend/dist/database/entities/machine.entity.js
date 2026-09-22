var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn, UpdateDateColumn } from 'typeorm';
import { decimalTransformer } from '../decimal.transformer.js';
let Machine = class Machine {
    id;
    name;
    active;
    loadedBalance;
    usedBalance;
    commissionBalance;
    createdAt;
    updatedAt;
};
__decorate([
    PrimaryGeneratedColumn('uuid'),
    __metadata("design:type", String)
], Machine.prototype, "id", void 0);
__decorate([
    Column({ unique: true, length: 150 }),
    __metadata("design:type", String)
], Machine.prototype, "name", void 0);
__decorate([
    Column({ default: true }),
    __metadata("design:type", Boolean)
], Machine.prototype, "active", void 0);
__decorate([
    Column({ name: 'loaded_balance', type: 'numeric', precision: 16, scale: 2, default: 0, transformer: decimalTransformer }),
    __metadata("design:type", Number)
], Machine.prototype, "loadedBalance", void 0);
__decorate([
    Column({ name: 'used_balance', type: 'numeric', precision: 16, scale: 2, default: 0, transformer: decimalTransformer }),
    __metadata("design:type", Number)
], Machine.prototype, "usedBalance", void 0);
__decorate([
    Column({ name: 'commission_balance', type: 'numeric', precision: 16, scale: 2, default: 0, transformer: decimalTransformer }),
    __metadata("design:type", Number)
], Machine.prototype, "commissionBalance", void 0);
__decorate([
    CreateDateColumn({ name: 'created_at' }),
    __metadata("design:type", Date)
], Machine.prototype, "createdAt", void 0);
__decorate([
    UpdateDateColumn({ name: 'updated_at' }),
    __metadata("design:type", Date)
], Machine.prototype, "updatedAt", void 0);
Machine = __decorate([
    Entity('machines')
], Machine);
export { Machine };
//# sourceMappingURL=machine.entity.js.map