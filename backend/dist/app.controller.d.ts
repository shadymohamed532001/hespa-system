import { AppService } from './app.service.js';
export declare class AppController {
    private readonly appService;
    constructor(appService: AppService);
    getHello(): string;
    health(): Promise<{
        status: string;
        database: string;
        latencyMs?: undefined;
        timestamp?: undefined;
    } | {
        status: string;
        database: string;
        latencyMs: number;
        timestamp: string;
    }>;
}
