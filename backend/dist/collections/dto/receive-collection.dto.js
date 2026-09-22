var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
import { IsDateString, IsEnum, IsNumber, IsOptional, IsString, IsUUID, MaxLength, Min, MinLength } from 'class-validator';
import { ExecutionMode } from '../../database/enums.js';
export class ReceiveCollectionDto {
    agentName;
    companyName;
    amount;
    executionMode;
    receivedAt;
    accountId;
    commission = 0;
}
__decorate([
    IsString(),
    MinLength(2),
    MaxLength(150),
    __metadata("design:type", String)
], ReceiveCollectionDto.prototype, "agentName", void 0);
__decorate([
    IsString(),
    MinLength(2),
    MaxLength(150),
    __metadata("design:type", String)
], ReceiveCollectionDto.prototype, "companyName", void 0);
__decorate([
    IsNumber({ maxDecimalPlaces: 2 }),
    Min(0.01),
    __metadata("design:type", Number)
], ReceiveCollectionDto.prototype, "amount", void 0);
__decorate([
    IsEnum(ExecutionMode),
    __metadata("design:type", String)
], ReceiveCollectionDto.prototype, "executionMode", void 0);
__decorate([
    IsOptional(),
    IsDateString(),
    __metadata("design:type", String)
], ReceiveCollectionDto.prototype, "receivedAt", void 0);
__decorate([
    IsOptional(),
    IsUUID(),
    __metadata("design:type", String)
], ReceiveCollectionDto.prototype, "accountId", void 0);
__decorate([
    IsOptional(),
    IsNumber({ maxDecimalPlaces: 2 }),
    Min(0),
    __metadata("design:type", Object)
], ReceiveCollectionDto.prototype, "commission", void 0);
//# sourceMappingURL=receive-collection.dto.js.map