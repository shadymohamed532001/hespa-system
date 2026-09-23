import {
  CallHandler,
  ExecutionContext,
  HttpException,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Observable, tap } from 'rxjs';
import { Repository } from 'typeorm';
import { AuditEvent } from '../../database/entities/audit-event.entity.js';

type RequestShape = {
  method: string;
  originalUrl: string;
  body?: unknown;
  params?: unknown;
  query?: unknown;
  ip?: string;
  headers: Record<string, string | string[] | undefined>;
  user?: { userId?: string; username?: string };
};

const REDACTED_KEYS = new Set([
  'password',
  'passwordHash',
  'token',
  'accessToken',
  'refreshToken',
  'authorization',
  'secret',
]);
function sanitize(value: unknown, depth = 0): unknown {
  if (depth > 4) return '[truncated]';
  if (Array.isArray(value))
    return value.slice(0, 50).map((item) => sanitize(item, depth + 1));
  if (!value || typeof value !== 'object') {
    return typeof value === 'string' && value.length > 500
      ? `${value.slice(0, 500)}…`
      : value;
  }
  return Object.fromEntries(
    Object.entries(value as Record<string, unknown>).map(([key, item]) => [
      key,
      REDACTED_KEYS.has(key) ? '[redacted]' : sanitize(item, depth + 1),
    ]),
  );
}

@Injectable()
export class AuditInterceptor implements NestInterceptor {
  constructor(
    @InjectRepository(AuditEvent)
    private readonly events: Repository<AuditEvent>,
  ) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const request = context.switchToHttp().getRequest<RequestShape>();
    if (!['POST', 'PATCH', 'PUT', 'DELETE'].includes(request.method)) {
      return next.handle();
    }
    const response = context
      .switchToHttp()
      .getResponse<{ statusCode: number }>();
    const started = Date.now();

    return next.handle().pipe(
      tap({
        next: () => {
          void this.record(request, response.statusCode, true, started);
        },
        error: (error: unknown) => {
          const statusCode =
            error instanceof HttpException ? error.getStatus() : 500;
          void this.record(request, statusCode, false, started);
        },
      }),
    );
  }

  private async record(
    request: RequestShape,
    statusCode: number,
    success: boolean,
    started: number,
  ) {
    try {
      const rawAgent = request.headers['user-agent'];
      await this.events.save(
        this.events.create({
          userId: request.user?.userId ?? null,
          username: request.user?.username ?? null,
          method: request.method,
          path: request.originalUrl.split('?')[0].slice(0, 300),
          statusCode,
          success,
          ipAddress: request.ip?.slice(0, 80) ?? null,
          userAgent:
            (Array.isArray(rawAgent) ? rawAgent[0] : rawAgent)?.slice(0, 500) ??
            null,
          details: {
            durationMs: Date.now() - started,
            body: sanitize(request.body),
            params: sanitize(request.params),
            query: sanitize(request.query),
          },
        }),
      );
    } catch (error) {
      // Audit persistence must never turn a successful financial transaction into a 500.
      console.error('Failed to persist audit event', error);
    }
  }
}
