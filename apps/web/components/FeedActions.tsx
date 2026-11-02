"use client";

import { useEffect, useState } from "react";
import {
  Button as IconShare,
  ButtonKurangSetuju as IconDownOn,
  ButtonKurangSetuju2 as IconDownOff,
  Container15 as IconComment,
} from "@/components/icons";
import type { Votes } from "@/lib/articles";

const lsGet = (k: string): string[] => {
  try {
    const v = JSON.parse(localStorage.getItem(k) ?? "[]");
    return Array.isArray(v) ? v.map(String) : [];
  } catch {
    return [];
  }
};

const commentsKey = (id: string) => `saba-comments:${id}`;

// Panah atas + bookmark tidak ada di aset mockup: 2 path minimal,
// gaya stroke #727687 disamakan ikon lain.
function IconUp({ active }: { active: boolean }) {
  return (
    <svg viewBox="0 0 16 16" width="14" height="14" aria-hidden fill="none">
      <path
        d="M8 13V3M3.5 7.5L8 3l4.5 4.5"
        stroke={active ? "#fff" : "#0866FF"}
        strokeWidth={2}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function IconBookmark({ active }: { active: boolean }) {
  return (
    <svg viewBox="0 0 16 16" width="15" height="15" aria-hidden fill="none">
      <path
        d="M4 2h8v12l-4-3-4 3z"
        stroke={active ? "#0866FF" : "#727687"}
        strokeWidth={1.67}
        strokeLinejoin="round"
        fill={active ? "#0866FF" : "none"}
        opacity={active ? 0.25 : 1}
      />
    </svg>
  );
}

export function FeedActions({
  id,
  initial,
  path,
  lang,
  t,
}: {
  id: string;
  initial: Votes;
  path: string;
  lang: "id" | "en";
  t: { copied: string };
}) {
  const [votes, setVotes] = useState({ up: initial.up, down: initial.down, score: initial.score });
  const [mine, setMine] = useState<1 | -1 | 0>(initial.myVote);
  const [comments, setComments] = useState(0);
  const [saved, setSaved] = useState(false);
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    try {
      const items = localStorage.getItem(commentsKey(id));
      setComments(items ? (JSON.parse(items) as unknown[]).length : 0);
    } catch {
      setComments(0);
    }
    setSaved(lsGet("saba-bookmarks").includes(id));
  }, [id]);

  async function vote(v: 1 | -1) {
    const next = mine === v ? 0 : v;
    const prev = { ...votes, my: mine };
    const du = (next === 1 ? 1 : 0) - (mine === 1 ? 1 : 0);
    const dd = (next === -1 ? 1 : 0) - (mine === -1 ? 1 : 0);
    setMine(next);
    setVotes({ up: votes.up + du, down: votes.down + dd, score: votes.score + du - dd });
    try {
      // Same-origin via Caddy (/v1/* -> API); cookie saba_v ikut otomatis.
      const res = await fetch("/v1/votes", {
        method: "POST",
        headers: { "content-type": "application/json" },
        credentials: "include",
        body: JSON.stringify({ articleId: id, value: next }),
      });
      if (!res.ok) throw new Error(`vote_${res.status}`);
      const b = (await res.json()) as Votes;
      setVotes({ up: b.up, down: b.down, score: b.score });
      setMine(b.myVote);
    } catch {
      setVotes({ up: prev.up, down: prev.down, score: prev.up - prev.down });
      setMine(prev.my);
    }
  }

  function toggleSave() {
    const list = lsGet("saba-bookmarks");
    const has = list.includes(id);
    const next = has ? list.filter((x) => x !== id) : [...list, id];
    try {
      localStorage.setItem("saba-bookmarks", JSON.stringify(next));
    } catch {
      /* privat: sesi ini saja */
    }
    setSaved(!has);
  }

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
    <div className="mt-3 flex items-center gap-1.5 font-sans">
      <span className="flex items-center rounded-full bg-canvas p-1">
        <button
          type="button"
          onClick={() => vote(1)}
          aria-label="Setuju"
          className={`flex items-center gap-1 rounded-full px-2.5 py-1 text-[13px] font-semibold ${
            mine === 1 ? "bg-saba text-white" : "text-saba"
          }`}
        >
          <IconUp active={mine === 1} />
          {votes.up > 0 ? votes.up : lang === "en" ? "Up" : "Setuju"}
        </button>
        <button
          type="button"
          onClick={() => vote(-1)}
          aria-label="Kurang setuju"
          className="flex h-8 w-8 items-center justify-center rounded-full text-muted"
        >
          {mine === -1 ? (
            <IconDownOn width="1.5em" height="1.5em" />
          ) : (
            <IconDownOff width="1.5em" height="1.5em" />
          )}
        </button>
      </span>
      <span className="flex items-center gap-1 px-2 text-[13px] font-semibold text-muted">
        <IconComment width="1.4em" height="1.4em" />
        {comments > 0 ? comments : ""}
      </span>
      <span className="flex-1" />
      <button
        type="button"
        onClick={share}
        aria-label="Bagikan"
        className="flex h-8 w-8 items-center justify-center rounded-full text-muted"
      >
        {copied ? (
          <span className="text-xs font-bold text-saba">{t.copied}</span>
        ) : (
          <IconShare width="1.3em" height="1.3em" />
        )}
      </button>
      <button
        type="button"
        onClick={toggleSave}
        aria-label="Simpan"
        className="flex h-8 w-8 items-center justify-center rounded-full"
      >
        <IconBookmark active={saved} />
      </button>
    </div>
  );
}
