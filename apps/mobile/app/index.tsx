import { useRouter } from 'expo-router';
import { useEffect, useState } from 'react';
import { ActivityIndicator, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { colors, controls, layout, radii, spacing, typography } from '@opsdesk/design-tokens';
import {
  getMobileContextErrorMessage,
  loadMobileMemberContext,
  MobileAuthenticationRequiredError,
} from '../lib/member-context';
import { createSupabaseMobileClient } from '../lib/supabase';

const emailPattern = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

export default function IndexScreen() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [isRestoring, setIsRestoring] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    let isMounted = true;

    async function restoreSession() {
      try {
        const supabase = createSupabaseMobileClient();
        const { data } = await supabase.auth.getSession();

        if (!data.session) {
          return;
        }

        const context = await loadMobileMemberContext(supabase);
        if (isMounted) {
          router.replace(context.role === 'employee' ? '/today' : '/overview');
        }
      } catch (error) {
        if (error instanceof MobileAuthenticationRequiredError) {
          return;
        }

        if (isMounted) {
          setErrorMessage(getMobileContextErrorMessage(error));
        }
      } finally {
        if (isMounted) {
          setIsRestoring(false);
        }
      }
    }

    void restoreSession();

    return () => {
      isMounted = false;
    };
  }, [router]);

  async function handleSignIn() {
    setErrorMessage(null);

    const normalizedEmail = email.trim();
    if (!emailPattern.test(normalizedEmail)) {
      setErrorMessage('Nhập email công việc hợp lệ.');
      return;
    }

    if (!password) {
      setErrorMessage('Nhập mật khẩu để tiếp tục.');
      return;
    }

    setIsSubmitting(true);
    let supabase: ReturnType<typeof createSupabaseMobileClient> | null = null;

    try {
      supabase = createSupabaseMobileClient();
      const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
        email: normalizedEmail,
        password,
      });

      if (authError || !authData.user) {
        setErrorMessage('Email hoặc mật khẩu không đúng.');
        return;
      }

      const context = await loadMobileMemberContext(supabase);
      router.replace(context.role === 'employee' ? '/today' : '/overview');
    } catch (error) {
      if (supabase) {
        await supabase.auth.signOut();
      }

      setErrorMessage(getMobileContextErrorMessage(error));
    } finally {
      setIsSubmitting(false);
    }
  }

  if (isRestoring) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator color={colors.accent} />
      </View>
    );
  }

  return (
    <View
      style={[
        styles.container,
        {
          paddingBottom: layout.mobileAuthPadding + insets.bottom,
          paddingTop: layout.mobileAuthPadding + insets.top,
        },
      ]}
    >
      <View style={styles.brandRow}>
        <View style={styles.brandMark}>
          <Text style={styles.brandMarkText}>O</Text>
        </View>
        <Text style={styles.brandName}>OpsDesk</Text>
      </View>
      <Text style={styles.eyebrow}>WORKSPACE OPERATIONS</Text>
      <Text style={styles.title}>Đăng nhập workspace</Text>
      <Text style={styles.body}>Theo dõi công việc và phối hợp cùng đội ngũ trên mobile.</Text>

      <View style={styles.form}>
        <View style={styles.fieldGroup}>
          <Text style={styles.label}>Email công việc</Text>
          <TextInput
            accessibilityLabel="Email công việc"
            autoCapitalize="none"
            autoComplete="email"
            editable={!isSubmitting}
            keyboardType="email-address"
            onChangeText={setEmail}
            placeholder="ten@congty.vn"
            placeholderTextColor={colors.inputPlaceholder}
            style={styles.input}
            value={email}
          />
        </View>

        <View style={styles.fieldGroup}>
          <View style={styles.labelRow}>
            <Text style={styles.label}>Mật khẩu</Text>
            <Pressable
              accessibilityLabel={showPassword ? 'Ẩn mật khẩu' : 'Hiện mật khẩu'}
              accessibilityRole="button"
              disabled={isSubmitting}
              onPress={() => setShowPassword((current) => !current)}
            >
              <Text style={styles.toggleText}>
                {showPassword ? 'Ẩn mật khẩu' : 'Hiện mật khẩu'}
              </Text>
            </Pressable>
          </View>
          <TextInput
            accessibilityLabel="Mật khẩu"
            autoComplete="password"
            editable={!isSubmitting}
            onChangeText={setPassword}
            placeholder="Nhập mật khẩu"
            placeholderTextColor={colors.inputPlaceholder}
            secureTextEntry={!showPassword}
            style={styles.input}
            value={password}
          />
        </View>

        {errorMessage ? (
          <Text style={styles.error} accessibilityRole="alert">
            {errorMessage}
          </Text>
        ) : null}

        <Pressable
          accessibilityRole="button"
          disabled={isSubmitting}
          onPress={handleSignIn}
          style={styles.primaryButton}
        >
          {isSubmitting ? (
            <ActivityIndicator color={colors.surface} />
          ) : (
            <Text style={styles.primaryButtonText}>Đăng nhập</Text>
          )}
        </Pressable>
        <Text style={styles.footnote}>
          Chưa có tài khoản? Liên hệ quản trị viên để nhận lời mời.
        </Text>
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
    padding: layout.mobileAuthPadding,
  },
  brandRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.md,
    marginBottom: spacing['5xl'],
  },
  brandMark: {
    alignItems: 'center',
    backgroundColor: colors.primary,
    borderRadius: radii.control,
    height: 32,
    justifyContent: 'center',
    width: 32,
  },
  brandMarkText: {
    color: colors.surface,
    fontSize: typography.fontSize.bodyLarge,
    fontWeight: typography.fontWeight.bold,
  },
  brandName: {
    color: colors.textPrimary,
    fontSize: typography.fontSize.brand,
    fontWeight: typography.fontWeight.bold,
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
    marginTop: spacing.lg,
  },
  form: {
    gap: 18,
    marginTop: 36,
  },
  fieldGroup: {
    gap: spacing.sm,
  },
  labelRow: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  label: {
    color: colors.textPrimary,
    fontSize: typography.fontSize.label,
    fontWeight: typography.fontWeight.semibold,
  },
  input: {
    backgroundColor: colors.surface,
    borderColor: colors.inputBorder,
    borderRadius: radii.md,
    borderWidth: 1,
    color: colors.textPrimary,
    fontSize: typography.fontSize.bodyLarge,
    minHeight: controls.mobileFieldHeight,
    paddingHorizontal: 13,
  },
  toggleText: {
    color: colors.accent,
    fontSize: typography.fontSize.caption,
    fontWeight: typography.fontWeight.semibold,
  },
  error: {
    backgroundColor: colors.dangerSoft,
    borderColor: colors.dangerBorder,
    borderRadius: radii.md,
    borderWidth: 1,
    color: colors.danger,
    fontSize: typography.fontSize.label,
    lineHeight: typography.lineHeight.body,
    padding: 11,
  },
  primaryButton: {
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
  footnote: {
    color: colors.textMuted,
    fontSize: typography.fontSize.caption,
    lineHeight: typography.lineHeight.caption,
    textAlign: 'center',
  },
});
