import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import helmet from 'helmet';
import { AppModule } from './app.module.js';
async function bootstrap() {
    const app = await NestFactory.create(AppModule);
    const config = app.get(ConfigService);
    const production = config.get('NODE_ENV', 'development') === 'production';
    app.disable('x-powered-by');
    app.set('trust proxy', config.get('TRUST_PROXY', production ? 'loopback' : false));
    app.use(helmet());
    app.setGlobalPrefix('api');
    const allowedOrigins = config
        .get('CORS_ORIGINS', '')
        .split(',')
        .map((value) => value.trim())
        .filter(Boolean);
    app.enableCors({
        origin: (origin, callback) => {
            if (!origin || allowedOrigins.includes(origin))
                return callback(null, true);
            return callback(new Error('Origin is not allowed by CORS'), false);
        },
        credentials: false,
        methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
        allowedHeaders: ['Authorization', 'Content-Type', 'Idempotency-Key'],
        maxAge: 600,
    });
    app.useGlobalPipes(new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
        stopAtFirstError: false,
    }));
    await app.listen(Number(config.get('PORT', 3000)), config.get('HOST', production ? '127.0.0.1' : '0.0.0.0'));
}
await bootstrap();
//# sourceMappingURL=main.js.map