import {
  addDays,
  isoWeekday,
  materializeShift,
} from '../../../../lib/attendance/shift-materialization';
import { requireMemberContext } from '../../../../lib/auth/require-member';
import { createSupabasePrivilegedServerClient } from '../../../../lib/supabase/admin';

export const runtime = 'nodejs';

type Command =
  | { action: 'save_policy'; allow_web_office_attendance: boolean; organization_id: string }
  | { action: 'save_office'; name: string; organization_id: string; timezone: string }
  | {
      action: 'save_network';
      bssid: string;
      office_id: string;
      organization_id: string;
      ssid_label: string;
    }
  | {
      action: 'save_ip_range';
      ip_range: string;
      note?: string;
      office_id: string;
      organization_id: string;
    }
  | {
      action: 'save_shift_template';
      allowed_mode: 'office' | 'remote' | 'hybrid';
      break_end?: string;
      break_start?: string;
      end_local: string;
      name: string;
      office_id: string | null;
      organization_id: string;
      start_local: string;
    }
  | {
      action: 'assign_shift';
      effective_from: string;
      member_id: string;
      organization_id: string;
      shift_template_id: string;
      weekdays: number[];
    };

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const timePattern = /^([01]\d|2[0-3]):[0-5]\d$/;
const datePattern = /^\d{4}-\d{2}-\d{2}$/;

function record(value: unknown): Record<string, unknown> | null {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

function string(value: unknown, maxLength: number, required = true) {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  if ((required && !trimmed) || trimmed.length > maxLength) return null;
  return trimmed;
}

function uuid(value: unknown) {
  const parsed = string(value, 36);
  return parsed && uuidPattern.test(parsed) ? parsed : null;
}

function time(value: unknown) {
  const parsed = string(value, 5);
  return parsed && timePattern.test(parsed) ? parsed : null;
}

function optionalTime(value: unknown) {
  if (value === undefined || value === null || value === '') return undefined;
  return time(value) ?? null;
}

function parseCommand(value: unknown): Command | null {
  const input = record(value);
  const action = typeof input?.action === 'string' ? input.action : null;
  const organizationId = uuid(input?.organization_id);
  if (!input || !action || !organizationId) return null;

  if (action === 'save_policy' && typeof input.allow_web_office_attendance === 'boolean') {
    return {
      action,
      allow_web_office_attendance: input.allow_web_office_attendance,
      organization_id: organizationId,
    };
  }
  if (action === 'save_office') {
    const name = string(input.name, 160);
    const timezone = string(input.timezone, 80);
    return name && timezone ? { action, name, organization_id: organizationId, timezone } : null;
  }
  if (action === 'save_network') {
    const officeId = uuid(input.office_id);
    const ssidLabel = string(input.ssid_label, 160);
    const bssid = string(input.bssid, 17)?.toLowerCase();
    return officeId && ssidLabel && bssid && /^[0-9a-f]{2}(:[0-9a-f]{2}){5}$/.test(bssid)
      ? {
          action,
          bssid,
          office_id: officeId,
          organization_id: organizationId,
          ssid_label: ssidLabel,
        }
      : null;
  }
  if (action === 'save_ip_range') {
    const officeId = uuid(input.office_id);
    const ipRange = string(input.ip_range, 64);
    const note = string(input.note, 500, false) ?? undefined;
    return officeId && ipRange && /^[0-9a-fA-F:.]+\/\d{1,3}$/.test(ipRange)
      ? { action, ip_range: ipRange, note, office_id: officeId, organization_id: organizationId }
      : null;
  }
  if (action === 'save_shift_template') {
    const name = string(input.name, 160);
    const startLocal = time(input.start_local);
    const endLocal = time(input.end_local);
    const breakStart = optionalTime(input.break_start);
    const breakEnd = optionalTime(input.break_end);
    const officeId =
      input.office_id === null || input.office_id === '' ? null : uuid(input.office_id);
    const allowedMode = input.allowed_mode;
    if (
      !name ||
      !startLocal ||
      !endLocal ||
      breakStart === null ||
      breakEnd === null ||
      (officeId === null && input.office_id !== null && input.office_id !== '') ||
      !['office', 'remote', 'hybrid'].includes(String(allowedMode))
    ) {
      return null;
    }
    return {
      action,
      allowed_mode: allowedMode as 'office' | 'remote' | 'hybrid',
      break_end: breakEnd,
      break_start: breakStart,
      end_local: endLocal,
      name,
      office_id: officeId,
      organization_id: organizationId,
      start_local: startLocal,
    };
  }
  if (action === 'assign_shift') {
    const memberId = uuid(input.member_id);
    const templateId = uuid(input.shift_template_id);
    const effectiveFrom = string(input.effective_from, 10);
    const weekdays =
      Array.isArray(input.weekdays) && input.weekdays.length > 0 && input.weekdays.length <= 7
        ? input.weekdays.filter(
            (day): day is number => Number.isInteger(day) && day >= 1 && day <= 7,
          )
        : [];
    return memberId &&
      templateId &&
      effectiveFrom &&
      datePattern.test(effectiveFrom) &&
      weekdays.length > 0
      ? {
          action,
          effective_from: effectiveFrom,
          member_id: memberId,
          organization_id: organizationId,
          shift_template_id: templateId,
          weekdays,
        }
      : null;
  }
  return null;
}

function failure(code: string, status: number) {
  return Response.json({ ok: false, error: { code } }, { status });
}

function isMissingP12(error: { code?: string; message?: string } | null) {
  return (
    error?.code === '42P01' ||
    error?.code === 'PGRST205' ||
    error?.message?.includes('attendance_settings')
  );
}

async function writeAudit(input: {
  action: string;
  actorMemberId: string;
  entityId?: string | null;
  entityType: string;
  metadata: Record<string, unknown>;
  organizationId: string;
}) {
  const admin = createSupabasePrivilegedServerClient();
  // Audit delivery is best-effort only after the protected write succeeds. A table
  // write failure is surfaced to operations without rolling back the setting itself.
  const { error } = await admin.from('audit_logs').insert({
    action: input.action,
    actor_kind: 'member',
    actor_member_id: input.actorMemberId,
    entity_id: input.entityId ?? null,
    entity_type: input.entityType,
    organization_id: input.organizationId,
    safe_metadata: input.metadata,
  });
  if (error) throw new Error('AUDIT_WRITE_FAILED');
}

function dateInTimezone(timezone: string) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    day: '2-digit',
    month: '2-digit',
    timeZone: timezone,
    year: 'numeric',
  }).formatToParts(new Date());
  const value = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${value.year}-${value.month}-${value.day}`;
}

export async function POST(request: Request) {
  const origin = request.headers.get('origin');
  if (origin && origin !== new URL(request.url).origin) return failure('ORIGIN_NOT_ALLOWED', 403);

  const command = parseCommand(await request.json().catch(() => null));
  if (!command) return failure('VALIDATION_ERROR', 400);

  let context;
  try {
    context = await requireMemberContext(command.organization_id);
  } catch {
    return failure('AUTHENTICATION_OR_MEMBERSHIP_REQUIRED', 401);
  }
  if (context.role !== 'admin' && !context.capabilities.includes('can_manage_attendance')) {
    return failure('ATTENDANCE_ADMIN_REQUIRED', 403);
  }

  const admin = createSupabasePrivilegedServerClient();
  const baseAudit = {
    actorMemberId: context.member_id,
    organizationId: context.organization_id,
  };

  try {
    if (command.action === 'save_policy') {
      const { error } = await admin.from('attendance_settings').upsert(
        {
          allow_web_office_attendance: command.allow_web_office_attendance,
          organization_id: context.organization_id,
          remote_photo_required: true,
          updated_by_member_id: context.member_id,
          version: 1,
        },
        { onConflict: 'organization_id' },
      );
      if (isMissingP12(error)) return failure('ATTENDANCE_SETTINGS_MIGRATION_REQUIRED', 409);
      if (error) return failure('ATTENDANCE_POLICY_SAVE_FAILED', 422);
      await writeAudit({
        ...baseAudit,
        action: 'attendance.settings.saved',
        entityType: 'attendance_settings',
        metadata: { allow_web_office_attendance: command.allow_web_office_attendance },
      });
      return Response.json({ ok: true });
    }

    if (command.action === 'save_office') {
      const { data, error } = await admin
        .from('offices')
        .upsert(
          {
            active: true,
            name: command.name,
            organization_id: context.organization_id,
            timezone: command.timezone,
          },
          { onConflict: 'organization_id,name' },
        )
        .select('id,name,timezone')
        .single();
      if (error || !data) return failure('OFFICE_SAVE_FAILED', 422);
      await writeAudit({
        ...baseAudit,
        action: 'attendance.office.saved',
        entityId: data.id,
        entityType: 'office',
        metadata: { name: data.name, timezone: data.timezone },
      });
      return Response.json({ ok: true, data });
    }

    if (command.action === 'save_network') {
      const { data, error } = await admin
        .from('office_networks')
        .insert({
          bssid: command.bssid,
          office_id: command.office_id,
          organization_id: context.organization_id,
          ssid_label: command.ssid_label,
        })
        .select('id')
        .single();
      if (error || !data) return failure('OFFICE_NETWORK_SAVE_FAILED', 422);
      await writeAudit({
        ...baseAudit,
        action: 'attendance.office_network.saved',
        entityId: data.id,
        entityType: 'office_network',
        metadata: { office_id: command.office_id, ssid_label: command.ssid_label },
      });
      return Response.json({ ok: true, data });
    }

    if (command.action === 'save_ip_range') {
      const { data, error } = await admin
        .from('office_ip_ranges')
        .insert({
          ip_range: command.ip_range,
          note: command.note || null,
          office_id: command.office_id,
          organization_id: context.organization_id,
        })
        .select('id')
        .single();
      if (error || !data) return failure('OFFICE_IP_RANGE_SAVE_FAILED', 422);
      await writeAudit({
        ...baseAudit,
        action: 'attendance.office_ip_range.saved',
        entityId: data.id,
        entityType: 'office_ip_range',
        metadata: { office_id: command.office_id, ip_range: command.ip_range },
      });
      return Response.json({ ok: true, data });
    }

    if (command.action === 'save_shift_template') {
      const startMinutes =
        Number(command.start_local.slice(0, 2)) * 60 + Number(command.start_local.slice(3));
      const endMinutes =
        Number(command.end_local.slice(0, 2)) * 60 + Number(command.end_local.slice(3));
      if (endMinutes <= startMinutes) return failure('SHIFT_OVERNIGHT_NOT_SUPPORTED', 422);
      if (command.allowed_mode === 'office' && !command.office_id) {
        return failure('SHIFT_OFFICE_REQUIRED', 422);
      }
      const hasBothBreakTimes = Boolean(command.break_start && command.break_end);
      if (Boolean(command.break_start) !== Boolean(command.break_end)) {
        return failure('SHIFT_BREAK_INCOMPLETE', 422);
      }
      const breaks = hasBothBreakTimes
        ? [{ end: command.break_end!, start: command.break_start! }]
        : [];
      const breakMinutes = hasBothBreakTimes
        ? Number(command.break_end!.slice(0, 2)) * 60 +
          Number(command.break_end!.slice(3)) -
          (Number(command.break_start!.slice(0, 2)) * 60 + Number(command.break_start!.slice(3)))
        : 0;
      if (breakMinutes < 0 || breakMinutes >= endMinutes - startMinutes) {
        return failure('SHIFT_BREAK_INVALID', 422);
      }
      const { data, error } = await admin
        .from('shift_templates')
        .insert({
          allowed_mode: command.allowed_mode,
          breaks,
          end_day_offset: 0,
          end_local: command.end_local,
          name: command.name,
          office_id: command.office_id,
          organization_id: context.organization_id,
          standard_day_minutes: endMinutes - startMinutes - breakMinutes,
          start_local: command.start_local,
        })
        .select('id,name')
        .single();
      if (error || !data) return failure('SHIFT_TEMPLATE_SAVE_FAILED', 422);
      await writeAudit({
        ...baseAudit,
        action: 'attendance.shift_template.saved',
        entityId: data.id,
        entityType: 'shift_template',
        metadata: { allowed_mode: command.allowed_mode, name: data.name },
      });
      return Response.json({ ok: true, data });
    }

    const { data: template, error: templateError } = await admin
      .from('shift_templates')
      .select(
        'id,office_id,name,start_local,end_local,breaks,allowed_mode,standard_day_minutes,version',
      )
      .eq('organization_id', context.organization_id)
      .eq('id', command.shift_template_id)
      .eq('active', true)
      .single();
    const { data: member, error: memberError } = await admin
      .from('organization_members')
      .select('id')
      .eq('organization_id', context.organization_id)
      .eq('id', command.member_id)
      .eq('status', 'active')
      .single();
    if (templateError || !template || memberError || !member) {
      return failure('SHIFT_ASSIGNMENT_TARGET_INVALID', 422);
    }
    const { error: assignmentError } = await admin.from('shift_assignments').insert({
      effective_from: command.effective_from,
      member_id: member.id,
      organization_id: context.organization_id,
      shift_template_id: template.id,
      weekdays: [...new Set(command.weekdays)].sort((left, right) => left - right),
    });
    if (assignmentError) return failure('SHIFT_ASSIGNMENT_SAVE_FAILED', 422);

    const today = dateInTimezone(context.timezone);
    const fromDate = command.effective_from > today ? command.effective_from : today;
    const candidateDates = Array.from({ length: 91 }, (_, index) =>
      addDays(fromDate, index),
    ).filter((date) => command.weekdays.includes(isoWeekday(date)));
    const { data: existing, error: existingError } = await admin
      .from('shift_instances')
      .select('work_date')
      .eq('organization_id', context.organization_id)
      .eq('member_id', member.id)
      .in('work_date', candidateDates);
    if (existingError) return failure('SHIFT_MATERIALIZATION_LOOKUP_FAILED', 503);
    const existingDates = new Set((existing ?? []).map((row) => row.work_date));
    let officeTimezone = context.timezone;
    if (template.office_id) {
      const { data: office, error: officeError } = await admin
        .from('offices')
        .select('timezone')
        .eq('organization_id', context.organization_id)
        .eq('id', template.office_id)
        .single();
      if (officeError || !office) return failure('SHIFT_OFFICE_INVALID', 422);
      officeTimezone = office.timezone;
    }
    const rows = candidateDates
      .filter((date) => !existingDates.has(date))
      .map((date) =>
        materializeShift({
          date,
          memberId: member.id,
          organizationId: context.organization_id,
          template: {
            allowedMode: template.allowed_mode,
            breaks: Array.isArray(template.breaks)
              ? (template.breaks as Array<{ end: string; start: string }>)
              : [],
            endLocal: template.end_local,
            officeId: template.office_id,
            standardDayMinutes: template.standard_day_minutes,
            startLocal: template.start_local,
            templateId: template.id,
            templateVersion: template.version,
          },
          timezone: officeTimezone,
        }),
      );
    if (rows.length > 0) {
      const { error: insertError } = await admin.from('shift_instances').insert(rows);
      if (insertError) return failure('SHIFT_MATERIALIZATION_FAILED', 422);
    }
    await writeAudit({
      ...baseAudit,
      action: 'attendance.shift_assigned',
      entityId: template.id,
      entityType: 'shift_template',
      metadata: {
        generated_instances: rows.length,
        member_id: member.id,
        weekdays: command.weekdays,
      },
    });
    return Response.json({ ok: true, data: { generated_instances: rows.length } });
  } catch {
    return failure('ATTENDANCE_SETTINGS_SERVER_ERROR', 503);
  }
}
