"use client";

import { useEffect, useState } from "react";
import Modal from "../../_components/Modal";
import ErrorPanel from "../../_components/ErrorPanel";
import Badge from "../../_components/Badge";

export default function RefSetCreateModal({ open, onClose, onSubmit, canConfirm, baseRefSetId }) {
  const [status, setStatus] = useState("draft"); // draft|confirmed
  const [copyBase, setCopyBase] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [err, setErr] = useState(null);

  useEffect(() => {
    if (!open) return;
    setStatus("draft");
    setCopyBase(true);
    setSubmitting(false);
    setErr(null);
  }, [open]);

  async function create() {
    setErr(null);
    if (status === "confirmed" && !canConfirm) {
      setErr({ message: "refs < 8: cannot create confirmed (policy)", request_id: null, details: { min: 8 } });
      return;
    }
    setSubmitting(true);
    try {
      await onSubmit({ status, ...(status === "confirmed" && copyBase && baseRefSetId ? { base_ref_set_id: baseRefSetId } : {}) });
      onClose();
    } catch (e) {
      setErr(e);
    } finally {
      setSubmitting(false);
    }
  }

  const footer = (
    <div className="flex items-center justify-end gap-2">
      <button
        type="button"
        className="rounded-md border px-3 py-1.5 text-xs hover:bg-gray-50 disabled:opacity-50"
        onClick={onClose}
        disabled={submitting}
      >
        Cancel
      </button>
      <button
        type="button"
        className="rounded-md bg-black px-3 py-1.5 text-xs text-white hover:bg-black/90 disabled:opacity-50"
        onClick={create}
        disabled={submitting}
      >
        {submitting ? "Creating..." : "Create"}
      </button>
    </div>
  );

  return (
    <Modal open={open} title="Create Ref Set Version" onClose={submitting ? () => {} : onClose} footer={footer}>
      {err ? <ErrorPanel title="Request failed" error={err} onRetry={() => setErr(null)} /> : null}

      <div className="grid gap-3">
        <div>
          <label className="text-xs font-medium text-gray-700">Status</label>
          <select
            className="mt-1 w-full rounded-md border px-3 py-2 text-sm"
            value={status}
            onChange={(e) => setStatus(e.target.value)}
          >
            <option value="draft">draft</option>
            <option value="confirmed">confirmed</option>
          </select>
          {status === "confirmed" ? (
            <div className="mt-2 text-xs text-gray-700">
              {canConfirm ? <Badge tone="green">meets ≥8</Badge> : <Badge tone="amber">below ≥8</Badge>}{" "}
              Confirmed requires refs ≥ 8 (policy-dependent).
            </div>
          ) : null}
        </div>

        {status === "confirmed" ? (
          <div className="rounded-md border bg-gray-50 p-2 text-xs text-gray-700">
            <div className="flex items-center justify-between">
              <div className="font-medium">Copy refs from current</div>
              <input
                type="checkbox"
                checked={copyBase}
                onChange={(e) => setCopyBase(e.target.checked)}
                disabled={!baseRefSetId}
              />
            </div>
            <div className="mt-1 text-gray-600">
              If backend supports it, we send <span className="font-mono">base_ref_set_id</span>. If rejected, you can create confirmed without copy and re-add refs.
            </div>
            <div className="mt-1 text-gray-500">
              base_ref_set_id: <span className="font-mono">{baseRefSetId || "(none)"}</span>
            </div>
          </div>
        ) : null}
      </div>
    </Modal>
  );
}
