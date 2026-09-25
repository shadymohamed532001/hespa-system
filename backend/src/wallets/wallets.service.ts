import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  OnModuleInit,
} from '@nestjs/common';
import { msg } from '../common/i18n/locale-context.js';
import { InjectRepository } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { DataSource, Repository } from 'typeorm';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { Wallet } from '../database/entities/wallet.entity.js';
import { Treasury } from '../database/entities/treasury.entity.js';
import { LedgerCategory } from '../database/enums.js';
import { CreateWalletDto } from './dto/create-wallet.dto.js';
import { TopUpWalletDto } from './dto/top-up-wallet.dto.js';
import { CustomerWalletOperationDto } from './dto/customer-wallet-operation.dto.js';
import { walletCommission } from './wallet-commission.js';
import { shouldSeedDemoData } from '../config/demo-data.js';

export const WALLET_DAILY_TOP_UP_LIMIT = 60_000;
export const WALLET_MONTHLY_TOP_UP_LIMIT = 200_000;

function cairoPeriod() {
  const day = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Africa/Cairo',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
  return { day, month: day.slice(0, 7) };
}

@Injectable()
export class WalletsService implements OnModuleInit {
  constructor(
    @InjectRepository(Wallet) private readonly wallets: Repository<Wallet>,
    private readonly dataSource: DataSource,
    private readonly config: ConfigService,
  ) {}

  async onModuleInit() {
    if (!shouldSeedDemoData(this.config)) return;
    if (await this.wallets.count()) return;
    await this.wallets.save([
      this.wallets.create({
        name: 'محفظة 01',
        ownerName: 'مالك المحفظة التجريبية',
        type: 'vodafone_cash',
        openingBalance: 11250,
        balance: 11250,
      }),
      this.wallets.create({
        name: 'InstaPay 01',
        ownerName: 'مالك حساب InstaPay التجريبي',
        type: 'instapay',
        openingBalance: 16550,
        balance: 16550,
      }),
    ]);
  }

  findAll(includeInactive = false) {
    return this.wallets.find({
      where: includeInactive ? {} : { active: true },
      order: { createdAt: 'ASC' },
    });
  }

  async create(dto: CreateWalletDto, username: string) {
    const name = dto.name.trim();
    if (!name) throw new BadRequestException(msg({ ar: 'اسم أو رقم المحفظة مطلوب', en: 'Wallet name or number is required' }));
    const ownerName = dto.ownerName?.trim() ?? '';
    if (await this.wallets.exists({ where: { name } })) {
      throw new ConflictException(msg({ ar: 'توجد محفظة بنفس الاسم أو الرقم بالفعل', en: 'A wallet with this name or number already exists' }));
    }
    return this.dataSource.transaction(async (manager) => {
      const wallet = await manager.getRepository(Wallet).save(
        manager.getRepository(Wallet).create({
          name,
          ownerName,
          type: dto.type,
          openingBalance: dto.openingBalance,
          balance: dto.openingBalance,
        }),
      );
      if (dto.openingBalance > 0) {
        await manager.getRepository(LedgerEntry).save({
          category: LedgerCategory.OPENING_BALANCE,
          amount: dto.openingBalance,
          entityType: 'wallet',
          entityId: wallet.id,
          reference: null,
          description: `رصيد افتتاحي للمحفظة ${wallet.name}${wallet.ownerName ? ` باسم ${wallet.ownerName}` : ''}`,
          performedBy: username,
        });
      }
      return wallet;
    });
  }

  async topUp(id: string, dto: TopUpWalletDto, username: string) {
    return this.dataSource.transaction(async (manager) => {
      const repo = manager.getRepository(Wallet);
      const wallet = await repo.findOne({
        where: { id, active: true },
        lock: { mode: 'pessimistic_write' },
      });
      if (!wallet) throw new NotFoundException(msg({ ar: 'المحفظة غير موجودة أو موقوفة', en: 'Wallet not found or inactive' }));
      const period = cairoPeriod();
      if (wallet.counterDay !== period.day) {
        wallet.counterDay = period.day;
        wallet.dailyTopUp = 0;
        wallet.todayTopUp = 0;
        wallet.openingBalance = wallet.balance;
      }
      if (wallet.counterMonth !== period.month) {
        wallet.counterMonth = period.month;
        wallet.monthlyTopUp = 0;
      }
      if (wallet.dailyTopUp + dto.amount > WALLET_DAILY_TOP_UP_LIMIT) {
        throw new BadRequestException({
          message: msg({ ar: 'سيتم تجاوز حد شحن المحفظة اليومي', en: 'This would exceed the wallet daily top-up limit' }),
          limit: WALLET_DAILY_TOP_UP_LIMIT,
          available: Math.max(0, WALLET_DAILY_TOP_UP_LIMIT - wallet.dailyTopUp),
        });
      }
      if (wallet.monthlyTopUp + dto.amount > WALLET_MONTHLY_TOP_UP_LIMIT) {
        throw new BadRequestException({
          message: msg({ ar: 'سيتم تجاوز حد شحن المحفظة الشهري', en: 'This would exceed the wallet monthly top-up limit' }),
          limit: WALLET_MONTHLY_TOP_UP_LIMIT,
          available: Math.max(
            0,
            WALLET_MONTHLY_TOP_UP_LIMIT - wallet.monthlyTopUp,
          ),
        });
      }
      wallet.balance += dto.amount;
      wallet.todayTopUp += dto.amount;
      wallet.dailyTopUp += dto.amount;
      wallet.monthlyTopUp += dto.amount;
      await repo.save(wallet);
      await manager.getRepository(LedgerEntry).save({
        category: LedgerCategory.TOP_UP,
        amount: dto.amount,
        entityType: 'wallet',
        entityId: wallet.id,
        reference: dto.reference ?? null,
        description: `شحن ${wallet.name}${wallet.ownerName ? ` باسم ${wallet.ownerName}` : ''}`,
        performedBy: username,
      });
      return wallet;
    });
  }

  async customerOperation(
    id: string,
    dto: CustomerWalletOperationDto,
    username: string,
  ) {
    return this.dataSource.transaction(async (manager) => {
      // Lock in the same order as internal-transfer reversals: treasury, wallet.
      const treasuryRepo = manager.getRepository(Treasury);
      const treasury = await treasuryRepo.findOne({
        where: { id: 'main' },
        lock: { mode: 'pessimistic_write' },
      });
      if (!treasury) {
        throw new NotFoundException(
          msg({ ar: 'الخزنة غير مهيأة', en: 'Treasury is not initialized' }),
        );
      }
      const walletRepo = manager.getRepository(Wallet);
      const wallet = await walletRepo.findOne({
        where: { id, active: true },
        lock: { mode: 'pessimistic_write' },
      });
      if (!wallet) {
        throw new NotFoundException(
          msg({
            ar: 'المحفظة غير موجودة أو موقوفة',
            en: 'Wallet not found or inactive',
          }),
        );
      }

      const amount = Number(dto.amount);
      const commission = walletCommission(wallet.type, dto.direction, amount);
      const feePaymentMode = dto.feePaymentMode ?? 'deducted';
      if (dto.direction === 'send' && dto.feePaymentMode) {
        throw new BadRequestException(
          msg({
            ar: 'طريقة دفع العمولة تخص استلام التحويل فقط',
            en: 'Fee payment mode only applies when receiving a transfer',
          }),
        );
      }
      if (
        dto.direction === 'receive' &&
        feePaymentMode === 'deducted' &&
        amount <= commission
      ) {
        throw new BadRequestException(
          msg({
            ar: 'المبلغ أقل من العمولة؛ اختر تحصيل العمولة منفصلة',
            en: 'The amount does not cover the fee; collect the fee separately',
          }),
        );
      }

      const send = dto.direction === 'send';
      const cashToCollect = send
        ? amount + commission
        : feePaymentMode === 'separate'
          ? commission
          : 0;
      const cashToPay = send
        ? 0
        : feePaymentMode === 'separate'
          ? amount
          : amount - commission;
      const treasuryAfter = Number(
        (Number(treasury.balance) + cashToCollect - cashToPay).toFixed(2),
      );
      if (send && Number(wallet.balance) < amount) {
        throw new BadRequestException(
          msg({
            ar: 'رصيد المحفظة غير كافٍ',
            en: 'Insufficient wallet balance',
          }),
        );
      }
      if (treasuryAfter < 0) {
        throw new BadRequestException(
          msg({
            ar: 'رصيد الخزنة لا يكفي لتسليم الكاش',
            en: 'Insufficient treasury cash for the payout',
          }),
        );
      }

      wallet.balance = Number(
        (Number(wallet.balance) + (send ? -amount : amount)).toFixed(2),
      );
      wallet.commissionBalance = Number(
        (Number(wallet.commissionBalance) + commission).toFixed(2),
      );
      treasury.balance = treasuryAfter;
      await walletRepo.save(wallet);
      await treasuryRepo.save(treasury);

      const ledger = manager.getRepository(LedgerEntry);
      const principal = await ledger.save({
        category: LedgerCategory.INTERNAL_TRANSFER,
        amount,
        entityType: 'internal_transfer',
        entityId: null,
        sourceType: send ? 'wallet' : 'treasury',
        sourceId: send ? wallet.id : 'main',
        targetType: send ? 'treasury' : 'wallet',
        targetId: send ? 'main' : wallet.id,
        reference: dto.reference ?? null,
        description: send
          ? `تحويل لعميل من ${wallet.name} واستلام الكاش في الخزنة`
          : `استلام تحويل عميل على ${wallet.name} وتسليم الكاش من الخزنة`,
        performedBy: username,
        metadata: {
          customerWalletOperation: true,
          direction: dto.direction,
          feePaymentMode: send ? null : feePaymentMode,
          purpose: dto.purpose ?? null,
        },
      });
      await ledger.save({
        category: LedgerCategory.WALLET_CASH_FEE,
        amount: commission,
        entityType: 'treasury',
        entityId: 'main',
        reference: dto.reference ?? null,
        description: `عمولة كاش عملية ${wallet.name}`,
        performedBy: username,
        metadata: { customerWalletTransferEntryId: principal.id },
      });
      await ledger.save({
        category: LedgerCategory.COMMISSION,
        amount: commission,
        entityType: 'wallet',
        entityId: wallet.id,
        reference: dto.reference ?? null,
        description: `عمولة عملية عميل من ${wallet.name}`,
        performedBy: username,
        metadata: { customerWalletTransferEntryId: principal.id },
      });

      return {
        wallet,
        treasuryBalance: treasury.balance,
        commission,
        cashToCollect: Number(cashToCollect.toFixed(2)),
        cashToPay: Number(cashToPay.toFixed(2)),
        operationEntryId: principal.id,
      };
    });
  }

  async setActive(id: string, active: boolean) {
    const wallet = await this.wallets.findOne({ where: { id } });
    if (!wallet) throw new NotFoundException(msg({ ar: 'المحفظة غير موجودة', en: 'Wallet not found' }));
    wallet.active = active;
    return this.wallets.save(wallet);
  }

  async remove(id: string, username: string) {
    const wallet = await this.wallets.findOne({ where: { id } });
    if (!wallet) throw new NotFoundException(msg({ ar: 'المحفظة غير موجودة', en: 'Wallet not found' }));

    const history = await this.dataSource
      .getRepository(LedgerEntry)
      .createQueryBuilder('entry')
      .where('(entry.entity_type = :type AND entry.entity_id = :id)', {
        type: 'wallet',
        id,
      })
      .orWhere('(entry.source_type = :type AND entry.source_id = :id)', {
        type: 'wallet',
        id,
      })
      .orWhere('(entry.target_type = :type AND entry.target_id = :id)', {
        type: 'wallet',
        id,
      })
      .getCount();

    if (wallet.balance !== 0 || wallet.commissionBalance !== 0 || history > 0) {
      throw new BadRequestException(
        msg({ ar: 'لا يمكن حذف المحفظة نهائيًا إلا إذا كان الرصيد والعمولة صفرًا ولا توجد حركات مرتبطة بها', en: 'Permanent wallet delete is only allowed when balance and commission are zero and there are no related movements' }),
      );
    }

    const name = wallet.name;
    await this.wallets.remove(wallet);
    return {
      deleted: true,
      id,
      name,
      deletedBy: username,
      message: `تم حذف المحفظة «${name}» نهائيًا`,
    };
  }
}
