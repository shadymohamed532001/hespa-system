import type { ValueTransformer } from 'typeorm';

export const decimalTransformer: ValueTransformer = {
  to: (value?: number) => value ?? 0,
  from: (value: string | number) => Number(value),
};

