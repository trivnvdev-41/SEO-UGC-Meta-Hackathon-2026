"use client";

import { useEffect, useState } from "react";

type Item = { name: string; text: string; at: number };
type Identity = { name: string; email: string };

const itemsKey = (id: string) => `saba-comments:${id}`;
const identKey = "saba-identity";

function loadItems(id: string): Item[] {
  try {
    const raw = localStorage.getItem(itemsKey(id));
    const arr = raw ? JSON.parse(raw) : [];
    return Array.isArray(arr) ? arr : [];
  } catch {
    return [];
  }
}

function timeAgo(at: number, lang: "id" | "en"): string {
  const m = Math.floor((Date.now() - at) / 60000);
  if (m < 1) return lang === "en" ? "just now" : "baru saja";
  if (m < 60) return `${m} mnt`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h} jam`;
  return `${Math.floor(h / 24)} hari`;
}

export function Comments({
  id,
  lang,
  t,
}: {
  id: string;
  lang: "id" | "en";
  t: {
    title: string;
    empty: string;
    namePh: string;
    emailPh: string;
    textPh: string;
    send: string;
    needName: string;
  };
}) {
  const [items, setItems] = useState<Item[]>([]);
  const [ident, setIdent] = useState<Identity>({ name: "", email: "" });
  const [text, setText] = useState("");
  const [ready, setReady] = useState(false);

  useEffect(() => {
    setItems(loadItems(id));
    try {
      const raw = localStorage.getItem(identKey);
      if (raw) setIdent({ name: "", email: "", ...JSON.parse(raw) });
    } catch {
      /* abaikan */
    }
    setReady(true);
  }, [id]);

  const canSend = ident.name.trim().length >= 2 && text.trim().length > 0;

  function send() {
    if (!canSend) return;
    const item = {
      name: ident.name.trim(),
      text: text.trim().slice(0, 500),
      at: Date.now(),
    };
    const next = [item, ...items];
    setItems(next);
    try {
      localStorage.setItem(itemsKey(id), JSON.stringify(next));
      localStorage.setItem(
        identKey,
        JSON.stringify({ name: ident.name.trim(), email: ident.email.trim() }),
      );
    } catch {
      /* mode privat: tampil sesi ini saja */
    }
    setText("");
  }

  if (!ready) return null;

  return (
    <section aria-label={t.title} className="mt-4">
      <h2 className="mt-0 mb-3 text-lg">
        {t.title}{" "}
        <span className="text-sm font-medium text-muted">({items.length})</span>
      </h2>
      {items.length === 0 ? (
        <p className="mb-4 text-sm text-muted">{t.empty}</p>
      ) : (
        <ul className="mb-4 grid list-none gap-3 p-0">
          {items.map((c, i) => (
            <li
              key={`${c.at}-${i}`}
              className="rounded-xl border border-line bg-canvas p-3"
            >
              <p className="flex items-center gap-2">
                <span className="flex h-6 w-6 items-center justify-center rounded-full bg-saba-soft text-xs font-bold text-saba">
                  {c.name.charAt(0).toUpperCase()}
                </span>
                <span className="text-xs font-bold">{c.name}</span>
                <span className="text-[11px] text-muted">
                  {timeAgo(c.at, lang)}
                </span>
              </p>
              <p className="mt-1 text-[15px] leading-relaxed whitespace-pre-wrap">
                {c.text}
              </p>
            </li>
          ))}
        </ul>
      )}
      <div className="grid gap-2">
        <div className="grid gap-2 sm:grid-cols-2">
          <input
            value={ident.name}
            onChange={(e) =>
              setIdent({ ...ident, name: e.target.value })
            }
            placeholder={t.namePh}
            maxLength={30}
            aria-label={t.namePh}
            className="rounded-xl border border-line bg-white px-3 py-2 text-sm outline-none placeholder:text-neutral-500 focus:border-saba"
          />
          <input
            value={ident.email}
            onChange={(e) =>
              setIdent({ ...ident, email: e.target.value })
            }
            placeholder={t.emailPh}
            type="email"
            aria-label={t.emailPh}
            className="rounded-xl border border-line bg-white px-3 py-2 text-sm outline-none placeholder:text-neutral-500 focus:border-saba"
          />
        </div>
        {!canSend && ident.name.trim().length < 2 ? (
          <p className="text-xs text-muted">{t.needName}</p>
        ) : null}
        <div className="flex gap-2">
          <textarea
            value={text}
            onChange={(e) => setText(e.target.value)}
            placeholder={t.textPh}
            rows={2}
            maxLength={500}
            aria-label={t.textPh}
            className="w-full resize-none rounded-xl border border-line bg-white px-3 py-2 text-sm outline-none placeholder:text-neutral-500 focus:border-saba"
          />
          <button
            type="button"
            onClick={send}
            disabled={!canSend}
            aria-label={t.send}
            title={t.send}
            className={`h-10 w-10 shrink-0 self-end rounded-full transition-colors ${
              canSend
                ? "bg-saba text-white hover:bg-[#0064e0]"
                : "cursor-not-allowed bg-canvas text-neutral-400"
            }`}
          >
            <span aria-hidden className="text-base leading-none">
              ➤
            </span>
          </button>
        </div>
      </div>
    </section>
  );
}
