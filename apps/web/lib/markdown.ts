import { createElement, type ReactNode } from "react";

// Markdown minimal: heading, list, bold, link. Teks dirender sebagai node React
// (auto-escaped), jadi tidak ada HTML mentah dari output model.
export function inline(text: string, keyPrefix: string): ReactNode[] {
  const out: ReactNode[] = [];
  const re = /\*\*(.+?)\*\*|\[([^\]]+)\]\((https?:\/\/[^)\s]+)\)/g;
  let last = 0;
  let m: RegExpExecArray | null;
  let i = 0;
  while ((m = re.exec(text)) !== null) {
    if (m.index > last) out.push(text.slice(last, m.index));
    out.push(
      m[1]
        ? createElement(
            "strong",
            { key: `${keyPrefix}-b${i}`, className: "font-bold" },
            m[1],
          )
        : createElement(
            "a",
            {
              key: `${keyPrefix}-a${i}`,
              href: m[3],
              rel: "nofollow noopener",
            },
            m[2],
          ),
    );
    last = m.index + m[0].length;
    i += 1;
  }
  if (last < text.length) out.push(text.slice(last));
  return out;
}

export function renderMd(md: string): ReactNode[] {
  // shortcut: renderer md minimal (heading + list + bold/link),
  // ganti markdown lib saat butuh tabel/gfm.
  return md.split("\n\n").map((block, i) => {
    const lines = block.split("\n");
    if (block.startsWith("## ") || block.startsWith("# ")) {
      // H1 sudah dipakai judul artikel, jadi heading level 1 dari model jadi h2.
      const text = block.startsWith("## ") ? block.slice(3) : block.slice(2);
      return createElement("h2", { key: i }, ...inline(text, `h${i}`));
    }
    if (lines.every((l) => l.startsWith("- "))) {
      return createElement(
        "ul",
        { key: i, className: "my-3 list-disc space-y-1 pl-5" },
        ...lines.map((li, j) =>
          createElement("li", { key: j }, ...inline(li.slice(2), `l${i}-${j}`)),
        ),
      );
    }
    return createElement(
      "p",
      { key: i, className: "my-3" },
      ...inline(block, `p${i}`),
    );
  });
}
