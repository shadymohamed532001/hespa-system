var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
import { IsIn, IsNumber, IsOptional, IsString, IsUUID, Min, ValidateIf } from 'class-validator';
const assetTypes = ['treasury', 'account', 'wallet', 'machine'];
export class InternalTransferDto {
    fromType;
    fromId;
    toType;
    toId;
    amount;
    reference;
}
__decorate([
    IsIn(assetTypes),
    __metadata("design:type", Object)
], InternalTransferDto.prototype, "fromType", void 0);
__decorate([
    ValidateIf((value) => value.fromType !== 'treasury'),
    IsUUID(),
    __metadata("design:type", String)
], InternalTransferDto.prototype, "fromId", void 0);
__decorate([
    IsIn(assetTypes),
    __metadata("design:type", Object)
], InternalTransferDto.prototype, "toType", void 0);
__decorate([
    ValidateIf((value) => value.toType !== 'treasury'),
    IsUUID(),
    __metadata("design:type", String)
], InternalTransferDto.prototype, "toId", void 0);
__decorate([
    IsNumber({ maxDecimalPlaces: 2 }),
    Min(0.01),
    __metadata("design:type", Number)
], InternalTransferDto.prototype, "amount", void 0);
__decorate([
    IsOptional(),
    IsString(),
    __metadata("design:type", String)
], InternalTransferDto.prototype, "reference", void 0);
//# sourceMappingURL=internal-transfer.dto.js.map