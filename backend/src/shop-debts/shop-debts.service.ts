import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, EntityManager, Repository } from 'typeorm';
import { inTransaction } from '../common/in-transaction.js';
import { msg } from '../common/i18n/locale-context.js';
import { ShopDebtMovement } from '../database/entities/shop-debt-movement.entity.js';
import { CancelShopDebtDto, RecordShopDebtDto } from './dto/shop-debt.dto.js';

const cents = (value: number | string | null | undefined) =>
  Math.round(Number(value ?? 0) * 100);

/**
 * A record-only notebook of money the shop owner borrowed from people and
 * paid back. It never touches treasury or account balances.
 */
@Injectable()
export class ShopDebtsService {
  constructor(
    @InjectRepository(ShopDebtMovement)
    private readonly movements: Repository<ShopDebtMovement>,
    private readonly dataSource: DataSource,
  ) {}

  /** Everyone the shop borrowed from, with what is still owed to them. */
  async findPeople() {
    const rows: Array<{
      personName: string;
      borrowed: string;
      repaid: string;
      lastActivityAt: Date;
      movementsCount: string;
    }> = await this.dataSource.query(`
      SELECT MIN(person_name) AS "personName",
        COALESCE(SUM(amount) FILTER (WHERE kind = 'borrow'), 0) AS borrowed,
        COALESCE(SUM(amount) FILTER (WHERE kind = 'repay'), 0) AS repaid,
        MAX(created_at) AS "lastActivityAt",
        COUNT(*) AS "movementsCount"
      FROM shop_debt_movements
      WHERE cancelled_at IS NULL
      GROUP BY LOWER(TRIM(person_name))
    `);
    return rows
      .map((row) => ({
        personName: row.personName,
        borrowed: cents(row.borrowed) / 100,
        repaid: cents(row.repaid) / 100,
        owed: (cents(row.borrowed) - cents(row.repaid)) / 100,
        lastActivityAt: row.lastActivityAt,
        movementsCount: Number(row.movementsCount),
      }))
      .sort(
        (a, b) =>
          b.owed - a.owed ||
          new Date(b.lastActivityAt).getTime() -
            new Date(a.lastActivityAt).getTime(),
      );
  }

  /** One person's movements, newest first, with what was owed after each. */
  async history(personName: string) {
    const name = personName.trim();
    const rows = await this.movements
      .createQueryBuilder('movement')
      .where('LOWER(TRIM(movement.personName)) = LOWER(:name)', { name })
      .orderBy('movement.createdAt', 'ASC')
      .addOrderBy('movement.reference', 'ASC')
      .getMany();
    let owed = 0;
    let borrowed = 0;
    let repaid = 0;
    const movements = rows.map((row) => {
      if (!row.cancelledAt) {
        const amount = cents(row.amount);
        if (row.kind === 'borrow') {
          owed += amount;
          borrowed += amount;
        } else {
          owed -= amount;
          repaid += amount;
        }
      }
      return {
        ...row,
        cancelled: row.cancelledAt != null,
        owedAfter: owed / 100,
      };
    });
    return {
      personName: rows[0]?.personName ?? name,
      owed: owed / 100,
      borrowed: borrowed / 100,
      repaid: repaid / 100,
      movements: movements.reverse(),
    };
  }

  async record(dto: RecordShopDebtDto, username: string) {
    return inTransaction(
      this.dataSource,
      undefined,
    )(async (manager) => {
      const name = dto.personName.trim();
      await this.lockPerson(manager, name);
      const owed = await this.owed(manager, name);
      const amount = cents(dto.amount) / 100;
      if (dto.kind === 'repay') {
        if (owed <= 0) {
          throw new BadRequestException(
            msg({
              ar: 'المحل مش مستلف حاجة من الشخص ده',
              en: 'The shop owes nothing to this person',
            }),
          );
        }
        if (amount > owed) {
          throw new BadRequestException(
            msg({
              ar: `أقصى مبلغ سداد هو ${owed}`,
              en: `The maximum repayment is ${owed}`,
            }),
          );
        }
      }
      await manager.query(
        `SELECT pg_advisory_xact_lock(hashtext('hesba:shop-debt-reference'))`,
      );
      const number =
        (await manager.getRepository(ShopDebtMovement).count()) + 1;
      const saved = await manager.getRepository(ShopDebtMovement).save({
        reference: `DBT-${String(number).padStart(3, '0')}`,
        personName: name,
        kind: dto.kind,
        amount,
        note: dto.note?.trim() || null,
        performedBy: username,
        cancelledAt: null,
        cancelledBy: null,
        cancelReason: null,
      });
      const after =
        (cents(owed) + (dto.kind === 'borrow' ? 1 : -1) * cents(amount)) / 100;
      return { ...saved, owedAfter: after };
    });
  }

  async cancel(id: string, dto: CancelShopDebtDto, username: string) {
    return inTransaction(
      this.dataSource,
      undefined,
    )(async (manager) => {
      const repo = manager.getRepository(ShopDebtMovement);
      const movement = await repo.findOne({
        where: { id },
        lock: { mode: 'pessimistic_write' },
      });
      if (!movement) {
        throw new NotFoundException(
          msg({ ar: 'الحركة غير موجودة', en: 'Movement not found' }),
        );
      }
      if (movement.cancelledAt) {
        throw new BadRequestException(
          msg({ ar: 'الحركة ملغية بالفعل', en: 'Movement already cancelled' }),
        );
      }
      await this.lockPerson(manager, movement.personName);
      if (movement.kind === 'borrow') {
        const owed = await this.owed(manager, movement.personName);
        if (cents(owed) < cents(movement.amount)) {
          throw new BadRequestException(
            msg({
              ar: 'اتسدد جزء من السلفة دي؛ الغِ السداد الأول',
              en: 'Part of this loan was repaid; cancel the repayment first',
            }),
          );
        }
      }
      movement.cancelledAt = new Date();
      movement.cancelledBy = username;
      movement.cancelReason = dto.reason.trim();
      return repo.save(movement);
    });
  }

  private lockPerson(manager: EntityManager, name: string) {
    return manager.query(`SELECT pg_advisory_xact_lock(hashtext($1))`, [
      `hesba:shop-debt:${name.trim().toLowerCase()}`,
    ]);
  }

  private async owed(manager: EntityManager, name: string): Promise<number> {
    const [row] = await manager.query(
      `
      SELECT
        COALESCE(SUM(amount) FILTER (WHERE kind = 'borrow'), 0) -
        COALESCE(SUM(amount) FILTER (WHERE kind = 'repay'), 0) AS owed
      FROM shop_debt_movements
      WHERE cancelled_at IS NULL AND LOWER(TRIM(person_name)) = LOWER(TRIM($1))
    `,
      [name],
    );
    return cents(row?.owed) / 100;
  }
}
