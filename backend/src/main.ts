import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestExpressApplication } from '@nestjs/platform-express';
import helmet from 'helmet';
import { AppModule } from './app.module.js';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  const config = app.get(ConfigService);
  const production = config.get('NODE_ENV', 'development') === 'production';
  const rawTrustProxy = config.get<string | boolean>('TRUST_PROXY');
  const trustProxy =
    rawTrustProxy === undefined
      ? production
        ? 1
        : false
      : rawTrustProxy === true || rawTrustProxy === 'true'
        ? true
        : rawTrustProxy === false || rawTrustProxy === 'false'
          ? false
          : /^\d+$/.test(String(rawTrustProxy))
            ? Number(rawTrustProxy)
            : rawTrustProxy;

  app.disable('x-powered-by');
  app.set('trust proxy', trustProxy);
  app.use(helmet());
  app.setGlobalPrefix('api');
  const allowedOrigins = config
    .get<string>('CORS_ORIGINS', '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);
  app.enableCors({
    origin: (origin, callback) => {
      if (!origin || allowedOrigins.includes(origin))
        return callback(null, true);
      return callback(null, false);
    },
    credentials: false,
    methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: [
      'Authorization',
      'Content-Type',
      'Idempotency-Key',
      'Accept-Language',
      'X-App-Locale',
    ],
    maxAge: 600,
  });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      stopAtFirstError: false,
    }),
  );
  await app.listen(
    Number(config.get('PORT', 3000)),
    config.get<string>('HOST', production ? '127.0.0.1' : '0.0.0.0'),
  );
}
await bootstrap();
