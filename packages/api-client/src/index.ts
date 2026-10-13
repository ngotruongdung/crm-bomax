export type CommandResult<T> =
  | { ok: true; data: T; request_id: string }
  | {
      ok: false;
      error: { code: string; message: string; field_errors?: Record<string, string> };
      request_id: string;
    };

export const queryKeys = {
  today: (organizationId: string, memberId: string, date: string) =>
    ['today', organizationId, memberId, date] as const,
  tasks: (organizationId: string, filtersHash: string) =>
    ['tasks', organizationId, filtersHash] as const,
  task: (organizationId: string, taskId: string) => ['task', organizationId, taskId] as const,
} as const;

export type { Database, Json } from './database.types';
