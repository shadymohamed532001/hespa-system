import { BadRequestException, Controller, Get, Query } from '@nestjs/common';
import { RequirePermissions } from '../common/decorators/permissions.decorator.js';
import { AppPermission } from '../database/enums.js';
import { ReportsService } from './reports.service.js';

@RequirePermissions(AppPermission.VIEW_BALANCES)
@Controller('reports')
export class ReportsController {
  constructor(private readonly reports: ReportsService) {}

  @Get('summary')
  summary(
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('entityType') entityType?: string,
    @Query('entityId') entityId?: string,
  ) {
    if (!from || !to) {
      throw new BadRequestException('تاريخ البداية والنهاية مطلوبان');
    }

    const start = new Date(from);
    const end = new Date(to);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
      throw new BadRequestException('صيغة الفترة غير صحيحة');
    }
    if (end <= start) {
      throw new BadRequestException('تاريخ النهاية يجب أن يكون بعد تاريخ البداية');
    }
    if (end.getTime() - start.getTime() > 366 * 24 * 60 * 60 * 1000) {
      throw new BadRequestException('أقصى فترة للتقرير هي سنة واحدة');
    }

    const allowedTypes = ['all', 'treasury', 'account', 'wallet', 'machine', 'inventory'];
    const scopeType = entityType || 'all';
    if (!allowedTypes.includes(scopeType)) {
      throw new BadRequestException('نوع القسم غير مدعوم');
    }

    return this.reports.summary({ start, end, entityType: scopeType, entityId });
  }
}
