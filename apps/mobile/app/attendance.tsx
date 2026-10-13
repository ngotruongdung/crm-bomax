import type { AttendanceDay, OrganizationContext } from '@opsdesk/contracts';
import { colors, controls, layout, radii, spacing, typography } from '@opsdesk/design-tokens';
import type { Href } from 'expo-router';
import { useRouter } from 'expo-router';
import { useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator,
  Platform,
  Pressable,
  RefreshControl,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import {
  attendanceDiagnosticFromError,
  attendanceDiagnosticFromWifi,
  type AttendanceDiagnostic,
} from '../lib/attendance/attendance-diagnostics';
import {
  createAttendanceChallenge,
  finalizeOfficeAttendance,
  loadAttendanceDay,
  registerAttendanceDevice,
} from '../lib/attendance/attendance-api';
import {
  openOfficeWifiPermissionSettingsNative,
  readCurrentOfficeWifiNative,
} from '../lib/attendance/office-wifi';
import { getMobileContextErrorMessage, loadMobileMemberContext } from '../lib/member-context';
import { revokeCurrentMobileDevice } from '../lib/notifications/push-registration';
import { createSupabaseMobileClient } from '../lib/supabase';

function organizationDate(timezone: string) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
}

function formatTime(value: string | null | undefined) {
  if (!value) return '—';
  return new Date(value).toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit' });
}

function allowedModeLabel(mode: 'office' | 'remote' | 'hybrid') {
  if (mode === 'office') return 'Tại văn phòng';
  if (mode === 'remote') return 'Online';
  return 'Linh hoạt';
}

export default function AttendanceScreen() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const [context, setContext] = useState<OrganizationContext | null>(null);
  const [day, setDay] = useState<AttendanceDay | null>(null);
  const [deviceId, setDeviceId] = useState<string | null>(null);
  const [diagnostic, setDiagnostic] = useState<AttendanceDiagnostic | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    let active = true;

    async function prepare() {
      try {
        const nextContext = await loadMobileMemberContext();
        const workDate = organizationDate(nextContext.timezone);
        const platform =
          Platform.OS === 'ios' ? 'ios' : Platform.OS === 'android' ? 'android' : null;
        const [nextDay, device] = await Promise.all([
          loadAttendanceDay(nextContext.organization_id, workDate),
          platform
            ? registerAttendanceDevice(nextContext.organization_id, platform)
            : Promise.resolve(null),
        ]);
        if (!active) return;
        setContext(nextContext);
        setDay(nextDay);
        setDeviceId(device?.device_id ?? null);
        if (!nextDay.shift) {
          setDiagnostic(attendanceDiagnosticFromError(new Error('NO_SCHEDULED_SHIFT')));
        } else if (!platform) {
          setDiagnostic(attendanceDiagnosticFromError(new Error('NATIVE_WIFI_UNAVAILABLE_ON_WEB')));
        }
      } catch (error) {
        if (!active) return;
        const message =
          error instanceof Error && error.message.startsWith('MOBILE_')
            ? getMobileContextErrorMessage(error)
            : null;
        setDiagnostic(
          message
            ? {
                code: 'MOBILE_CONTEXT_ERROR',
                title: 'Không thể mở chấm công',
                description: message,
                action: 'Đăng nhập lại',
              }
            : attendanceDiagnosticFromError(error),
        );
      } finally {
        if (active) setLoading(false);
      }
    }

    void prepare();
    return () => {
      active = false;
    };
  }, []);

  const openSession = useMemo(
    () => day?.sessions.find((session) => session.status === 'open') ?? null,
    [day],
  );
  const nextAction = openSession ? 'check_out' : 'check_in';
  const officeAllowed = Boolean(
    day?.shift && ['office', 'hybrid'].includes(day.shift.allowed_mode),
  );
  const remoteAllowed = Boolean(
    day?.shift && ['remote', 'hybrid'].includes(day.shift.allowed_mode),
  );
  const isNative = Platform.OS === 'ios' || Platform.OS === 'android';

  async function refreshDay(showSpinner = true) {
    if (!context) return;
    if (showSpinner) setRefreshing(true);
    try {
      const nextDay = await loadAttendanceDay(
        context.organization_id,
        organizationDate(context.timezone),
      );
      setDay(nextDay);
      if (!nextDay.shift) {
        setDiagnostic(attendanceDiagnosticFromError(new Error('NO_SCHEDULED_SHIFT')));
      } else {
        setDiagnostic(null);
      }
    } catch (error) {
      setDiagnostic(attendanceDiagnosticFromError(error));
    } finally {
      if (showSpinner) setRefreshing(false);
    }
  }

  async function handleOfficeAttendance() {
    if (busy) return;
    setSuccessMessage(null);

    if (!isNative) {
      setDiagnostic(attendanceDiagnosticFromError(new Error('NATIVE_WIFI_UNAVAILABLE_ON_WEB')));
      return;
    }
    if (!context || !day?.shift) {
      setDiagnostic(attendanceDiagnosticFromError(new Error('NO_SCHEDULED_SHIFT')));
      return;
    }
    if (!officeAllowed) {
      setDiagnostic({
        code: 'OFFICE_NOT_ALLOWED',
        title: 'Ca này không chấm tại văn phòng',
        description: 'Ca hiện tại chỉ cho phép chấm công online theo lịch đã được duyệt.',
        action: 'Dùng chấm công online',
      });
      return;
    }
    if (!deviceId) {
      setDiagnostic(attendanceDiagnosticFromError(new Error('DEVICE_MISMATCH')));
      return;
    }

    setBusy(true);
    setDiagnostic(null);
    try {
      const wifi = await readCurrentOfficeWifiNative();
      if (wifi.status !== 'available') {
        setDiagnostic(attendanceDiagnosticFromWifi(wifi));
        return;
      }

      const challenge = await createAttendanceChallenge({
        organizationId: context.organization_id,
        shiftInstanceId: day.shift.id,
        action: nextAction,
        mode: 'office',
        deviceId,
      });
      if (
        !challenge.requirements.wifi_required ||
        !challenge.requirements.trusted_network_required
      ) {
        throw new Error('ATTENDANCE_POLICY_MISMATCH');
      }

      const commit = await finalizeOfficeAttendance({
        challengeId: challenge.challenge_id,
        nonce: challenge.nonce,
        deviceId,
        wifi,
      });
      setSuccessMessage(
        commit.duplicate
          ? `Yêu cầu đã được ghi nhận trước đó lúc ${formatTime(commit.recorded_at)}.`
          : `Đã ${commit.event_kind === 'check_in' ? 'chấm vào' : 'chấm ra'} lúc ${formatTime(commit.recorded_at)} theo giờ máy chủ.`,
      );
      await refreshDay(false);
    } catch (error) {
      setDiagnostic(attendanceDiagnosticFromError(error));
    } finally {
      setBusy(false);
    }
  }

  function handleRemoteAttendance() {
    setSuccessMessage(null);
    if (!day?.shift) {
      setDiagnostic(attendanceDiagnosticFromError(new Error('NO_SCHEDULED_SHIFT')));
      return;
    }
    if (!remoteAllowed) {
      setDiagnostic(attendanceDiagnosticFromError(new Error('REMOTE_NOT_APPROVED')));
      return;
    }
    if (!isNative) {
      setDiagnostic(
        attendanceDiagnosticFromError(new Error('REMOTE_ATTENDANCE_REQUIRES_NATIVE_APP')),
      );
      return;
    }
    router.push('/attendance-remote' as Href);
  }

  async function handleSignOut() {
    try {
      try {
        await revokeCurrentMobileDevice();
      } catch {
        // Push-device cleanup must not prevent account sign-out.
      }
      await createSupabaseMobileClient().auth.signOut();
    } finally {
      router.replace('/');
    }
  }

  if (loading) {
    return (
      <View style={styles.loading}>
        <ActivityIndicator color={colors.accent} />
      </View>
    );
  }

  const recentEvents = [...(day?.events ?? [])]
    .sort((a, b) => Date.parse(b.effective_at) - Date.parse(a.effective_at))
    .slice(0, 4);

  return (
    <View style={styles.root}>
      <ScrollView
        contentContainerStyle={[
          styles.container,
          {
            paddingTop: insets.top + layout.mobileWorkspacePadding,
            paddingBottom: insets.bottom + 118,
          },
        ]}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={() => void refreshDay(true)} />
        }
      >
        <View style={styles.topBar}>
          <View style={styles.brandRow}>
            <View style={styles.brandMark}>
              <Text style={styles.brandMarkText}>O</Text>
            </View>
            <Text style={styles.brandName}>OpsDesk</Text>
          </View>
          <Pressable accessibilityRole="button" onPress={() => void handleSignOut()}>
            <Text style={styles.signOut}>Đăng xuất</Text>
          </Pressable>
        </View>

        <Text style={styles.eyebrow}>ATTENDANCE · NATIVE VERIFY</Text>
        <Text style={styles.title}>Chấm công</Text>
        <Text style={styles.subtitle}>
          {context ? `${context.organization_name} · ${context.display_name}` : 'Phiên làm việc'}
        </Text>

        <View style={styles.summaryGrid}>
          <View style={styles.summaryCard}>
            <Text style={styles.summaryLabel}>Trạng thái</Text>
            <Text style={styles.summaryValue}>{openSession ? 'Đang trong ca' : 'Chưa vào ca'}</Text>
            <Text style={styles.summaryMeta}>
              {openSession
                ? `Vào lúc ${formatTime(openSession.starts_at)}`
                : 'Chờ xác minh từ máy chủ'}
            </Text>
          </View>
          <View style={styles.summaryCard}>
            <Text style={styles.summaryLabel}>Ca hôm nay</Text>
            <Text style={styles.summaryValue}>
              {day?.shift
                ? `${formatTime(day.shift.starts_at)} – ${formatTime(day.shift.ends_at)}`
                : 'Chưa có ca'}
            </Text>
            <Text style={styles.summaryMeta}>
              {day?.shift ? allowedModeLabel(day.shift.allowed_mode) : 'Không tự tạo giờ công'}
            </Text>
          </View>
        </View>

        <View style={styles.actionCard}>
          <View style={styles.sectionHeadingRow}>
            <View>
              <Text style={styles.sectionEyebrow}>XÁC THỰC THỜI GIAN THỰC</Text>
              <Text style={styles.sectionTitle}>
                {nextAction === 'check_in' ? 'Chấm vào ca' : 'Chấm ra ca'}
              </Text>
            </View>
            <Text style={styles.serverTime}>Server {formatTime(day?.server_now)}</Text>
          </View>

          <Pressable
            accessibilityRole="button"
            disabled={busy || !day?.shift}
            onPress={() => void handleOfficeAttendance()}
            style={busy || !day?.shift ? styles.disabledButton : styles.primaryButton}
          >
            <Text style={busy || !day?.shift ? styles.disabledText : styles.primaryText}>
              {busy
                ? 'Đang xác thực...'
                : nextAction === 'check_in'
                  ? 'Chấm vào tại văn phòng'
                  : 'Chấm ra tại văn phòng'}
            </Text>
          </Pressable>
          <Text style={styles.actionHint}>
            Ứng dụng native đọc SSID/BSSID, máy chủ kiểm tra BSSID và public IP trước khi ghi nhận.
          </Text>

          <Pressable
            accessibilityRole="button"
            disabled={busy || !day?.shift}
            onPress={handleRemoteAttendance}
            style={busy || !day?.shift ? styles.disabledButton : styles.secondaryButton}
          >
            <Text style={busy || !day?.shift ? styles.disabledText : styles.secondaryText}>
              {nextAction === 'check_in' ? 'Chấm vào online' : 'Chấm ra online'}
            </Text>
          </Pressable>
          <Text style={styles.actionHint}>
            Online yêu cầu ca được phép remote và ảnh chụp trực tiếp bằng camera điện thoại.
          </Text>
        </View>

        {successMessage ? (
          <View style={styles.successCard}>
            <Text style={styles.successTitle}>Đã xác nhận</Text>
            <Text style={styles.successBody}>{successMessage}</Text>
          </View>
        ) : null}

        {diagnostic ? (
          <View style={styles.diagnosticCard}>
            <Text style={styles.diagnosticCode}>{diagnostic.code}</Text>
            <Text style={styles.diagnosticTitle}>{diagnostic.title}</Text>
            <Text style={styles.diagnosticBody}>{diagnostic.description}</Text>
            {diagnostic.canOpenSettings ? (
              <Pressable
                accessibilityRole="button"
                onPress={() => void openOfficeWifiPermissionSettingsNative()}
                style={styles.diagnosticAction}
              >
                <Text style={styles.diagnosticActionText}>{diagnostic.action ?? 'Mở cài đặt'}</Text>
              </Pressable>
            ) : diagnostic.action ? (
              <Text style={styles.diagnosticAdvice}>{diagnostic.action}</Text>
            ) : null}
          </View>
        ) : null}

        <View style={styles.historyCard}>
          <View style={styles.sectionHeadingRow}>
            <View>
              <Text style={styles.sectionEyebrow}>NHẬT KÝ HÔM NAY</Text>
              <Text style={styles.sectionTitle}>Lịch sử xác nhận</Text>
            </View>
            <Text style={styles.historyCount}>{day?.events.length ?? 0} sự kiện</Text>
          </View>
          {recentEvents.length === 0 ? (
            <Text style={styles.emptyHistory}>
              Chưa có sự kiện chấm công được máy chủ ghi nhận.
            </Text>
          ) : (
            recentEvents.map((event) => (
              <View key={event.id} style={styles.historyRow}>
                <View>
                  <Text style={styles.historyTitle}>
                    {event.event_kind === 'check_in'
                      ? 'Chấm vào'
                      : event.event_kind === 'check_out'
                        ? 'Chấm ra'
                        : 'Điều chỉnh'}
                  </Text>
                  <Text style={styles.historyMeta}>
                    {event.mode === 'office'
                      ? 'Văn phòng'
                      : event.mode === 'remote'
                        ? 'Online'
                        : 'Điều chỉnh được duyệt'}
                  </Text>
                </View>
                <Text style={styles.historyTime}>{formatTime(event.effective_at)}</Text>
              </View>
            ))
          )}
        </View>
      </ScrollView>

      <View style={[styles.bottomNavigation, { bottom: insets.bottom + layout.mobileBottomInset }]}>
        <Pressable
          accessibilityRole="button"
          onPress={() => router.replace('/today')}
          style={styles.navItem}
        >
          <Text style={styles.navItemText}>Hôm nay</Text>
        </Pressable>
        <Pressable accessibilityRole="button" style={[styles.navItem, styles.navItemActive]}>
          <Text style={[styles.navItemText, styles.navItemTextActive]}>Chấm công</Text>
        </Pressable>
        <Pressable
          accessibilityRole="button"
          onPress={() => router.replace('/overview')}
          style={styles.navItem}
        >
          <Text style={styles.navItemText}>Tổng quan</Text>
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { backgroundColor: colors.canvas, flex: 1 },
  loading: {
    alignItems: 'center',
    backgroundColor: colors.canvas,
    flex: 1,
    justifyContent: 'center',
  },
  container: {
    gap: spacing.md,
    paddingHorizontal: layout.mobileWorkspacePadding,
  },
  topBar: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 18,
  },
  brandRow: { alignItems: 'center', flexDirection: 'row', gap: spacing.sm },
  brandMark: {
    alignItems: 'center',
    backgroundColor: colors.primary,
    borderRadius: radii.compact,
    height: 30,
    justifyContent: 'center',
    width: 30,
  },
  brandMarkText: {
    color: colors.surface,
    fontSize: typography.fontSize.body,
    fontWeight: typography.fontWeight.bold,
  },
  brandName: {
    color: colors.textPrimary,
    fontSize: typography.fontSize.bodyLarge,
    fontWeight: typography.fontWeight.bold,
  },
  signOut: {
    color: colors.accent,
    fontSize: typography.fontSize.label,
    fontWeight: typography.fontWeight.semibold,
  },
  eyebrow: {
    color: colors.accent,
    fontSize: typography.fontSize.caption,
    fontWeight: typography.fontWeight.bold,
    letterSpacing: 0.8,
  },
  title: {
    color: colors.textPrimary,
    fontSize: typography.fontSize.title,
    fontWeight: typography.fontWeight.bold,
  },
  subtitle: {
    color: colors.textSecondary,
    fontSize: typography.fontSize.body,
    lineHeight: typography.lineHeight.body,
  },
  summaryGrid: { flexDirection: 'row', gap: spacing.sm },
  summaryCard: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: radii.lg,
    borderWidth: 1,
    flex: 1,
    minHeight: 120,
    padding: 15,
  },
  summaryLabel: {
    color: colors.textMuted,
    fontSize: typography.fontSize.caption,
    fontWeight: typography.fontWeight.semibold,
  },
  summaryValue: {
    color: colors.textPrimary,
    fontSize: typography.fontSize.bodyLarge,
    fontWeight: typography.fontWeight.bold,
    marginTop: 10,
  },
  summaryMeta: {
    color: colors.textSecondary,
    fontSize: typography.fontSize.caption,
    lineHeight: 18,
    marginTop: 6,
  },
  actionCard: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: radii.lg,
    borderWidth: 1,
    gap: 12,
    marginTop: 2,
    padding: 16,
  },
  sectionHeadingRow: {
    alignItems: 'flex-start',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  sectionEyebrow: {
    color: colors.textMuted,
    fontSize: typography.fontSize.caption,
    fontWeight: typography.fontWeight.bold,
    letterSpacing: 0.7,
  },
  sectionTitle: {
    color: colors.textPrimary,
    fontSize: typography.fontSize.bodyLarge,
    fontWeight: typography.fontWeight.bold,
    marginTop: 5,
  },
  serverTime: {
    color: colors.textMuted,
    fontSize: typography.fontSize.caption,
    marginTop: 2,
  },
  primaryButton: {
    alignItems: 'center',
    backgroundColor: colors.primary,
    borderRadius: radii.md,
    justifyContent: 'center',
    minHeight: controls.mobileFieldHeight,
    marginTop: 4,
    paddingHorizontal: 14,
  },
  primaryText: {
    color: colors.surface,
    fontSize: typography.fontSize.body,
    fontWeight: typography.fontWeight.bold,
  },
  secondaryButton: {
    alignItems: 'center',
    backgroundColor: colors.surfaceInset,
    borderColor: colors.border,
    borderRadius: radii.md,
    borderWidth: 1,
    justifyContent: 'center',
    minHeight: controls.mobileFieldHeight,
    marginTop: 4,
    paddingHorizontal: 14,
  },
  secondaryText: {
    color: colors.textPrimary,
    fontSize: typography.fontSize.body,
    fontWeight: typography.fontWeight.bold,
  },
  disabledButton: {
    alignItems: 'center',
    backgroundColor: '#e7e9ed',
    borderRadius: radii.md,
    justifyContent: 'center',
    minHeight: controls.mobileFieldHeight,
    marginTop: 4,
    paddingHorizontal: 14,
  },
  disabledText: {
    color: colors.textMuted,
    fontSize: typography.fontSize.body,
    fontWeight: typography.fontWeight.bold,
  },
  actionHint: {
    color: colors.textMuted,
    fontSize: typography.fontSize.caption,
    lineHeight: 18,
  },
  successCard: {
    backgroundColor: colors.surfaceInset,
    borderColor: colors.border,
    borderRadius: radii.md,
    borderWidth: 1,
    padding: 14,
  },
  successTitle: {
    color: colors.textPrimary,
    fontSize: typography.fontSize.label,
    fontWeight: typography.fontWeight.bold,
  },
  successBody: {
    color: colors.textSecondary,
    fontSize: typography.fontSize.label,
    lineHeight: typography.lineHeight.body,
    marginTop: 5,
  },
  diagnosticCard: {
    backgroundColor: colors.surfaceInset,
    borderColor: colors.border,
    borderRadius: radii.lg,
    borderWidth: 1,
    padding: 16,
  },
  diagnosticCode: {
    color: colors.accent,
    fontSize: typography.fontSize.caption,
    fontWeight: typography.fontWeight.bold,
    letterSpacing: 0.6,
  },
  diagnosticTitle: {
    color: colors.textPrimary,
    fontSize: typography.fontSize.bodyLarge,
    fontWeight: typography.fontWeight.bold,
    marginTop: 7,
  },
  diagnosticBody: {
    color: colors.textSecondary,
    fontSize: typography.fontSize.label,
    lineHeight: typography.lineHeight.body,
    marginTop: 7,
  },
  diagnosticAction: {
    alignItems: 'center',
    alignSelf: 'flex-start',
    borderColor: colors.border,
    borderRadius: radii.md,
    borderWidth: 1,
    justifyContent: 'center',
    marginTop: 12,
    minHeight: controls.mobileTouchTarget,
    paddingHorizontal: 14,
  },
  diagnosticActionText: {
    color: colors.textPrimary,
    fontSize: typography.fontSize.label,
    fontWeight: typography.fontWeight.semibold,
  },
  diagnosticAdvice: {
    color: colors.accent,
    fontSize: typography.fontSize.label,
    fontWeight: typography.fontWeight.semibold,
    marginTop: 10,
  },
  historyCard: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: radii.lg,
    borderWidth: 1,
    padding: 16,
  },
  historyCount: {
    color: colors.textMuted,
    fontSize: typography.fontSize.caption,
    marginTop: 2,
  },
  emptyHistory: {
    color: colors.textMuted,
    fontSize: typography.fontSize.label,
    lineHeight: typography.lineHeight.body,
    marginTop: 16,
  },
  historyRow: {
    alignItems: 'center',
    borderTopColor: colors.border,
    borderTopWidth: 1,
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 14,
    paddingTop: 14,
  },
  historyTitle: {
    color: colors.textPrimary,
    fontSize: typography.fontSize.label,
    fontWeight: typography.fontWeight.semibold,
  },
  historyMeta: {
    color: colors.textMuted,
    fontSize: typography.fontSize.caption,
    marginTop: 3,
  },
  historyTime: {
    color: colors.textPrimary,
    fontSize: typography.fontSize.body,
    fontWeight: typography.fontWeight.bold,
  },
  bottomNavigation: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: radii.lg,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 8,
    left: layout.mobileWorkspacePadding,
    padding: 6,
    position: 'absolute',
    right: layout.mobileWorkspacePadding,
  },
  navItem: {
    alignItems: 'center',
    borderRadius: radii.md,
    flex: 1,
    justifyContent: 'center',
    minHeight: controls.mobileTouchTarget,
  },
  navItemActive: { backgroundColor: '#edeef1' },
  navItemText: {
    color: colors.textMuted,
    fontSize: typography.fontSize.label,
    fontWeight: typography.fontWeight.semibold,
  },
  navItemTextActive: { color: colors.textPrimary },
});
