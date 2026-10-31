// shortcut: form paste-link → proxy /api/convert → poll → redirect artikel.
// Pola sama seperti app Android (poll 5 detik, maks ~6 menit, bisa batal).
"use client";

import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { articlePath } from "@/lib/site";
import type { Lang } from "@/lib/articles";

const T = {
  id: {
    placeholder: "Tempel link TikTok/YouTube…",
    send: "Buat artikel",
    cancel: "Batal",
    sending: "Mengirim…",
    waiting: "Artikel dimasak di server, mohon tunggu…",
    badUrl: "Hanya link https TikTok/YouTube yang didukung.",
    failed: "Gagal. Coba lagi.",
    timeout: "Belum jadi setelah 6 menit. Coba lagi nanti.",
  },
  en: {
    placeholder: "Paste a TikTok/YouTube link…",
    send: "Create article",
    cancel: "Cancel",
    sending: "Sending…",
    waiting: "Cooking the article on the server, please wait…",
    badUrl: "Only https TikTok/YouTube links are supported.",
    failed: "Failed. Try again.",
    timeout: "Not ready after 6 minutes. Try again later.",
  },
} as const;

const HOST_RE = /(^|\.)(tiktok\.com|youtube\.com|youtu\.be)$/i;

function supported(url: string): boolean {
  try {
    const u = new URL(url.trim());
    return u.protocol === "https:" && HOST_RE.test(u.hostname);
  } catch {
    return false;
  }
}

export function ConvertForm({ lang }: { lang: Lang }) {
  const t = T[lang];
  const router = useRouter();
  const [link, setLink] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const seq = useRef(0);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (busy) return;
    if (!supported(link)) {
      setError(t.badUrl);
      return;
    }
    const my = ++seq.current;
    setBusy(true);
    setError(null);
    try {
      const res = await fetch("/api/convert", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ url: link.trim() }),
      });
      const body = await res.json().catch(() => ({}));
      if (!res.ok || !body.jobId) throw new Error(body.error ?? t.failed);
      for (let i = 0; i < 72; i++) {
        if (seq.current !== my) return;
        const poll = await fetch(
          `/api/articles/${encodeURIComponent(body.jobId)}`,
        ).catch(() => null);
        if (seq.current !== my) return;
        if (poll?.ok) {
          router.push(articlePath(body.jobId, lang));
          return;
        }
        await new Promise((r) => setTimeout(r, 5000));
      }
      if (seq.current === my) setError(t.timeout);
    } catch (err) {
      if (seq.current === my) {
        setError(err instanceof Error ? err.message : t.failed);
      }
    } finally {
      if (seq.current === my) setBusy(false);
    }
  }

  return (
    <form onSubmit={submit} className="mt-5 font-sans">
      <div className="flex gap-2">
        <input
          value={link}
          onChange={(e) => setLink(e.target.value)}
          placeholder={t.placeholder}
          inputMode="url"
          className="w-full rounded-xl border border-neutral-200 px-4 py-2 text-sm outline-none focus:border-neutral-400"
        />
        <button
          type="submit"
          disabled={busy}
          className="rounded-xl bg-accent px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
        >
          {busy ? t.sending : t.send}
        </button>
      </div>
      {busy ? (
        <div className="mt-3 flex items-center gap-3">
          <p className="text-sm text-muted">{t.waiting}</p>
          <button
            type="button"
            onClick={() => {
              seq.current += 1;
              setBusy(false);
            }}
            className="text-sm underline underline-offset-2"
          >
            {t.cancel}
          </button>
        </div>
      ) : null}
      {error && !busy ? (
        <p className="mt-3 text-sm text-red-700">{error}</p>
      ) : null}
    </form>
  );
}
