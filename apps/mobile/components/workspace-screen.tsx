import type { AttendanceDay, OrganizationContext } from '@opsdesk/contracts';
import { colors, controls, layout, radii, spacing, typography } from '@opsdesk/design-tokens';
import type { Href } from 'expo-router';
import { useRouter } from 'expo-router';
import { useEffect, useState } from 'react';
import { ActivityIndicator, Platform, Pressable, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { getMobileContextErrorMessage, loadMobileMemberContext } from '../lib/member-context';
import { createSupabaseMobileClient } from '../lib/supabase';
import {
  registerMobilePush,
  revokeCurrentMobileDevice,
} from '../lib/notifications/push-registration';
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

type WorkspaceSection = 'overview' | 'today' | 'attendance';

type WorkspaceScreenProps = {
  section: WorkspaceSection;
};

export function WorkspaceScreen({ section }: WorkspaceScreenProps) {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const [context, setContext] = useState<OrganizationContext | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [attendanceDay, setAttendanceDay] = useState<AttendanceDay | null>(null);
  const [attendanceDeviceId, setAttendanceDeviceId] = useState<string | null>(null);
  const [attendanceMessage, setAttendanceMessage] = useState<string | null>(null);
  const [attendanceBusy, setAttendanceBusy] = useState(false);
  const safeContainerStyle = [
    styles.container,
    {
      paddingBottom: layout.mobileWorkspacePadding + insets.bottom,
      paddingTop: layout.mobileWorkspacePadding + insets.top,
    },
  ];

  useEffect(() => {
    let isMounted = true;

    async function loadContext() {
      try {
        const nextContext = await loadMobileMemberContext();

        if (!isMounted) {
          return;
        }

        if (section === 'overview' && nextContext.role === 'employee') {
          router.replace('/today');
          return;
        }

        setContext(nextContext);
      } catch (error) {
        if (isMounted) {
          setErrorMessage(getMobileContextErrorMessage(error));
        }
      } finally {
        if (isMounted) {
          setIsLoading(false);
        }
      }
    }

    void loadContext();

    return () => {
      isMounted = false;
    };
  }, [router, section]);

  useEffect(() => {
    if (section !== 'attendance' || !context) return;
    const attendanceContext = context;
    let active = true;

    async function loadAttendance() {
      try {
        const workDate = new Intl.DateTimeFormat('en-CA', {
          timeZone: attendanceContext.timezone,
          year: 'numeric',
          month: '2-digit',
          day: '2-digit',
        }).format(new Date());
        const platform =
          Platform.OS === 'ios' ? 'ios' : Platform.OS === 'android' ? 'android' : null;
        const [day, device] = await Promise.all([
          loadAttendanceDay(attendanceContext.organization_id, workDate),
          platform
            ? registerAttendanceDevice(attendanceContext.organization_id, platform)
            : Promise.resolve(null),
        ]);
        if (!active) return;
        setAttendanceDay(day);
        setAttendanceDeviceId(device?.device_id ?? null);
      } catch (error) {
        if (!active) return;
        setAttendanceMessage(error instanceof Error ? error.message : 'ATTENDANCE_LOAD_FAILED');
      }
    }

    void loadAttendance();
    return () => {
      active = false;
    };
  }, [context, section]);

  useEffect(() => {
    if (!context) return;
    const pushContext = context;
    let active = true;

    async function registerPush() {
      const outcome = await registerMobilePush(pushContext.organization_id);
      if (!active) return;
      if (outcome.status === 'unavailable') {
        console.warn(`[OpsDesk push] ${outcome.reason}`);
      }
    }

    void registerPush();
    return () => {
      active = false;
    };
  }, [context]);

  async function handleOfficeAttendance() {
    if (!context || !attendanceDay?.shift || !attendanceDeviceId || attendanceBusy) return;
    setAttendanceBusy(true);
    setAttendanceMessage(null);
    try {
      const openSession = attendanceDay.sessions.find((item) => item.status === 'open');
      const action = openSession ? 'check_out' : 'check_in';
      const challenge = await createAttendanceChallenge({
        organizationId: context.organization_id,
        shiftInstanceId: attendanceDay.shift.id,
        action,
        mode: 'office',
        deviceId: attendanceDeviceId,
      });
      const wifi = await readCurrentOfficeWifiNative();
      if (wifi.status !== 'available') {
        setAttendanceMessage(wifi.message ?? `WIFI_${wifi.status.toUpperCase()}`);
        return;
      }
      const commit = await finalizeOfficeAttendance({
        challengeId: challenge.challenge_id,
        nonce: challenge.nonce,
        deviceId: attendanceDeviceId,
        wifi,
      });
      setAttendanceMessage(
        commit.duplicate
          ? `Đã ghi nhận trước đó lúc ${new Date(commit.recorded_at).toLocaleTimeString('vi-VN')}`
          : `Đã ${commit.event_kind === 'check_in' ? 'chấm vào' : 'chấm ra'} lúc ${new Date(commit.recorded_at).toLocaleTimeString('vi-VN')}`,
      );
      const refreshed = await loadAttendanceDay(context.organization_id, attendanceDay.work_date);
      setAttendanceDay(refreshed);
    } catch (error) {
      setAttendanceMessage(error instanceof Error ? error.message : 'ATTENDANCE_FINALIZE_FAILED');
    } finally {
      setAttendanceBusy(false);
    }
  }

  async function handleSignOut() {
    try {
      const supabase = createSupabaseMobileClient();
      try {
        await revokeCurrentMobileDevice();
      } catch (error) {
        console.warn(
          `[OpsDesk push] ${error instanceof Error ? error.message : 'DEVICE_REVOKE_FAILED'}`,
        );
      }
      await supabase.auth.signOut();
    } finally {
      router.replace('/');
    }
  }

  if (isLoading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator color={colors.accent} />
      </View>
    );
  }

  if (errorMessage || !context) {
    return (
      <View style={safeContainerStyle}>
        <Text style={styles.eyebrow}>OPSDESK · WORKSPACE</Text>
        <Text style={styles.title}>Không thể mở workspace</Text>
        <Text style={styles.body}>{errorMessage ?? 'Không thể xác minh quyền truy cập.'}</Text>
        <View style={styles.errorCard}>
          <Text style={styles.errorCardTitle}>Quyền truy cập an toàn</Text>
          <Text style={styles.errorCardBody}>
            Workspace chỉ hiển thị khi phiên đăng nhập và membership đang hoạt động được xác minh từ
            máy chủ.
          </Text>
        </View>
        <Pressable
          accessibilityRole="button"
          onPress={() => router.replace('/')}
          style={styles.primaryButton}
        >
          <Text style={styles.primaryButtonText}>Quay lại đăng nhập</Text>
        </Pressable>
      </View>
    );
  }

  const isToday = section === 'today';
  const isAttendance = section === 'attendance';
  const officeAttendanceEnabled = Boolean(
    !attendanceBusy &&
      attendanceDay?.shift &&
      attendanceDeviceId &&
      Platform.OS !== 'web' &&
      ['office', 'hybrid'].includes(attendanceDay.shift.allowed_mode),
  );
  const remoteAttendanceEnabled = Boolean(
    !attendanceBusy &&
      attendanceDay?.shift &&
      attendanceDeviceId &&
      Platform.OS !== 'web' &&
      ['remote', 'hybrid'].includes(attendanceDay.shift.allowed_mode),
  );

  return (
    <View style={safeContainerStyle}>
      <View style={styles.topBar}>
        <View style={styles.brandRow}>
          <View style={styles.brandMark}>
            <Text style={styles.brandMarkText}>O</Text>
          </View>
          <Text style={styles.brandName}>OpsDesk</Text>
        </View>
        <Pressable accessibilityRole="button" onPress={() => void handleSignOut()}>
          <Text style={styles.signOutText}>Đăng xuất</Text>
        </Pressable>
      </View>

      <Text style={styles.eyebrow}>OPSDESK · WORKSPACE</Text>
      <Text style={styles.title}>
        {isAttendance ? 'Chấm công' : isToday ? 'Hôm nay' : 'Tổng quan'}
      </Text>
      <Text style={styles.body}>
        {context.organization_name} · {context.display_name}
      </Text>

      <View style={styles.contextCard}>
        <Text style={styles.contextLabel}>Ngữ cảnh đã xác thực</Text>
        <Text style={styles.contextText}>Vai trò: {context.role}</Text>
        <Text style={styles.contextText}>Mã nhân sự: {context.employee_code}</Text>
        <Text style={styles.contextText}>Timezone: {context.timezone}</Text>
      </View>

      {isAttendance ? (
        <View style={styles.attendanceCard}>
          <Text style={styles.attendanceCode}>
            {attendanceDay?.shift ? 'SERVER_SHIFT_READY' : 'NO_VERIFIED_SHIFT'}
          </Text>
          <Text style={styles.emptyTitle}>
            {attendanceDay?.shift
              ? `${attendanceDay.sessions.some((item) => item.status === 'open') ? 'Đang trong ca' : 'Sẵn sàng chấm công'}`
              : 'Chưa có ca làm việc phù hợp'}
          </Text>
          <Text style={styles.emptyBody}>
            {attendanceDay?.shift
              ? `Ca ${new Date(attendanceDay.shift.starts_at).toLocaleTimeString('vi-VN')} - ${new Date(attendanceDay.shift.ends_at).toLocaleTimeString('vi-VN')}. Thời gian chính thức lấy từ máy chủ.`
              : 'Không có event hay giờ vào/ra nào được tự tạo khi chưa có ca và xác nhận từ máy chủ.'}
          </Text>
          {attendanceMessage ? (
            <Text style={styles.attendanceMessage}>{attendanceMessage}</Text>
          ) : null}
          <Pressable
            accessibilityRole="button"
            disabled={!officeAttendanceEnabled}
            onPress={() => void handleOfficeAttendance()}
            style={officeAttendanceEnabled ? styles.primaryButtonInline : styles.disabledButton}
          >
            <Text
              style={officeAttendanceEnabled ? styles.primaryButtonText : styles.disabledButtonText}
            >
              {attendanceBusy
                ? 'Đang xác thực...'
                : attendanceDay?.sessions.some((item) => item.status === 'open')
                  ? 'Chấm ra ca tại văn phòng'
                  : 'Chấm vào ca tại văn phòng'}
            </Text>
          </Pressable>
          <Pressable
            accessibilityRole="button"
            disabled={!remoteAttendanceEnabled}
            onPress={() => router.push('/attendance-remote' as Href)}
            style={remoteAttendanceEnabled ? styles.primaryButtonInline : styles.disabledButton}
          >
            <Text
              style={remoteAttendanceEnabled ? styles.primaryButtonText : styles.disabledButtonText}
            >
              {attendanceDay?.sessions.some((item) => item.status === 'open')
                ? 'Chấm ra ca online'
                : 'Chấm vào ca online'}
            </Text>
          </Pressable>
          {attendanceMessage?.toLowerCase().includes('permission') ? (
            <Pressable onPress={() => void openOfficeWifiPermissionSettingsNative()}>
              <Text style={styles.permissionLink}>Mở cài đặt quyền Wi-Fi</Text>
            </Pressable>
          ) : null}
        </View>
      ) : (
        <View style={styles.emptyCard}>
          <Text style={styles.emptyIcon}>{isToday ? '✓' : '◌'}</Text>
          <Text style={styles.emptyTitle}>
            {isToday ? 'Sẵn sàng cho ngày làm việc' : 'Workspace đang được chuẩn bị'}
          </Text>
          <Text style={styles.emptyBody}>
            {isToday
              ? 'Dữ liệu công việc hôm nay sẽ xuất hiện tại đây khi module nghiệp vụ được bật.'
              : 'Các chỉ số vận hành sẽ xuất hiện tại đây khi module nghiệp vụ được bật.'}
          </Text>
        </View>
      )}

      <View style={[styles.bottomNavigation, { bottom: layout.mobileBottomInset + insets.bottom }]}>
        <Pressable
          accessibilityRole="button"
          onPress={() => router.replace('/today')}
          style={[styles.navItem, isToday && styles.navItemActive]}
        >
          <Text style={[styles.navItemText, isToday && styles.navItemTextActive]}>Hôm nay</Text>
        </Pressable>
        <Pressable
          accessibilityRole="button"
          onPress={() => router.replace('/attendance')}
          style={[styles.navItem, isAttendance && styles.navItemActive]}
        >
          <Text style={[styles.navItemText, isAttendance && styles.navItemTextActive]}>
            Chấm công
          </Text>
        </Pressable>
        <Pressable
          accessibilityRole="button"
          onPress={() => router.replace('/overview')}
          style={[styles.navItem, !isToday && !isAttendance && styles.navItemActive]}
        >
          <Text style={[styles.navItemText, !isToday && !isAttendance && styles.navItemTextActive]}>
            Tổng quan
          </Text>
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  loadingContainer: {
    alignItems: 'center',
    backgroundColor: colors.canvas,
    flex: 1,
    justifyContent: 'center',
  },
  container: {
    backgroundColor: colors.canvas,
    flex: 1,
    padding: layout.mobileWorkspacePadding,
  },
  topBar: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 52,
  },
  brandRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.sm,
  },
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
  signOutText: {
    color: colors.accent,
    fontSize: typography.fontSize.label,
    fontWeight: typography.fontWeight.semibold,
  },
  eyebrow: {
    color: colors.accent,
    fontSize: typography.fontSize.caption,
    fontWeight: typography.fontWeight.bold,
    letterSpacing: 1,
  },
  title: {
    color: colors.textPrimary,
    fontSize: typography.fontSize.title,
    fontWeight: typography.fontWeight.bold,
    marginTop: spacing.md,
  },
  body: {
    color: colors.textSecondary,
    fontSize: typography.fontSize.bodyLarge,
    lineHeight: typography.lineHeight.bodyLarge,
    marginTop: 14,
  },
  contextCard: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: radii.lg,
    borderWidth: 1,
    gap: spacing.sm,
    marginTop: 24,
    padding: 18,
  },
  contextLabel: {
    color: colors.textPrimary,
    fontSize: typography.fontSize.label,
    fontWeight: typography.fontWeight.bold,
  },
  contextText: {
    color: colors.textSecondary,
    fontSize: typography.fontSize.label,
  },
  emptyCard: {
    alignItems: 'center',
    backgroundColor: colors.surfaceInset,
    borderColor: colors.border,
    borderRadius: radii.lg,
    borderWidth: 1,
    marginTop: 16,
    paddingHorizontal: 20,
    paddingVertical: 32,
  },
  emptyIcon: {
    color: colors.accent,
    fontSize: 30,
    fontWeight: '700',
  },
  emptyTitle: {
    color: colors.textPrimary,
    fontSize: typography.fontSize.bodyLarge,
    fontWeight: typography.fontWeight.bold,
    marginTop: 14,
    textAlign: 'center',
  },
  emptyBody: {
    color: colors.textSecondary,
    fontSize: typography.fontSize.label,
    lineHeight: typography.lineHeight.body,
    marginTop: 8,
    textAlign: 'center',
  },
  errorCard: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: radii.lg,
    borderWidth: 1,
    marginTop: 24,
    padding: 18,
  },
  errorCardTitle: {
    color: colors.textPrimary,
    fontSize: typography.fontSize.body,
    fontWeight: typography.fontWeight.bold,
  },
  errorCardBody: {
    color: colors.textSecondary,
    fontSize: typography.fontSize.label,
    lineHeight: typography.lineHeight.body,
    marginTop: 8,
  },
  attendanceCard: {
    backgroundColor: colors.surfaceInset,
    borderColor: colors.border,
    borderRadius: radii.lg,
    borderWidth: 1,
    gap: spacing.md,
    marginTop: 16,
    padding: 20,
  },
  attendanceCode: {
    color: colors.textMuted,
    fontSize: typography.fontSize.caption,
    fontWeight: typography.fontWeight.bold,
    letterSpacing: 0.8,
  },
  attendanceMessage: {
    color: colors.textSecondary,
    fontSize: typography.fontSize.label,
    lineHeight: typography.lineHeight.body,
    textAlign: 'center',
  },
  disabledButton: {
    alignItems: 'center',
    backgroundColor: '#e7e9ed',
    borderRadius: radii.md,
    justifyContent: 'center',
    minHeight: controls.mobileFieldHeight,
  },
  disabledButtonText: {
    color: colors.textMuted,
    fontSize: typography.fontSize.body,
    fontWeight: typography.fontWeight.bold,
  },
  primaryButton: {
    alignItems: 'center',
    backgroundColor: colors.primary,
    borderRadius: radii.md,
    justifyContent: 'center',
    marginTop: 18,
    minHeight: controls.mobileFieldHeight,
  },
  primaryButtonInline: {
    alignItems: 'center',
    backgroundColor: colors.primary,
    borderRadius: radii.md,
    justifyContent: 'center',
    minHeight: controls.mobileFieldHeight,
  },
  primaryButtonText: {
    color: colors.surface,
    fontSize: typography.fontSize.body,
    fontWeight: typography.fontWeight.bold,
  },
  permissionLink: {
    color: colors.accent,
    fontSize: typography.fontSize.label,
    fontWeight: typography.fontWeight.semibold,
    textAlign: 'center',
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
  navItemActive: {
    backgroundColor: '#edeef1',
  },
  navItemText: {
    color: colors.textMuted,
    fontSize: typography.fontSize.label,
    fontWeight: typography.fontWeight.semibold,
  },
  navItemTextActive: {
    color: colors.textPrimary,
  },
});
