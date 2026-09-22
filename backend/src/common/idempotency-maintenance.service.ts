import { Injectable, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { LessThan, Repository } from 'typeorm';
import {
  IdempotencyRecord,
  IdempotencyStatus,
} from '../database/entities/idempotency-record.entity.js';

@Injectable()
export class IdempotencyMaintenanceService implements OnModuleInit {
  constructor(
    @InjectRepository(IdempotencyRecord)
    private readonly records: Repository<IdempotencyRecord>,
  ) {}

  async onModuleInit() {
    const cutoff = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    await this.records.delete({
      status: IdempotencyStatus.COMPLETED,
      updatedAt: LessThan(cutoff),
    });
  }
}
