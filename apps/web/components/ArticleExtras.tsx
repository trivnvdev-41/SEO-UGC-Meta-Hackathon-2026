"use client";

import { useEffect, useState } from "react";
import { ButtonBagikan as IconShare } from "@/components/icons";

const followsKey = "saba-follows";

function loadFollows(): string[] {
  try {
    const v = JSON.parse(localStorage.getItem(followsKey) ?? "[]");
    return Array.isArray(v) ? v.map(String) : [];
  } catch {
    return [];
  }
}

/// Tombol Ikuti komunitas: toggle lokal (pola bookmark), tanpa angka palsu.
export function FollowButton({
  id,
  label,
  following,
}: {
  id: string;
  label: string;
  following: string;
}) {
  const [on, setOn] = useState(false);
  useEffect(() => {
    setOn(loadFollows().includes(id));
  }, [id]);
  function toggle() {
    const list = loadFollows();
    const next = list.includes(id)
      ? list.filter((x) => x !== id)
      : [...list, id];
    try {
      localStorage.setItem(followsKey, JSON.stringify(next));
    } catch {
      /* privat: sesi ini saja */
    }
    setOn(!on);
  }
  return (
    <button
      type="button"
      onClick={toggle}
      aria-pressed={on}
      className={`shrink-0 rounded-full px-3.5 py-1.5 font-sans text-[13px] font-semibold shadow-sm ${
        on ? "bg-canvas text-saba" : "bg-saba text-white"
      }`}
    >
      {on ? following : label}
    </button>
  );
}

/// Salin link artikel: ikon bagikan ala mock.
export function ShareButton({ path, label }: { path: string; label: string }) {
  const [copied, setCopied] = useState(false);
  async function share() {
    try {
      await navigator.clipboard.writeText(
        `${window.location.origin}${path}`,
      );
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    } catch {
      /* abaikan */
    }
  }
  return (
    <button
      type="button"
      onClick={share}
      aria-label={label}
      className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-[#424656]"
    >
      {copied ? (
        <span className="text-[11px] font-bold text-saba">✓</span>
      ) : (
        <IconShare width="1.5em" height="1.5em" />
      )}
    </button>
  );
}
