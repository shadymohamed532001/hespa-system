import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  Request,
} from '@nestjs/common';
import { Idempotent } from '../common/decorators/idempotent.decorator.js';
import { Roles } from '../common/decorators/roles.decorator.js';
import { msg } from '../common/i18n/locale-context.js';
import { UserRole } from '../database/enums.js';
import { CancelShopDebtDto, RecordShopDebtDto } from './dto/shop-debt.dto.js';
import { ShopDebtsService } from './shop-debts.service.js';

type UserRequest = { user: { username: string } };

/** The shop owner's personal loans: admin only. */
@Controller('shop-debts')
@Roles(UserRole.ADMIN)
export class ShopDebtsController {
  constructor(private readonly debts: ShopDebtsService) {}

  @Get()
  findPeople() {
    return this.debts.findPeople();
  }

  @Get('history')
  history(@Query('personName') personName?: string) {
    const name = personName?.trim() ?? '';
    if (name.length < 2 || name.length > 150) {
      throw new BadRequestException(
        msg({ ar: 'اكتب اسم الشخص', en: 'Enter the person name' }),
      );
    }
    return this.debts.history(name);
  }

  @Idempotent()
  @Post()
  record(@Body() dto: RecordShopDebtDto, @Request() request: UserRequest) {
    return this.debts.record(dto, request.user.username);
  }

  @Idempotent()
  @Post(':id/cancel')
  cancel(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CancelShopDebtDto,
    @Request() request: UserRequest,
  ) {
    return this.debts.cancel(id, dto, request.user.username);
  }
}
