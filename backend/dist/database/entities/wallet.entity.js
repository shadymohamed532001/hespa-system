var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn, UpdateDateColumn, } from 'typeorm';
import { decimalTransformer } from '../decimal.transformer.js';
let Wallet = class Wallet {
    id;
    name;
    type;
    active;
    openingBalance;
    todayTopUp;
    balance;
    dailyTopUp;
    monthlyTopUp;
    counterDay;
    counterMonth;
    commissionBalance;
    createdAt;
    updatedAt;
};
__decorate([
    PrimaryGeneratedColumn('uuid'),
    __metadata("design:type", String)
], Wallet.prototype, "id", void 0);
__decorate([
    Column({
        type: 'varchar',
        length: 150,
        unique: true,
    }),
    __metadata("design:type", String)
], Wallet.prototype, "name", void 0);
__decorate([
    Column({
        type: 'varchar',
        length: 80,
    }),
    __metadata("design:type", String)
], Wallet.prototype, "type", void 0);
__decorate([
    Column({
        type: 'boolean',
        default: true,
    }),
    __metadata("design:type", Boolean)
], Wallet.prototype, "active", void 0);
__decorate([
    Column({
        name: 'opening_balance',
        type: 'numeric',
        precision: 16,
        scale: 2,
        default: 0,
        transformer: decimalTransformer,
    }),
    __metadata("design:type", Number)
], Wallet.prototype, "openingBalance", void 0);
__decorate([
    Column({
        name: 'today_top_up',
        type: 'numeric',
        precision: 16,
        scale: 2,
        default: 0,
        transformer: decimalTransformer,
    }),
    __metadata("design:type", Number)
], Wallet.prototype, "todayTopUp", void 0);
__decorate([
    Column({
        type: 'numeric',
        precision: 16,
        scale: 2,
        default: 0,
        transformer: decimalTransformer,
    }),
    __metadata("design:type", Number)
], Wallet.prototype, "balance", void 0);
__decorate([
    Column({
        name: 'daily_top_up',
        type: 'numeric',
        precision: 16,
        scale: 2,
        default: 0,
        transformer: decimalTransformer,
    }),
    __metadata("design:type", Number)
], Wallet.prototype, "dailyTopUp", void 0);
__decorate([
    Column({
        name: 'monthly_top_up',
        type: 'numeric',
        precision: 16,
        scale: 2,
        default: 0,
        transformer: decimalTransformer,
    }),
    __metadata("design:type", Number)
], Wallet.prototype, "monthlyTopUp", void 0);
__decorate([
    Column({
        name: 'counter_day',
        type: 'date',
        nullable: true,
    }),
    __metadata("design:type", Object)
], Wallet.prototype, "counterDay", void 0);
__decorate([
    Column({
        name: 'counter_month',
        type: 'varchar',
        length: 7,
        nullable: true,
    }),
    __metadata("design:type", Object)
], Wallet.prototype, "counterMonth", void 0);
__decorate([
    Column({
        name: 'commission_balance',
        type: 'numeric',
        precision: 16,
        scale: 2,
        default: 0,
        transformer: decimalTransformer,
    }),
    __metadata("design:type", Number)
], Wallet.prototype, "commissionBalance", void 0);
__decorate([
    CreateDateColumn({
        name: 'created_at',
        type: 'timestamp',
    }),
    __metadata("design:type", Date)
], Wallet.prototype, "createdAt", void 0);
__decorate([
    UpdateDateColumn({
        name: 'updated_at',
        type: 'timestamp',
    }),
    __metadata("design:type", Date)
], Wallet.prototype, "updatedAt", void 0);
Wallet = __decorate([
    Entity('wallets')
], Wallet);
export { Wallet };
//# sourceMappingURL=wallet.entity.js.map