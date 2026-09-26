import type { ValueTransformer } from 'typeorm';

export const decimalTransformer: ValueTransformer = {
  to: (value?: number) => value ?? 0,
  from: (value: string | number) => Number(value),
};

export const nullableDecimalTransformer: ValueTransformer = {
  to: (value?: number | null) => value ?? null,
  from: (value: string | number | null) =>
    value === null || value === undefined ? null : Number(value),
};
