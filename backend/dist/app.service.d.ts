import { DataSource } from 'typeorm';
export declare class AppService {
    private readonly dataSource?;
    constructor(dataSource?: DataSource | undefined);
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
