'use client';

import { useActionState } from 'react';
import { useFormStatus } from 'react-dom';

export function Submit({ children, className = 'btn', pending: pendingText }) {
  const { pending } = useFormStatus();
  return (
    <button className={className} disabled={pending} type="submit">
      {pending ? pendingText || 'Working…' : children}
    </button>
  );
}

// A form bound to a server action that returns { ok } or { error }.
export function ActionForm({ action, children, className }) {
  const [state, formAction] = useActionState(action, null);
  return (
    <form action={formAction} className={className}>
      {children}
      {state?.ok && <p className="msg ok">{state.ok}</p>}
      {state?.error && <p className="msg err">{state.error}</p>}
    </form>
  );
}

export function ConfirmSubmit({ children, className = 'btn ghost sm', message = 'Are you sure?' }) {
  return (
    <button
      className={className}
      type="submit"
      onClick={(e) => {
        if (!confirm(message)) e.preventDefault();
      }}
    >
      {children}
    </button>
  );
}
