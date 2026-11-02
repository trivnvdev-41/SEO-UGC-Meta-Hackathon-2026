"use client";

import { useEffect, useState } from "react";

type Item = { name: string; text: string; at: number };

const itemsKey = (id: string) => `saba-comments:${id}`;
const identKey = "saba-identity";
const nameId = "saba-comment-name";

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
  handle,
  t,
}: {
  id: string;
  lang: "id" | "en";
  handle: string;
  t: {
    title: string;
    empty: string;
    namePh: string;
    textPh: string;
    send: string;
    needName: string;
  };
}) {
  const [items, setItems] = useState<Item[]>([]);
  const [name, setName] = useState("");
  const [text, setText] = useState("");
  const [hint, setHint] = useState(false);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    setItems(loadItems(id));
    try {
      const raw = localStorage.getItem(identKey);
      if (raw) {
        const ident = JSON.parse(raw) as { name?: unknown };
        if (typeof ident.name === "string") setName(ident.name);
      }
    } catch {
      /* abaikan */
    }
    setReady(true);
  }, [id]);

  const nameOk = name.trim().length >= 2;

  function send() {
    if (text.trim().length === 0) return;
    if (!nameOk) {
      setHint(true);
      document.getElementById(nameId)?.focus();
      return;
    }
    const item = { name: name.trim(), text: text.trim().slice(0, 500), at: Date.now() };
    const next = [item, ...items];
    setItems(next);
    try {
      localStorage.setItem(itemsKey(id), JSON.stringify(next));
      localStorage.setItem(identKey, JSON.stringify({ name: name.trim() }));
    } catch {
      /* mode privat: tampil sesi ini saja */
    }
    setText("");
    setHint(false);
  }

  if (!ready) return null;

  return (
    <section aria-label={t.title}>
      <div className="flex items-center gap-2">
        <h2 className="mt-0 text-[17px] font-bold">{t.title}</h2>
        <span className="rounded-full bg-canvas px-2 py-0.5 text-[11px] font-bold text-[#424656]">
          {items.length}
        </span>
      </div>

      <div className="mt-3">
        <input
          id={nameId}
          value={name}
          onChange={(e) => {
            setName(e.target.value);
            if (e.target.value.trim().length >= 2) setHint(false);
          }}
          placeholder={t.namePh}
          maxLength={30}
          aria-label={t.namePh}
          className="w-full rounded-full border border-line bg-white px-3.5 py-2 text-sm outline-none placeholder:text-neutral-500 focus:border-saba"
        />
        {hint && !nameOk ? (
          <p className="mt-1 text-xs text-[#CF3A3A]">{t.needName}</p>
        ) : null}
      </div>

      {items.length === 0 ? (
        <p className="mt-3 text-sm text-muted">{t.empty}</p>
      ) : (
        <ul className="mt-3 grid list-none gap-2.5 p-0">
          {items.map((c, i) => (
            <li
              key={`${c.at}-${i}`}
              className="rounded-xl bg-canvas p-3"
            >
              <p className="flex items-center gap-2">
                <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-saba-soft text-sm font-bold text-saba">
                  {c.name.charAt(0).toUpperCase()}
                </span>
                <span className="min-w-0">
                  <span className="block truncate text-[15px] font-bold">
                    {c.name}
                  </span>
                  <span className="block text-[13px] text-[#727687]">
                    {timeAgo(c.at, lang)}
                  </span>
                </span>
              </p>
              <p className="mt-1.5 text-[15px] leading-relaxed whitespace-pre-wrap">
                {c.text}
              </p>
            </li>
          ))}
        </ul>
      )}

      <div className="sticky bottom-2 z-10 mt-3 flex items-center gap-1.5 rounded-full border border-line bg-white/90 p-1.5 pl-3.5 shadow-md backdrop-blur">
        <input
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") send();
          }}
          placeholder={t.textPh}
          maxLength={500}
          aria-label={t.textPh}
          className="w-full bg-transparent text-sm outline-none placeholder:text-neutral-500"
        />
        <button
          type="button"
          onClick={send}
          aria-label={t.send}
          title={t.send}
          className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-saba text-white"
        >
          <span aria-hidden className="text-base leading-none">
            ➤
          </span>
        </button>
      </div>
      <p className="mt-1 text-center text-[11px] text-muted">
        {lang === "en"
          ? `Replying as ${name.trim() || "…"}`
          : `Menjawab sebagai ${name.trim() || "…"} • @${handle}`}
      </p>
    </section>
  );
}
