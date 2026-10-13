import { describe, expect, it } from 'vitest';
import { createDemoNotifications } from '../lib/demo/notification-demo';
import { createDemoOrganizationContext } from '../lib/demo/opsdesk-demo';
import {
  isActionInboxItem,
  parseNotificationInboxTab,
} from '../app/notifications/notification-projections';

describe('Notification action inbox projections', () => {
  it('keeps only actionable task, HR and report updates in the action inbox', () => {
    const context = createDemoOrganizationContext('2026-10-13T03:00:00.000Z');
    const items = createDemoNotifications(context);

    expect(items.slice(0, 3).every(isActionInboxItem)).toBe(true);
    expect(isActionInboxItem(items[3]!)).toBe(false);
  });

  it('accepts only known URL tab values', () => {
    expect(parseNotificationInboxTab('tasks')).toBe('tasks');
    expect(parseNotificationInboxTab('system')).toBe('all');
    expect(parseNotificationInboxTab(null)).toBe('all');
  });
});
