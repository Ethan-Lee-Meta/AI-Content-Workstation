"use client";

export default function Modal({ open, title, children, onClose, footer }) {
  if (!open) return null;
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-black/30" onClick={onClose} />
      <div className="relative w-full max-w-2xl rounded-lg border bg-white shadow-lg">
        <div className="flex items-center justify-between border-b px-4 py-3">
          <div className="text-sm font-semibold">{title}</div>
          <button
            type="button"
            className="rounded-md border px-2 py-1 text-xs hover:bg-gray-50"
            onClick={onClose}
          >
            Close
          </button>
        </div>
        <div className="px-4 py-3">{children}</div>
        {footer ? <div className="border-t px-4 py-3">{footer}</div> : null}
      </div>
    </div>
  );
}
