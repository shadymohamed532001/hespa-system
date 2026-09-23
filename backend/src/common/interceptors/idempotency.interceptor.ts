import {
  BadRequestException,
  CallHandler,
  ConflictException,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { InjectRepository } from '@nestjs/typeorm';
import { createHash } from 'node:crypto';
import { catchError, from, mergeMap, Observable, of, throwError } from 'rxjs';
import { Repository } from 'typeorm';
import { IDEMPOTENT_KEY } from '../decorators/idempotent.decorator.js';
import {
  IdempotencyRecord,
  IdempotencyStatus,
} from '../../database/entities/idempotency-record.entity.js';
import { msg } from '../i18n/locale-context.js';

type RequestShape = {
  method: string;
  originalUrl: string;
  body?: unknown;
  headers: Record<string, string | string[] | undefined>;
  user?: { userId?: string };
};

@Injectable()
export class IdempotencyInterceptor implements NestInterceptor {
  constructor(
    private readonly reflector: Reflector,
    @InjectRepository(IdempotencyRecord)
    private readonly records: Repository<IdempotencyRecord>,
  ) {}

  async intercept(
    context: ExecutionContext,
    next: CallHandler,
  ): Promise<Observable<unknown>> {
    const required = this.reflector.getAllAndOverride<boolean>(IDEMPOTENT_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!required) return next.handle();

    const request = context.switchToHttp().getRequest<RequestShape>();
    const userId = request.user?.userId;
    if (!userId)
      throw new BadRequestException(
        msg({
          ar: 'تعذر تحديد المستخدم للعملية',
          en: 'Could not determine the user for this operation',
        }),
      );

    const rawHeader = request.headers['idempotency-key'];
    const key = Array.isArray(rawHeader) ? rawHeader[0] : rawHeader;
    if (!key || !/^[A-Za-z0-9._:-]{16,120}$/.test(key)) {
      throw new BadRequestException(
        msg({
          ar: 'يلزم إرسال Idempotency-Key صالح لمنع تكرار العملية',
          en: 'A valid Idempotency-Key is required to prevent duplicate operations',
        }),
      );
    }

    const path = request.originalUrl.split('?')[0];
    const requestHash = createHash('sha256')
      .update(
        JSON.stringify({
          method: request.method,
          path,
          body: request.body ?? null,
        }),
      )
      .digest('hex');

    const record = this.records.create({
      userId,
      key,
      method: request.method,
      path,
      requestHash,
      status: IdempotencyStatus.PENDING,
      response: null,
    });

    try {
      await this.records.save(record);
    } catch (error) {
      if (!this.isUniqueViolation(error)) throw error;
      const existing = await this.records.findOne({ where: { userId, key } });
      if (!existing) throw error;
      if (existing.requestHash !== requestHash) {
        throw new ConflictException(
          msg({
            ar: 'تم استخدام مفتاح العملية مع طلب مختلف',
            en: 'This idempotency key was already used with a different request',
          }),
        );
      }
      if (existing.status === IdempotencyStatus.COMPLETED) {
        return of(existing.response);
      }
      throw new ConflictException({
        code: 'IDEMPOTENCY_IN_PROGRESS',
        message: msg({
          ar: 'العملية قيد التنفيذ؛ ستتم إعادة المحاولة بنفس المفتاح',
          en: 'Operation is already in progress; retry with the same key',
        }),
        retryAfterMs: 350,
      });
    }

    return next.handle().pipe(
      mergeMap((response) =>
        from(this.completeRecord(record.id, response)).pipe(
          mergeMap(() => of(response)),
          catchError((error: unknown) => {
            // The protected operation has already succeeded. Keep the record in
            // PENDING rather than deleting it and risking a duplicate retry.
            console.error('Failed to complete idempotency record', error);
            return of(response);
          }),
        ),
      ),
      catchError((error: unknown) =>
        from(this.releaseRecord(record.id)).pipe(
          mergeMap(() => throwError(() => error)),
        ),
      ),
    );
  }

  private async completeRecord(id: string, response: unknown) {
    let lastError: unknown;
    for (let attempt = 0; attempt < 3; attempt++) {
      try {
        await this.records.update(id, {
          status: IdempotencyStatus.COMPLETED,
          response: response as never,
        });
        return;
      } catch (error) {
        lastError = error;
        if (attempt < 2) {
          await new Promise((resolve) =>
            setTimeout(resolve, 25 * 2 ** attempt),
          );
        }
      }
    }
    throw lastError;
  }

  private async releaseRecord(id: string) {
    try {
      await this.records.delete(id);
    } catch (error) {
      // Preserve the original controller error. A leftover PENDING row is
      // intentionally safer than deleting an uncertain key and allowing the
      // client to repeat a money movement.
      console.error('Failed to release idempotency record', error);
    }
  }

  private isUniqueViolation(error: unknown) {
    if (!error || typeof error !== 'object') return false;
    const candidate = error as {
      code?: string;
      driverError?: { code?: string };
    };
    return (
      candidate.code === '23505' || candidate.driverError?.code === '23505'
    );
  }
}
