import { Injectable, Optional } from '@nestjs/common';
import { DataSource } from 'typeorm';

@Injectable()
export class AppService {
  constructor(@Optional() private readonly dataSource?: DataSource) {}

  getHello(): string {
    return 'Hesba API is running';
  }

  async health() {
    const startedAt = Date.now();
    if (!this.dataSource?.isInitialized) {
      return { status: 'degraded', database: 'unavailable' };
    }
    await this.dataSource.query('SELECT 1');
    return {
      status: 'ok',
      database: 'up',
      latencyMs: Date.now() - startedAt,
      timestamp: new Date().toISOString(),
    };
  }
}
