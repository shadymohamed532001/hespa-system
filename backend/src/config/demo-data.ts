import { ConfigService } from '@nestjs/config';

export function shouldSeedDemoData(config: ConfigService) {
  const production = config.get('NODE_ENV', 'development') === 'production';
  return config.get('SEED_DEMO_DATA', production ? 'false' : 'true') === 'true';
}
