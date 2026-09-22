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
import { DEFAULT_EMPLOYEE_PERMISSIONS, DEFAULT_USER_LIMITS, UserRole, } from '../enums.js';
let User = class User {
    id;
    username;
    displayName;
    passwordHash;
    role;
    permissions;
    limits;
    active;
    tokenVersion;
    createdAt;
    updatedAt;
};
__decorate([
    PrimaryGeneratedColumn('uuid'),
    __metadata("design:type", String)
], User.prototype, "id", void 0);
__decorate([
    Column({ unique: true, length: 80 }),
    __metadata("design:type", String)
], User.prototype, "username", void 0);
__decorate([
    Column({ name: 'display_name', length: 120, default: '' }),
    __metadata("design:type", String)
], User.prototype, "displayName", void 0);
__decorate([
    Column({ name: 'password_hash' }),
    __metadata("design:type", String)
], User.prototype, "passwordHash", void 0);
__decorate([
    Column({ type: 'enum', enum: UserRole }),
    __metadata("design:type", String)
], User.prototype, "role", void 0);
__decorate([
    Column({
        type: 'jsonb',
        default: () => `'${JSON.stringify(DEFAULT_EMPLOYEE_PERMISSIONS)}'`,
    }),
    __metadata("design:type", Array)
], User.prototype, "permissions", void 0);
__decorate([
    Column({
        type: 'jsonb',
        default: () => `'${JSON.stringify(DEFAULT_USER_LIMITS)}'`,
    }),
    __metadata("design:type", Object)
], User.prototype, "limits", void 0);
__decorate([
    Column({ default: true }),
    __metadata("design:type", Boolean)
], User.prototype, "active", void 0);
__decorate([
    Column({ name: 'token_version', type: 'int', default: 0 }),
    __metadata("design:type", Number)
], User.prototype, "tokenVersion", void 0);
__decorate([
    CreateDateColumn({ name: 'created_at' }),
    __metadata("design:type", Date)
], User.prototype, "createdAt", void 0);
__decorate([
    UpdateDateColumn({ name: 'updated_at' }),
    __metadata("design:type", Date)
], User.prototype, "updatedAt", void 0);
User = __decorate([
    Entity('users')
], User);
export { User };
//# sourceMappingURL=user.entity.js.map