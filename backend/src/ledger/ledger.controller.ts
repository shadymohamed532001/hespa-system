import { Controller, Get, Query } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { RequirePermissions } from '../common/decorators/permissions.decorator.js';
import { AppPermission } from '../database/enums.js';

@Controller('ledger')
@RequirePermissions(AppPermission.VIEW_BALANCES)
export class LedgerController {
  constructor(@InjectRepository(LedgerEntry) private readonly ledger: Repository<LedgerEntry>) {}

  @Get()
  findAll(@Query('limit') limit?: string) {
    const take = Math.min(Math.max(Number(limit) || 100, 1), 500);
    return this.ledger.find({ order: { createdAt: 'DESC' }, take });
  }
}
