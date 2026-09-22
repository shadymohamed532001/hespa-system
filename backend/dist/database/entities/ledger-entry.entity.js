var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn } from 'typeorm';
import { decimalTransformer } from '../decimal.transformer.js';
import { LedgerCategory } from '../enums.js';
let LedgerEntry = class LedgerEntry {
    id;
    category;
    amount;
    entityType;
    entityId;
    reference;
    description;
    performedBy;
    createdAt;
};
__decorate([
    PrimaryGeneratedColumn('uuid'),
    __metadata("design:type", String)
], LedgerEntry.prototype, "id", void 0);
__decorate([
    Column({ type: 'enum', enum: LedgerCategory }),
    __metadata("design:type", String)
], LedgerEntry.prototype, "category", void 0);
__decorate([
    Column({ type: 'numeric', precision: 16, scale: 2, transformer: decimalTransformer }),
    __metadata("design:type", Number)
], LedgerEntry.prototype, "amount", void 0);
__decorate([
    Column({ name: 'entity_type', length: 50 }),
    __metadata("design:type", String)
], LedgerEntry.prototype, "entityType", void 0);
__decorate([
    Column({ name: 'entity_id', length: 80, nullable: true }),
    __metadata("design:type", Object)
], LedgerEntry.prototype, "entityId", void 0);
__decorate([
    Column({ length: 80, nullable: true }),
    __metadata("design:type", Object)
], LedgerEntry.prototype, "reference", void 0);
__decorate([
    Column({ type: 'text' }),
    __metadata("design:type", String)
], LedgerEntry.prototype, "description", void 0);
__decorate([
    Column({ name: 'performed_by', length: 80 }),
    __metadata("design:type", String)
], LedgerEntry.prototype, "performedBy", void 0);
__decorate([
    CreateDateColumn({ name: 'created_at' }),
    __metadata("design:type", Date)
], LedgerEntry.prototype, "createdAt", void 0);
LedgerEntry = __decorate([
    Entity('ledger_entries')
], LedgerEntry);
export { LedgerEntry };
//# sourceMappingURL=ledger-entry.entity.js.map