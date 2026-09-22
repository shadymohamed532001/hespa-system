var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
import { Column, Entity, PrimaryColumn, UpdateDateColumn } from 'typeorm';
import { decimalTransformer } from '../decimal.transformer.js';
let Treasury = class Treasury {
    id;
    balance;
    updatedAt;
};
__decorate([
    PrimaryColumn({ default: 'main' }),
    __metadata("design:type", String)
], Treasury.prototype, "id", void 0);
__decorate([
    Column({ type: 'numeric', precision: 16, scale: 2, default: 0, transformer: decimalTransformer }),
    __metadata("design:type", Number)
], Treasury.prototype, "balance", void 0);
__decorate([
    UpdateDateColumn({ name: 'updated_at' }),
    __metadata("design:type", Date)
], Treasury.prototype, "updatedAt", void 0);
Treasury = __decorate([
    Entity('treasury')
], Treasury);
export { Treasury };
//# sourceMappingURL=treasury.entity.js.map