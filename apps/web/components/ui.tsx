'use client';

import type {
  ButtonHTMLAttributes,
  InputHTMLAttributes,
  RefObject,
  ReactNode,
  SelectHTMLAttributes,
  TextareaHTMLAttributes,
} from 'react';
import { useEffect, useId, useRef } from 'react';

type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger';

type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: ButtonVariant;
};

export function Button({ className, type = 'button', variant = 'primary', ...props }: ButtonProps) {
  return (
    <button
      className={joinClassNames('ui-button', `ui-button-${variant}`, className)}
      type={type}
      {...props}
    />
  );
}

type SidebarProps = {
  children: ReactNode;
  label?: string;
};

export function Sidebar({ children, label }: SidebarProps) {
  return (
    <aside className="ui-sidebar">
      {label ? <p className="ui-sidebar-label">{label}</p> : null}
      {children}
    </aside>
  );
}

type MobileBottomNavigationProps = {
  children: ReactNode;
  label?: string;
};

export function MobileBottomNavigation({
  children,
  label = 'Điều hướng mobile',
}: MobileBottomNavigationProps) {
  return (
    <nav aria-label={label} className="ui-mobile-bottom-navigation">
      {children}
    </nav>
  );
}

type AppShellProps = {
  children: ReactNode;
  header?: ReactNode;
  mobileNavigation?: ReactNode;
  sidebar: ReactNode;
};

export function AppShell({ children, header, mobileNavigation, sidebar }: AppShellProps) {
  return (
    <div className="ui-app-shell">
      <div className="ui-app-shell-sidebar">{sidebar}</div>
      <div className="ui-app-shell-main">
        {header ? <header className="ui-app-shell-header">{header}</header> : null}
        <main className="ui-app-shell-content">{children}</main>
      </div>
      {mobileNavigation}
    </div>
  );
}

type BreadcrumbProps = {
  children: ReactNode;
};

export function Breadcrumb({ children }: BreadcrumbProps) {
  return (
    <nav aria-label="Breadcrumb" className="ui-breadcrumb">
      {children}
    </nav>
  );
}

type PageHeaderProps = {
  actions?: ReactNode;
  description?: string;
  eyebrow?: string;
  title: string;
};

export function PageHeader({ actions, description, eyebrow, title }: PageHeaderProps) {
  return (
    <div className="ui-page-header">
      <div>
        {eyebrow ? <p className="ui-eyebrow">{eyebrow}</p> : null}
        <h1 className="ui-page-title">{title}</h1>
        {description ? <p className="ui-page-description">{description}</p> : null}
      </div>
      {actions ? <div className="ui-page-header-actions">{actions}</div> : null}
    </div>
  );
}

type FieldMessageProps = {
  error?: string;
  hint?: string;
};

function FieldMessage({ error, hint, id }: FieldMessageProps & { id?: string }) {
  if (error)
    return (
      <p className="ui-field-error" id={id}>
        {error}
      </p>
    );
  if (hint)
    return (
      <p className="ui-field-hint" id={id}>
        {hint}
      </p>
    );
  return null;
}

type InputProps = InputHTMLAttributes<HTMLInputElement> & {
  error?: string;
  hint?: string;
  label?: string;
};

export function Input({
  'aria-describedby': ariaDescribedBy,
  error,
  hint,
  id,
  label,
  ...props
}: InputProps) {
  const generatedId = useId();
  const inputId = id ?? generatedId;
  const messageId = error || hint ? `${inputId}-message` : undefined;
  const describedBy = [ariaDescribedBy, messageId].filter(Boolean).join(' ') || undefined;

  return (
    <div className="ui-field">
      {label ? <label htmlFor={inputId}>{label}</label> : null}
      <input aria-describedby={describedBy} aria-invalid={Boolean(error)} id={inputId} {...props} />
      <FieldMessage error={error} hint={hint} id={messageId} />
    </div>
  );
}

type TextareaProps = TextareaHTMLAttributes<HTMLTextAreaElement> & {
  error?: string;
  hint?: string;
  label?: string;
};

export function Textarea({
  'aria-describedby': ariaDescribedBy,
  error,
  hint,
  id,
  label,
  ...props
}: TextareaProps) {
  const generatedId = useId();
  const textareaId = id ?? generatedId;
  const messageId = error || hint ? `${textareaId}-message` : undefined;
  const describedBy = [ariaDescribedBy, messageId].filter(Boolean).join(' ') || undefined;

  return (
    <div className="ui-field">
      {label ? <label htmlFor={textareaId}>{label}</label> : null}
      <textarea
        aria-describedby={describedBy}
        aria-invalid={Boolean(error)}
        id={textareaId}
        {...props}
      />
      <FieldMessage error={error} hint={hint} id={messageId} />
    </div>
  );
}

type SelectOption = {
  label: string;
  value: string;
};

type SelectProps = Omit<SelectHTMLAttributes<HTMLSelectElement>, 'children'> & {
  error?: string;
  hint?: string;
  label?: string;
  options: SelectOption[];
  placeholder?: string;
};

export function Select({
  'aria-describedby': ariaDescribedBy,
  error,
  hint,
  id,
  label,
  options,
  placeholder,
  ...props
}: SelectProps) {
  const generatedId = useId();
  const selectId = id ?? generatedId;
  const messageId = error || hint ? `${selectId}-message` : undefined;
  const describedBy = [ariaDescribedBy, messageId].filter(Boolean).join(' ') || undefined;

  return (
    <div className="ui-field">
      {label ? <label htmlFor={selectId}>{label}</label> : null}
      <select aria-describedby={describedBy} aria-invalid={Boolean(error)} id={selectId} {...props}>
        {placeholder ? <option value="">{placeholder}</option> : null}
        {options.map((option) => (
          <option key={option.value} value={option.value}>
            {option.label}
          </option>
        ))}
      </select>
      <FieldMessage error={error} hint={hint} id={messageId} />
    </div>
  );
}

type ComboboxProps = Omit<InputHTMLAttributes<HTMLInputElement>, 'list'> & {
  error?: string;
  hint?: string;
  label?: string;
  options: SelectOption[];
};

export function Combobox({
  'aria-describedby': ariaDescribedBy,
  error,
  hint,
  id,
  label,
  options,
  ...props
}: ComboboxProps) {
  const generatedId = useId();
  const inputId = id ?? generatedId;
  const listId = `${inputId}-options`;
  const messageId = error || hint ? `${inputId}-message` : undefined;
  const describedBy = [ariaDescribedBy, messageId].filter(Boolean).join(' ') || undefined;

  return (
    <div className="ui-field">
      {label ? <label htmlFor={inputId}>{label}</label> : null}
      <input
        aria-describedby={describedBy}
        aria-invalid={Boolean(error)}
        id={inputId}
        list={listId}
        {...props}
      />
      <datalist id={listId}>
        {options.map((option) => (
          <option key={option.value} label={option.label} value={option.value} />
        ))}
      </datalist>
      <FieldMessage error={error} hint={hint} id={messageId} />
    </div>
  );
}

type CheckboxProps = Omit<InputHTMLAttributes<HTMLInputElement>, 'type'> & {
  label: string;
};

export function Checkbox({ className, label, ...props }: CheckboxProps) {
  return (
    <label className={joinClassNames('ui-checkbox', className)}>
      <input type="checkbox" {...props} />
      <span>{label}</span>
    </label>
  );
}

export function DailyTaskCheckbox({ className, label, ...props }: CheckboxProps) {
  return (
    <label className={joinClassNames('ui-daily-task-checkbox', className)}>
      <input type="checkbox" {...props} />
      <span>{label}</span>
    </label>
  );
}

type OverlayProps = {
  children: ReactNode;
  footer?: ReactNode;
  onClose?: () => void;
  open: boolean;
  title: string;
};

function useOverlayFocus(
  open: boolean,
  onClose: (() => void) | undefined,
  surfaceRef: RefObject<HTMLElement | null>,
) {
  const onCloseRef = useRef(onClose);

  useEffect(() => {
    onCloseRef.current = onClose;
  }, [onClose]);

  useEffect(() => {
    if (!open) return;

    const previouslyFocused =
      document.activeElement instanceof HTMLElement ? document.activeElement : null;
    const focusSurface = () => {
      const surface = surfaceRef.current;
      if (!surface) return;

      const focusableElements = getFocusableElements(surface);
      (focusableElements[0] ?? surface).focus();
    };
    const frame = window.requestAnimationFrame(focusSurface);
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape' && onCloseRef.current) {
        event.preventDefault();
        onCloseRef.current();
        return;
      }

      if (event.key !== 'Tab') return;

      const surface = surfaceRef.current;
      if (!surface) return;

      const focusableElements = getFocusableElements(surface);
      if (focusableElements.length === 0) {
        event.preventDefault();
        surface.focus();
        return;
      }

      const firstElement = focusableElements[0];
      const lastElement = focusableElements[focusableElements.length - 1];
      if (!firstElement || !lastElement) return;

      if (event.shiftKey && document.activeElement === firstElement) {
        event.preventDefault();
        lastElement.focus();
      } else if (!event.shiftKey && document.activeElement === lastElement) {
        event.preventDefault();
        firstElement.focus();
      }
    };

    document.addEventListener('keydown', handleKeyDown);

    return () => {
      window.cancelAnimationFrame(frame);
      document.removeEventListener('keydown', handleKeyDown);
      if (previouslyFocused?.isConnected) previouslyFocused.focus();
    };
  }, [open, surfaceRef]);
}

function getFocusableElements(container: HTMLElement) {
  return Array.from(
    container.querySelectorAll<HTMLElement>(
      'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])',
    ),
  ).filter((element) => !element.hasAttribute('hidden') && element.getClientRects().length > 0);
}

export function Dialog({ children, footer, onClose, open, title }: OverlayProps) {
  const titleId = useId();
  const surfaceRef = useRef<HTMLElement | null>(null);
  useOverlayFocus(open, onClose, surfaceRef);

  if (!open) return null;

  return (
    <div className="ui-overlay">
      <section
        aria-labelledby={titleId}
        aria-modal="true"
        className="ui-dialog"
        ref={surfaceRef}
        role="dialog"
        tabIndex={-1}
      >
        <div className="ui-dialog-header">
          <h2 id={titleId}>{title}</h2>
          {onClose ? (
            <Button aria-label="Đóng hộp thoại" onClick={onClose} variant="ghost">
              ×
            </Button>
          ) : null}
        </div>
        <div className="ui-dialog-body">{children}</div>
        {footer ? <div className="ui-dialog-footer">{footer}</div> : null}
      </section>
    </div>
  );
}

type DrawerProps = OverlayProps & {
  side?: 'left' | 'right';
  size?: 'compact' | 'default';
};

export function Drawer({
  children,
  footer,
  onClose,
  open,
  side = 'right',
  size = 'default',
  title,
}: DrawerProps) {
  const titleId = useId();
  const surfaceRef = useRef<HTMLElement | null>(null);
  useOverlayFocus(open, onClose, surfaceRef);

  if (!open) return null;

  return (
    <div className="ui-overlay">
      <aside
        aria-labelledby={titleId}
        aria-modal="true"
        className={joinClassNames('ui-drawer', `ui-drawer-${side}`, `ui-drawer-${size}`)}
        ref={surfaceRef}
        role="dialog"
        tabIndex={-1}
      >
        <div className="ui-dialog-header">
          <h2 id={titleId}>{title}</h2>
          {onClose ? (
            <Button aria-label="Đóng ngăn bên" onClick={onClose} variant="ghost">
              ×
            </Button>
          ) : null}
        </div>
        <div className="ui-dialog-body">{children}</div>
        {footer ? <div className="ui-dialog-footer">{footer}</div> : null}
      </aside>
    </div>
  );
}

export function Sheet(props: DrawerProps) {
  return <Drawer {...props} />;
}

type TableColumn = {
  key: string;
  label: string;
};

type TableProps = {
  caption?: string;
  columns: TableColumn[];
  rows: Array<Record<string, ReactNode>>;
};

export function Table({ caption, columns, rows }: TableProps) {
  return (
    <div className="ui-table-wrap">
      <table className="ui-table">
        {caption ? <caption>{caption}</caption> : null}
        <thead>
          <tr>
            {columns.map((column) => (
              <th key={column.key} scope="col">
                {column.label}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, rowIndex) => (
            <tr key={rowIndex}>
              {columns.map((column) => (
                <td key={column.key}>{row[column.key] ?? '—'}</td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

type BadgeTone = 'neutral' | 'success' | 'warning' | 'danger';

export function StatusBadge({
  children,
  tone = 'neutral',
}: {
  children: ReactNode;
  tone?: BadgeTone;
}) {
  return <span className={joinClassNames('ui-badge', `ui-badge-${tone}`)}>{children}</span>;
}

type Priority = 'low' | 'medium' | 'normal' | 'high' | 'urgent';

export function PriorityBadge({ priority }: { priority: Priority }) {
  const labels: Record<Priority, string> = {
    low: 'Thấp',
    medium: 'Trung bình',
    normal: 'Bình thường',
    high: 'Cao',
    urgent: 'Khẩn cấp',
  };

  return (
    <span className={joinClassNames('ui-badge', `ui-priority-${priority}`)}>
      {labels[priority]}
    </span>
  );
}

export function EmptyState({ children, title }: { children?: ReactNode; title: string }) {
  return (
    <section className="ui-empty-state">
      <span className="ui-empty-state-icon" aria-hidden="true">
        ∅
      </span>
      <h2>{title}</h2>
      {children ? <div>{children}</div> : null}
    </section>
  );
}

export function ErrorState({
  children,
  title = 'Không thể tải dữ liệu',
}: {
  children?: ReactNode;
  title?: string;
}) {
  return (
    <section className="ui-error-state" role="alert">
      <h2>{title}</h2>
      {children ? <div>{children}</div> : null}
    </section>
  );
}

export function Skeleton({ count = 1 }: { count?: number }) {
  return (
    <div aria-label="Đang tải" className="ui-skeleton-list" role="status">
      {Array.from({ length: count }, (_, index) => (
        <span className="ui-skeleton" key={index} />
      ))}
    </div>
  );
}

export function Toast({
  message,
  onDismiss,
  tone = 'neutral',
}: {
  message: string;
  onDismiss?: () => void;
  tone?: BadgeTone;
}) {
  return (
    <div className={joinClassNames('ui-toast', `ui-toast-${tone}`)} role="status">
      <span>{message}</span>
      {onDismiss ? (
        <Button aria-label="Đóng thông báo" onClick={onDismiss} variant="ghost">
          ×
        </Button>
      ) : null}
    </div>
  );
}

export function ConfirmDialog({
  cancelLabel = 'Hủy',
  children,
  confirmLabel = 'Xác nhận',
  onCancel,
  onConfirm,
  open,
  title,
}: {
  cancelLabel?: string;
  children?: ReactNode;
  confirmLabel?: string;
  onCancel: () => void;
  onConfirm: () => void;
  open: boolean;
  title: string;
}) {
  return (
    <Dialog
      footer={
        <>
          <Button onClick={onCancel} variant="secondary">
            {cancelLabel}
          </Button>
          <Button onClick={onConfirm}>{confirmLabel}</Button>
        </>
      }
      onClose={onCancel}
      open={open}
      title={title}
    >
      {children}
    </Dialog>
  );
}

export function PersonLabel({ name, role }: { name: string; role?: string }) {
  return (
    <span className="ui-person-label">
      <span>{name}</span>
      {role ? <small>{role}</small> : null}
    </span>
  );
}

function joinClassNames(...values: Array<string | undefined>) {
  return values.filter(Boolean).join(' ');
}
