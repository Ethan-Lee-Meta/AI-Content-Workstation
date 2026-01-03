"use client";

import { useEffect, useState } from "react";
import Modal from "../_components/Modal";
import ErrorPanel from "../_components/ErrorPanel";

export default function CharacterCreateModal({ open, onClose, onSubmit }) {
  const [name, setName] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [err, setErr] = useState(null);

  useEffect(() => {
    if (!open) return;
    setName("");
    setErr(null);
    setSubmitting(false);
  }, [open]);

  async function handleCreate() {
    setErr(null);
    if (!name.trim()) {
      setErr({ message: "name is required", request_id: null, details: { field: "name" } });
      return;
    }
    setSubmitting(true);
    try {
      await onSubmit({ name: name.trim() });
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
        onClick={handleCreate}
        disabled={submitting}
      >
        {submitting ? "Creating..." : "Create"}
      </button>
    </div>
  );

  return (
    <Modal
      open={open}
      title="New Character"
      onClose={submitting ? () => {} : onClose}
      footer={footer}
    >
      {err ? <ErrorPanel title="Request failed" error={err} onRetry={() => setErr(null)} /> : null}

      <div className="grid gap-3">
        <div>
          <label className="text-xs font-medium text-gray-700">Name</label>
          <input
            className="mt-1 w-full rounded-md border px-3 py-2 text-sm"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="e.g. Alice"
          />
        </div>

        <div className="text-xs text-gray-600">
          Status defaults to backend rules (usually draft). You can manage ref_sets in character detail.
        </div>
      </div>
    </Modal>
  );
}
