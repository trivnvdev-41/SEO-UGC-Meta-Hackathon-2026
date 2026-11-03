import { createElement, type ReactNode } from "react";

// Markdown minimal: heading, list, quote, bold, link. Teks dirender sebagai
// node React (auto-escaped), jadi tidak ada HTML mentah dari output model.
// Tahan banting: heading tanpa spasi/level 4, tabel tanpa pipe tepi,
// hr lone (--, ---) dibuang, "--" spasi jadi em dash.
const emDash = (s: string) => s.replace(/(\s)--(\s)/g, "$1—$2");

export function inline(text: string, keyPrefix: string): ReactNode[] {
  const out: ReactNode[] = [];
  const re = /\*\*(.+?)\*\*|\[([^\]]+)\]\((https?:\/\/[^)\s]+)\)/g;
  let last = 0;
  let m: RegExpExecArray | null;
  let i = 0;
  while ((m = re.exec(text)) !== null) {
    if (m.index > last) out.push(emDash(text.slice(last, m.index)));
    out.push(
      m[1]
          ? createElement(
              "strong",
              { key: `${keyPrefix}-b${i}`, className: "font-bold" },
              emDash(m[1]),
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
  if (last < text.length) out.push(emDash(text.slice(last)));
  return out;
}

// Baris pemisah ala markdown (---, ***, ___, --, ===): tidak dirender sama
// sekali agar tak ada simbol nyasar di artikel.
const HR_RE = /^\s*([-*_=])(\s*\1){1,}\s*$/;

// Heading: `#/##/###/####` + spasi (normal), atau `##+` tanpa spasi.
// `#` tunggal tanpa spasi dianggap hashtag biasa, bukan heading.
const HEADING_RE = /^(#{1,4})\s+(.*)$|^(#{2,4})(\S.*)$/;

// Sel tabel: pisah `|`, toleran tanpa pipe tepi.
const cells = (l: string) =>
  l
    .trim()
    .replace(/^\||\|$/g, "")
    .split("|")
    .map((c) => c.trim());

// Baris delimiter tabel: hanya berisi |, spasi, :, - dan minimal satu -.
const isDelim = (l: string) => {
  const t = l.trim();
  return t.includes("-") && t.includes("|") && /^[|\s:-]+$/.test(t);
};

function tableNode(head: string[], rows: string[][], key: string): ReactNode {
  return createElement(
    "div",
    { key, className: "my-3 overflow-x-auto" },
    createElement(
      "table",
      { className: "w-full border-collapse text-sm" },
      createElement(
        "thead",
        null,
        createElement(
          "tr",
          null,
          ...head.map((h, j) =>
            createElement(
              "th",
              {
                key: j,
                className:
                  "border border-line bg-canvas px-2.5 py-1.5 text-left font-bold",
              },
              ...inline(h, `${key}-h${j}`),
            ),
          ),
        ),
      ),
      createElement(
        "tbody",
        null,
        ...rows.map((r, k) =>
          createElement(
            "tr",
            { key: k },
            ...r.map((c, j) =>
              createElement(
                "td",
                {
                  key: j,
                  className: "border border-line px-2.5 py-1.5 align-top",
                },
                ...inline(c, `${key}-${k}-${j}`),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

export function renderMd(md: string): ReactNode[] {
  const lines = md.split("\n");
  const out: ReactNode[] = [];
  let i = 0;
  const key = () => `b${out.length}`;
  const bullet = (l: string) => l.startsWith("- ") || l.startsWith("* ");

  while (i < lines.length) {
    // Lewati baris kosong dan garis pemisah (---, --, ***, ===).
    if (lines[i].trim() === "" || HR_RE.test(lines[i])) {
      i += 1;
      continue;
    }
    const hm = lines[i].match(HEADING_RE);
    if (hm) {
      // H1 sudah dipakai judul artikel, jadi #/## dari model jadi h2, ###+ jadi h3.
      const hashes = hm[1] ?? hm[3];
      const text = (hm[2] ?? hm[4] ?? "").trim();
      out.push(
        createElement(
          hashes.length >= 3 ? "h3" : "h2",
          { key: key() },
          ...inline(text || lines[i].replace(/^#+/, "").trim(), key()),
        ),
      );
      i += 1;
      continue;
    }
    // Tabel GFM: baris berisi `|` + baris delimiter (boleh tanpa pipe tepi).
    if (lines[i].includes("|")) {
      const head = cells(lines[i]);
      const delimIdx = lines
        .slice(i + 1, i + 3)
        .findIndex((l) => isDelim(l));
      if (head.length > 1 && delimIdx >= 0) {
        const rows: string[][] = [];
        let j = i + 1 + delimIdx + 1;
        while (j < lines.length && lines[j].includes("|") && !isDelim(lines[j])) {
          rows.push(cells(lines[j]));
          j += 1;
        }
        out.push(tableNode(head, rows, key()));
        i = j;
        continue;
      }
    }
    if (bullet(lines[i])) {
      const items: string[] = [];
      while (i < lines.length && bullet(lines[i])) {
        items.push(lines[i].slice(2));
        i += 1;
      }
      const k = key();
      out.push(
        createElement(
          "ul",
          { key: k, className: "my-3 list-disc space-y-1 pl-5" },
          ...items.map((li, j) =>
            createElement("li", { key: j }, ...inline(li, `${k}-${j}`)),
          ),
        ),
      );
      continue;
    }
    if (/^\d+\. /.test(lines[i])) {
      const items: string[] = [];
      while (i < lines.length && /^\d+\. /.test(lines[i])) {
        items.push(lines[i].replace(/^\d+\. /, ""));
        i += 1;
      }
      const k = key();
      out.push(
        createElement(
          "ol",
          { key: k, className: "my-3 list-decimal space-y-1 pl-5" },
          ...items.map((li, j) =>
            createElement("li", { key: j }, ...inline(li, `${k}-${j}`)),
          ),
        ),
      );
      continue;
    }
    if (lines[i].startsWith("> ")) {
      const quotes: string[] = [];
      while (i < lines.length && lines[i].startsWith("> ")) {
        quotes.push(lines[i].slice(2));
        i += 1;
      }
      const k = key();
      out.push(
        createElement(
          "blockquote",
          {
            key: k,
            className: "my-3 rounded-xl bg-canvas px-4 py-3 italic",
          },
          ...inline(quotes.join("\n"), k),
        ),
      );
      continue;
    }
    // Paragraf: gabung baris biasa berurutan (tanpa baris kosong).
    const paras: string[] = [];
    while (
      i < lines.length &&
      lines[i].trim() !== "" &&
      !HR_RE.test(lines[i]) &&
      !HEADING_RE.test(lines[i]) &&
      !lines[i].includes("|") &&
      !bullet(lines[i]) &&
      !/^\d+\. /.test(lines[i]) &&
      !lines[i].startsWith("> ")
    ) {
      paras.push(lines[i]);
      i += 1;
    }
    if (paras.length > 0) {
      const k = key();
      out.push(
        createElement(
          "p",
          { key: k, className: "my-3" },
          ...inline(paras.join("\n"), k),
        ),
      );
      continue;
    }
    // Pengaman: baris tak dikenali (mis. sel tabel yatim tanpa delimiter)
    // ditampilkan sebagai teks biasa TANPA karakter `|` agar bersih.
    const k = key();
    out.push(
      createElement(
        "p",
        { key: k, className: "my-3" },
        ...inline(lines[i].replaceAll("|", " ").replace(/\s+/g, " ").trim(), k),
      ),
    );
    i += 1;
  }
  return out;
}
