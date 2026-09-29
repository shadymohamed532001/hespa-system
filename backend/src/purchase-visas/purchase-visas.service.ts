import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { purchaseVisaProfit } from '../accounts/profit-commission.js';
import { msg } from '../common/i18n/locale-context.js';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { PurchaseVisa } from '../database/entities/purchase-visa.entity.js';
import { Treasury } from '../database/entities/treasury.entity.js';
import { LedgerCategory } from '../database/enums.js';
import {
  CreatePurchaseVisaDto,
  WithdrawPurchaseVisaDto,
} from './dto/purchase-visa.dto.js';
import { parsePurchaseVisaCard } from './purchase-visa-card.js';

@Injectable()
export class PurchaseVisasService {
  constructor(
    @InjectRepository(PurchaseVisa)
    private readonly visas: Repository<PurchaseVisa>,
    private readonly dataSource: DataSource,
  ) {}

  findAll(includeInactive = false) {
    return this.visas.find({
      where: includeInactive ? {} : { active: true },
      order: { createdAt: 'ASC' },
    });
  }

  async create(dto: CreatePurchaseVisaDto, username: string) {
    const name = dto.name.trim();
    if (!name) {
      throw new BadRequestException(
        msg({ ar: 'اسم الفيزا مطلوب', en: 'Visa name is required' }),
      );
    }
    const ownerName = dto.ownerName.trim();
    if (ownerName.length < 2) {
      throw new BadRequestException(
        msg({
          ar: 'اسم صاحب الفيزا مطلوب',
          en: 'The visa holder name is required',
        }),
      );
    }
    const card = parsePurchaseVisaCard(dto.cardNumber, dto.expiry.trim());
    if (!card.ok) {
      throw new BadRequestException(
        msg(
          card.error === 'expired'
            ? { ar: 'الفيزا منتهية', en: 'The visa is expired' }
            : card.error === 'expiry'
              ? {
                  ar: 'تاريخ الانتهاء لازم يكون شهر/سنة، مثل 09/28',
                  en: 'Expiry must be a month and year, like 09/28',
                }
              : {
                  ar: 'رقم الفيزا لازم يكون ١٦ رقم صحيح',
                  en: 'The visa number must be 16 valid digits',
                },
        ),
      );
    }
    if (await this.visas.exists({ where: { name } })) {
      throw new ConflictException(
        msg({
          ar: 'يوجد فيزا بنفس الاسم',
          en: 'A visa with this name already exists',
        }),
      );
    }
    if (await this.visas.exists({ where: { cardNumber: card.cardNumber } })) {
      throw new ConflictException(
        msg({
          ar: 'رقم الفيزا مسجّل قبل كده',
          en: 'This visa number is already registered',
        }),
      );
    }
    const opening = Number(dto.openingBalance ?? 0);
    return this.dataSource.transaction(async (manager) => {
      const repo = manager.getRepository(PurchaseVisa);
      const visa = await repo.save(
        repo.create({
          name,
          cardNumber: card.cardNumber,
          ownerName,
          expiresOn: card.expiresOn,
          balance: opening,
          commissionBalance: 0,
          active: true,
        }),
      );
      if (opening > 0) {
        await manager.getRepository(LedgerEntry).save({
          category: LedgerCategory.OPENING_BALANCE,
          amount: opening,
          entityType: 'purchase_visa',
          entityId: visa.id,
          reference: null,
          description: `رصيد افتتاحي لفيزا المشتريات ${visa.name}`,
          performedBy: username,
        });
      }
      return visa;
    });
  }

  async withdraw(id: string, dto: WithdrawPurchaseVisaDto, username: string) {
    const agentName = dto.agentName.trim();
    if (!agentName) {
      throw new BadRequestException(
        msg({ ar: 'اسم المندوب مطلوب', en: 'Agent name is required' }),
      );
    }
    const principal = Number(Number(dto.amount).toFixed(2));
    const { grossProfit, serviceFee, netProfit } = purchaseVisaProfit(
      principal,
      dto.withService,
    );
    const treasuryCredit = Number((principal + netProfit).toFixed(2));

    return this.dataSource.transaction(async (manager) => {
      const treasury = await manager.getRepository(Treasury).findOne({
        where: { id: 'main' },
        lock: { mode: 'pessimistic_write' },
      });
      if (!treasury) {
        throw new NotFoundException(
          msg({ ar: 'الخزنة غير مهيأة', en: 'Treasury is not initialized' }),
        );
      }
      const visa = await manager.getRepository(PurchaseVisa).findOne({
        where: { id, active: true },
        lock: { mode: 'pessimistic_write' },
      });
      if (!visa) {
        throw new NotFoundException(
          msg({
            ar: 'الفيزا غير موجودة أو موقوفة',
            en: 'Visa not found or inactive',
          }),
        );
      }
      if (Number(visa.balance) < principal) {
        throw new BadRequestException(
          msg({ ar: 'رصيد الفيزا غير كافٍ', en: 'Insufficient visa balance' }),
        );
      }

      visa.balance = Number((Number(visa.balance) - principal).toFixed(2));
      visa.commissionBalance = Number(
        (Number(visa.commissionBalance) + netProfit).toFixed(2),
      );
      treasury.balance = Number(
        (Number(treasury.balance) + treasuryCredit).toFixed(2),
      );
      await manager.save(visa);
      await manager.save(treasury);

      const serviceText = dto.withService
        ? `بخدمة ماكينة ${serviceFee.toFixed(2)} ج.م، وصافي المكسب ${netProfit.toFixed(2)} ج.م`
        : `من غير خدمة، والمكسب ${netProfit.toFixed(2)} ج.م`;
      const note = dto.note?.trim();
      const description = `سحب ${principal.toFixed(2)} ج.م من فيزا ${visa.name} توريد للمندوب ${agentName}. ${serviceText}. دخل الخزنة ${treasuryCredit.toFixed(2)} ج.م`;
      const entry = await manager.getRepository(LedgerEntry).save({
        category: LedgerCategory.PURCHASE_VISA_USAGE,
        amount: treasuryCredit,
        entityType: 'treasury',
        entityId: 'main',
        sourceType: 'purchase_visa',
        sourceId: visa.id,
        reference: null,
        description: note ? `${description} — ${note}` : description,
        performedBy: username,
        metadata: {
          visaId: visa.id,
          visaName: visa.name,
          agentName,
          principal,
          withService: dto.withService,
          grossProfit,
          serviceFee,
          netProfit,
          treasuryCredit,
        },
      });
      if (netProfit > 0) {
        await manager.getRepository(LedgerEntry).save({
          category: LedgerCategory.COMMISSION,
          amount: netProfit,
          entityType: 'purchase_visa',
          entityId: visa.id,
          reference: null,
          description: dto.withService
            ? `مكسب فيزا ${visa.name}: ١٣ جنيه لكل ألف بعد خصم خدمة الماكينة`
            : `مكسب فيزا ${visa.name}: ٢٠ جنيه لكل ألف`,
          performedBy: username,
          metadata: { purchaseVisaUsageEntryId: entry.id },
        });
      }
      return {
        id: entry.id,
        visa,
        principal,
        withService: dto.withService,
        grossProfit,
        serviceFee,
        netProfit,
        treasuryCredit,
        treasuryBalance: treasury.balance,
      };
    });
  }
}
