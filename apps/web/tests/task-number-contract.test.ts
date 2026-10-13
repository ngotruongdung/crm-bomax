import { describe, expect, it } from 'vitest';
import { taskDetailSchema, taskListSchema } from '@opsdesk/contracts';
import {
  createDemoOrganizationContext,
  createDemoTaskDetail,
  createDemoTasks,
} from '../lib/demo/opsdesk-demo';

describe('task number contracts', () => {
  it('normalizes bigint values returned through Supabase JSON RPC responses', () => {
    const context = createDemoOrganizationContext('2026-10-05T12:00:00.000Z');
    const task = createDemoTasks(context).at(0);
    if (!task) throw new Error('Expected a demo task.');

    const detail = createDemoTaskDetail(task.id, context);
    if (!detail) throw new Error('Expected demo task detail.');

    expect(taskListSchema.parse([{ ...task, task_number: 990001 }]).at(0)?.task_number).toBe(
      '990001',
    );
    expect(taskDetailSchema.parse({ ...detail, task_number: 990001 }).task_number).toBe('990001');
  });
});
