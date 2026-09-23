import { BadRequestException, Controller, Get, Query } from '@nestjs/common';
import { RequirePermissions } from '../common/decorators/permissions.decorator.js';
import { AppPermission, UserRole } from '../database/enums.js';
import { ReportsService } from './reports.service.js';
import { msg } from '../common/i18n/locale-context.js';
import { Roles } from '../common/decorators/roles.decorator.js';

@Roles(UserRole.ADMIN)
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
      throw new BadRequestException(
        msg({
          ar: 'تاريخ البداية والنهاية مطلوبان',
          en: 'Start and end dates are required',
        }),
      );
    }

    const start = new Date(from);
    const end = new Date(to);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
      throw new BadRequestException(
        msg({ ar: 'صيغة الفترة غير صحيحة', en: 'Invalid date range format' }),
      );
    }
    if (end <= start) {
      throw new BadRequestException(
        msg({
          ar: 'تاريخ النهاية يجب أن يكون بعد تاريخ البداية',
          en: 'End date must be after start date',
        }),
      );
    }
    if (end.getTime() - start.getTime() > 366 * 24 * 60 * 60 * 1000) {
      throw new BadRequestException(
        msg({
          ar: 'أقصى فترة للتقرير هي سنة واحدة',
          en: 'Maximum report range is one year',
        }),
      );
    }

    const allowedTypes = [
      'all',
      'treasury',
      'account',
      'wallet',
      'machine',
      'inventory',
    ];
    const scopeType = entityType || 'all';
    if (!allowedTypes.includes(scopeType)) {
      throw new BadRequestException(
        msg({ ar: 'نوع القسم غير مدعوم', en: 'Unsupported section type' }),
      );
    }

    return this.reports.summary({
      start,
      end,
      entityType: scopeType,
      entityId,
    });
  }
}
