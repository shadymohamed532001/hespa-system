import { Injectable, NestMiddleware } from '@nestjs/common';
import type { NextFunction, Request, Response } from 'express';
import { resolveLocale, runWithLocale } from './locale-context.js';

@Injectable()
export class LocaleMiddleware implements NestMiddleware {
  use(req: Request, _res: Response, next: NextFunction) {
    const header =
      req.header('x-app-locale') ??
      req.header('accept-language') ??
      undefined;
    runWithLocale(resolveLocale(header), () => next());
  }
}
