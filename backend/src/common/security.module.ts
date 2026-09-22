import { Global, Module } from '@nestjs/common';
import { APP_INTERCEPTOR } from '@nestjs/core';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuditEvent } from '../database/entities/audit-event.entity.js';
import { IdempotencyRecord } from '../database/entities/idempotency-record.entity.js';
import { AuditInterceptor } from './interceptors/audit.interceptor.js';
import { IdempotencyInterceptor } from './interceptors/idempotency.interceptor.js';
import { AuditController } from './audit.controller.js';
import { IdempotencyMaintenanceService } from './idempotency-maintenance.service.js';

@Global()
@Module({
  imports: [TypeOrmModule.forFeature([AuditEvent, IdempotencyRecord])],
  controllers: [AuditController],
  providers: [
    IdempotencyMaintenanceService,
    { provide: APP_INTERCEPTOR, useClass: AuditInterceptor },
    { provide: APP_INTERCEPTOR, useClass: IdempotencyInterceptor },
  ],
})
export class SecurityModule {}
