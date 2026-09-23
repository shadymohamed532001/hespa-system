var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
import { Column, CreateDateColumn, Entity, JoinColumn, ManyToOne, PrimaryGeneratedColumn, } from 'typeorm';
import { decimalTransformer } from '../decimal.transformer.js';
import { CollectionStatus, ExecutionMode } from '../enums.js';
import { FinancialAccount } from './financial-account.entity.js';
let Collection = class Collection {
    id;
    reference;
    agentName;
    companyName;
    amount;
    executionMode;
    status;
    receivedAt;
    executedAt;
    reversedAt;
    reversalReason;
    account;
    accountId;
    commission;
    createdAt;
};
__decorate([
    PrimaryGeneratedColumn('uuid'),
    __metadata("design:type", String)
], Collection.prototype, "id", void 0);
__decorate([
    Column({ unique: true, length: 40 }),
    __metadata("design:type", String)
], Collection.prototype, "reference", void 0);
__decorate([
    Column({ name: 'agent_name', length: 150 }),
    __metadata("design:type", String)
], Collection.prototype, "agentName", void 0);
__decorate([
    Column({ name: 'company_name', length: 150 }),
    __metadata("design:type", String)
], Collection.prototype, "companyName", void 0);
__decorate([
    Column({
        type: 'numeric',
        precision: 16,
        scale: 2,
        transformer: decimalTransformer,
    }),
    __metadata("design:type", Number)
], Collection.prototype, "amount", void 0);
__decorate([
    Column({ type: 'enum', enum: ExecutionMode }),
    __metadata("design:type", String)
], Collection.prototype, "executionMode", void 0);
__decorate([
    Column({ type: 'enum', enum: CollectionStatus }),
    __metadata("design:type", String)
], Collection.prototype, "status", void 0);
__decorate([
    Column({ name: 'received_at', type: 'timestamptz' }),
    __metadata("design:type", Date)
], Collection.prototype, "receivedAt", void 0);
__decorate([
    Column({ name: 'executed_at', type: 'timestamptz', nullable: true }),
    __metadata("design:type", Object)
], Collection.prototype, "executedAt", void 0);
__decorate([
    Column({ name: 'reversed_at', type: 'timestamptz', nullable: true }),
    __metadata("design:type", Object)
], Collection.prototype, "reversedAt", void 0);
__decorate([
    Column({
        name: 'reversal_reason',
        type: 'varchar',
        length: 300,
        nullable: true,
    }),
    __metadata("design:type", Object)
], Collection.prototype, "reversalReason", void 0);
__decorate([
    ManyToOne(() => FinancialAccount, { nullable: true, onDelete: 'RESTRICT' }),
    JoinColumn({ name: 'account_id' }),
    __metadata("design:type", Object)
], Collection.prototype, "account", void 0);
__decorate([
    Column({ name: 'account_id', type: 'uuid', nullable: true }),
    __metadata("design:type", Object)
], Collection.prototype, "accountId", void 0);
__decorate([
    Column({
        type: 'numeric',
        precision: 16,
        scale: 2,
        default: 0,
        transformer: decimalTransformer,
    }),
    __metadata("design:type", Number)
], Collection.prototype, "commission", void 0);
__decorate([
    CreateDateColumn({ name: 'created_at' }),
    __metadata("design:type", Date)
], Collection.prototype, "createdAt", void 0);
Collection = __decorate([
    Entity('collections')
], Collection);
export { Collection };
//# sourceMappingURL=collection.entity.js.map