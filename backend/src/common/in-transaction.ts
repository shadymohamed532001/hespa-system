import { DataSource, EntityManager } from 'typeorm';

/** Reuse the correction transaction so reversal and replacement commit together. */
export function inTransaction(
  source: DataSource,
  manager: EntityManager | undefined,
  isolation?: 'SERIALIZABLE',
) {
  return <T>(work: (manager: EntityManager) => Promise<T>): Promise<T> =>
    manager
      ? work(manager)
      : isolation
        ? source.transaction(isolation, work)
        : source.transaction(work);
}
