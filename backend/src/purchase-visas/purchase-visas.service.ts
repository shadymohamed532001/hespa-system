import { inTransaction } from '../common/in-transaction.js';
import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, EntityManager, Repository } from 'typeorm';
import { purchaseVisaProfit } from '../accounts/profit-commission.js';
import { msg } from '../common/i18n/locale-context.js';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { Machine } from '../database/entities/machine.entity.js';
import { PurchaseVisa } from '../database/entities/purchase-visa.entity.js';
import { Treasury } from '../database/entities/treasury.entity.js';
import { LedgerCategory } from '../database/enums.js';
import {
  CreatePurchaseVisaDto,
  ExternalVisaWithdrawDto,
  TopUpPurchaseVisaDto,
  WithdrawPurchaseVisaDto,
} from './dto/purchase-visa.dto.js';
import { parsePurchaseVisaCard } from './purchase-visa-card.js';

export const EXTERNAL_VISA_NAME = 'فيزا مشتريات خارجية';

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
    if (name.length < 2) {
      throw new BadRequestException(
        msg({
          ar: 'اسم صاحب الفيزا مطلوب',
          en: 'The visa holder name is required',
        }),
      );
    }
    const ownerName = dto.ownerName?.trim() || name;
    const cardText = dto.cardNumber?.trim() ?? '';
    const card = cardText
      ? parsePurchaseVisaCard(cardText, dto.expiry?.trim() ?? '')
      : ({ ok: true, cardNumber: null, expiresOn: null } as const);
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
    if (
      card.cardNumber &&
      (await this.visas.exists({ where: { cardNumber: card.cardNumber } }))
    ) {
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

  async topUp(
    id: string,
    dto: TopUpPurchaseVisaDto,
    username: string,
    transactionManager?: EntityManager,
  ) {
    const amount = Number(Number(dto.amount).toFixed(2));
    return inTransaction(
      this.dataSource,
      transactionManager,
    )(async (manager) => {
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
      visa.balance = Number((Number(visa.balance) + amount).toFixed(2));
      await manager.save(visa);
      const reference = dto.reference?.trim() || null;
      await manager.getRepository(LedgerEntry).save({
        category: LedgerCategory.TOP_UP,
        amount,
        entityType: 'purchase_visa',
        entityId: visa.id,
        reference,
        description: `شحن فيزا المشتريات ${visa.name}`,
        performedBy: username,
      });
      return visa;
    });
  }

  async withdraw(
    id: string,
    dto: WithdrawPurchaseVisaDto,
    username: string,
    transactionManager?: EntityManager,
  ) {
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

    return inTransaction(
      this.dataSource,
      transactionManager,
    )(async (manager) => {
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
          msg({
            ar: 'رصيد الفيزا غير كافٍ',
            en: 'Insufficient visa balance',
          }),
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

  /**
   * An external purchase visa (not registered here) is used once. Its balance
   * goes either to an agent, who pays cash into the treasury, or onto one of
   * the shop's machines. The visa's owner is paid cash from the treasury.
   */
  async withdrawExternal(
    dto: ExternalVisaWithdrawDto,
    username: string,
    transactionManager?: EntityManager,
  ) {
    const holderName = dto.holderName?.trim() || EXTERNAL_VISA_NAME;
    const toMachine = dto.destination === 'machine';
    const agentName = toMachine ? null : (dto.agentName ?? '').trim();
    if (!toMachine && !agentName) {
      throw new BadRequestException(
        msg({ ar: 'اسم المندوب مطلوب', en: 'Agent name is required' }),
      );
    }
    const principal = Number(Number(dto.amount).toFixed(2));
    const { grossProfit, serviceFee, netProfit } = purchaseVisaProfit(
      principal,
      dto.withService,
    );
    const profitPayer = toMachine ? 'customer' : (dto.profitPayer ?? 'agent');
    const customerCash =
      profitPayer === 'agent'
        ? principal
        : Number((principal - netProfit).toFixed(2));
    const agentCash = toMachine
      ? 0
      : profitPayer === 'agent'
        ? Number((principal + netProfit).toFixed(2))
        : principal;
    const treasuryCredit = Number((agentCash - customerCash).toFixed(2));

    return inTransaction(
      this.dataSource,
      transactionManager,
    )(async (manager) => {
      const treasury = await manager.getRepository(Treasury).findOne({
        where: { id: 'main' },
        lock: { mode: 'pessimistic_write' },
      });
      if (!treasury) {
        throw new NotFoundException(
          msg({ ar: 'الخزنة غير مهيأة', en: 'Treasury is not initialized' }),
        );
      }
      let machine: Machine | null = null;
      if (toMachine && dto.machineId) {
        machine = await manager.getRepository(Machine).findOne({
          where: { id: dto.machineId, active: true },
          lock: { mode: 'pessimistic_write' },
        });
        if (!machine) {
          throw new NotFoundException(
            msg({
              ar: 'الماكينة غير موجودة أو موقوفة',
              en: 'Machine not found or inactive',
            }),
          );
        }
      }
      const nextTreasury = Number(
        (Number(treasury.balance) + treasuryCredit).toFixed(2),
      );
      if (nextTreasury < 0) {
        throw new BadRequestException(
          msg({
            ar: 'رصيد الخزنة مش كفاية تدفع للعميل',
            en: 'The treasury balance is not enough to pay the customer',
          }),
        );
      }
      treasury.balance = nextTreasury;
      await manager.save(treasury);
      if (machine) {
        machine.loadedBalance = Number(
          (Number(machine.loadedBalance) + principal).toFixed(2),
        );
        await manager.save(machine);
      }

      const serviceText = dto.withService
        ? `بخدمة ماكينة ${serviceFee.toFixed(2)} ج.م`
        : 'من غير خدمة';
      const routeText = toMachine
        ? machine
          ? `على ماكينة ${machine.name}`
          : 'على ماكينة'
        : `توريد للمندوب ${agentName}، والمندوب دفع ${agentCash.toFixed(2)} ج.م`;
      const payerText =
        profitPayer === 'agent' ? 'المكسب على المندوب' : 'المكسب على العميل';
      const note = dto.note?.trim();
      const description = `سحب ${principal.toFixed(2)} ج.م من ${holderName} ${routeText}. العميل استلم ${customerCash.toFixed(2)} ج.م من الخزنة. ${serviceText}، ${payerText}، والمكسب ${netProfit.toFixed(2)} ج.م`;
      const ledger = manager.getRepository(LedgerEntry);
      const entry = await ledger.save({
        category: LedgerCategory.PURCHASE_VISA_USAGE,
        amount: treasuryCredit,
        entityType: 'treasury',
        entityId: 'main',
        sourceType: 'external_visa',
        sourceId: null,
        targetType: machine ? 'machine' : null,
        targetId: machine?.id ?? null,
        reference: null,
        description: note ? `${description} — ${note}` : description,
        performedBy: username,
        metadata: {
          externalVisa: true,
          holderName,
          destination: toMachine ? 'machine' : 'agent',
          machineId: machine?.id ?? null,
          machineName: machine?.name ?? null,
          agentName,
          principal,
          withService: dto.withService,
          profitPayer,
          grossProfit,
          serviceFee,
          netProfit,
          agentCash,
          customerCash,
          treasuryCredit,
          note: note || null,
        },
      });
      if (machine) {
        await ledger.save({
          category: LedgerCategory.TOP_UP,
          amount: principal,
          entityType: 'machine',
          entityId: machine.id,
          reference: null,
          description: `شحن ماكينة ${machine.name} من ${holderName}`,
          performedBy: username,
          metadata: { purchaseVisaUsageEntryId: entry.id, externalVisa: true },
        });
      }
      if (netProfit > 0) {
        await ledger.save({
          category: LedgerCategory.COMMISSION,
          amount: netProfit,
          entityType: 'treasury',
          entityId: 'main',
          reference: null,
          description: dto.withService
            ? `مكسب ${holderName}: ١٣ جنيه لكل ألف بعد خصم خدمة الماكينة`
            : `مكسب ${holderName}: ٢٠ جنيه لكل ألف`,
          performedBy: username,
          metadata: { purchaseVisaUsageEntryId: entry.id, externalVisa: true },
        });
      }
      return {
        id: entry.id,
        holderName,
        destination: toMachine ? 'machine' : 'agent',
        machineName: machine?.name ?? null,
        principal,
        withService: dto.withService,
        profitPayer,
        grossProfit,
        serviceFee,
        netProfit,
        agentCash,
        customerCash,
        treasuryCredit,
        treasuryBalance: treasury.balance,
      };
    });
  }
}
