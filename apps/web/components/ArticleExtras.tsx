"use client";

import { useEffect, useRef, useState } from "react";
import { ButtonBagikan as IconShare } from "@/components/icons";
import { shareLinks } from "@/lib/shareLinks";

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

/// Salin link artikel + share ke semua sosmed ala mock.
/// Web Share API dulu (mobile browser), fallback menu popup.
export function ShareButton({ path, label }: { path: string; label: string }) {
  const [copied, setCopied] = useState(false);
  const [open, setOpen] = useState(false);
  const boxRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const close = (e: MouseEvent) => {
      if (!boxRef.current?.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("click", close);
    return () => document.removeEventListener("click", close);
  }, [open]);

  async function copy() {
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

  async function share() {
    const url = `${window.location.origin}${path}`;
    try {
      if (typeof navigator.share === "function") {
        await navigator.share({ url, title: document.title });
        return;
      }
    } catch {
      /* batal/diabaikan -> buka menu */
    }
    setOpen((v) => !v);
  }

  const targets = shareLinks(
    typeof window === "undefined" ? path : `${window.location.origin}${path}`,
    typeof document === "undefined" ? "SABA" : document.title,
  );

  return (
    <div ref={boxRef} className="relative shrink-0">
      <button
        type="button"
        onClick={share}
        aria-label={label}
        aria-expanded={open}
        className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-[#424656]"
      >
        {copied ? (
          <span className="text-[11px] font-bold text-saba">✓</span>
        ) : (
          <IconShare width="1.5em" height="1.5em" />
        )}
      </button>
      {open ? (
        <div className="absolute right-0 z-20 mt-1 w-44 rounded-xl border border-line bg-white py-1 shadow-lg">
          {targets.map((t) =>
            t.key === "copy" ? (
              <button
                key={t.key}
                type="button"
                onClick={() => {
                  void copy();
                  setOpen(false);
                }}
                className="block w-full px-3.5 py-2 text-left text-[13px] font-semibold hover:bg-canvas"
              >
                {copied ? "✓ " : ""}
                {t.label}
              </button>
            ) : (
              <a
                key={t.key}
                href={t.href}
                target="_blank"
                rel="noopener noreferrer"
                onClick={() => setOpen(false)}
                className="block px-3.5 py-2 text-[13px] font-semibold no-underline hover:bg-canvas"
              >
                {t.label}
              </a>
            ),
          )}
        </div>
      ) : null}
    </div>
  );
}
