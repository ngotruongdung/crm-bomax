'use client';

import { useState } from 'react';
import { Button, ConfirmDialog, Dialog, Drawer, Sheet } from '../../../components/ui';

export default function OverlayPreview() {
  const [openOverlay, setOpenOverlay] = useState<'dialog' | 'drawer' | 'sheet' | 'confirm' | null>(
    null,
  );

  return (
    <div className="ui-preview-row ui-preview-overlay-actions">
      <Button onClick={() => setOpenOverlay('dialog')} variant="secondary">
        Dialog
      </Button>
      <Button onClick={() => setOpenOverlay('drawer')} variant="secondary">
        Drawer
      </Button>
      <Button onClick={() => setOpenOverlay('sheet')} variant="secondary">
        Sheet
      </Button>
      <Button onClick={() => setOpenOverlay('confirm')} variant="secondary">
        Confirm
      </Button>

      <Dialog
        onClose={() => setOpenOverlay(null)}
        open={openOverlay === 'dialog'}
        title="Dialog primitive"
      >
        <p>Overlay có heading, body, footer và nút đóng rõ ràng.</p>
      </Dialog>
      <Drawer
        onClose={() => setOpenOverlay(null)}
        open={openOverlay === 'drawer'}
        title="Drawer primitive"
      >
        <p>Drawer trượt từ cạnh phải, dùng cho nội dung theo ngữ cảnh.</p>
      </Drawer>
      <Sheet
        onClose={() => setOpenOverlay(null)}
        open={openOverlay === 'sheet'}
        title="Sheet primitive"
      >
        <p>Sheet dùng cùng contract overlay và có thể thay đổi layout theo breakpoint.</p>
      </Sheet>
      <ConfirmDialog
        onCancel={() => setOpenOverlay(null)}
        onConfirm={() => setOpenOverlay(null)}
        open={openOverlay === 'confirm'}
        title="Confirm primitive"
      >
        <p>Hành động cần xác nhận rõ ràng trước khi tiếp tục.</p>
      </ConfirmDialog>
    </div>
  );
}
