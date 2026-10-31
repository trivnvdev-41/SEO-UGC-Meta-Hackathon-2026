import { createElement, type ReactNode } from "react";

// Markdown minimal: heading, list, quote, bold, link. Teks dirender sebagai
// node React (auto-escaped), jadi tidak ada HTML mentah dari output model.
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
  // shortcut: renderer md minimal (heading + list + quote + bold/link),
  // ganti markdown lib saat butuh tabel/gfm.
  return md.split("\n\n").map((block, i) => {
    const lines = block.split("\n");
    const heading = block.match(/^(#{1,3}) (.*)$/);
    if (heading) {
      // H1 sudah dipakai judul artikel, jadi #/## dari model jadi h2, ### jadi h3.
      const text = heading[2];
      return createElement(
        heading[1].length >= 3 ? "h3" : "h2",
        { key: i },
        ...inline(text, `h${i}`),
      );
    }
    const bullet = (l: string) => l.startsWith("- ") || l.startsWith("* ");
    if (lines.every(bullet)) {
      return createElement(
        "ul",
        { key: i, className: "my-3 list-disc space-y-1 pl-5" },
        ...lines.map((li, j) =>
          createElement("li", { key: j }, ...inline(li.slice(2), `l${i}-${j}`)),
        ),
      );
    }
    if (lines.every((l) => /^\d+\. /.test(l))) {
      return createElement(
        "ol",
        { key: i, className: "my-3 list-decimal space-y-1 pl-5" },
        ...lines.map((li, j) =>
          createElement(
            "li",
            { key: j },
            ...inline(li.replace(/^\d+\. /, ""), `o${i}-${j}`),
          ),
        ),
      );
    }
    if (lines.every((l) => l.startsWith("> "))) {
      return createElement(
        "blockquote",
        {
          key: i,
          className: "my-3 border-l-4 pl-4 italic opacity-90",
        },
        ...inline(
          lines.map((l) => l.slice(2)).join("\n"),
          `q${i}`,
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
