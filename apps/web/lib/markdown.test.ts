import { createElement, Fragment } from "react";
import { describe, expect, it } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import { renderMd } from "./markdown";

const html = (md: string) =>
  renderToStaticMarkup(createElement(Fragment, null, ...renderMd(md)));

describe("renderMd", () => {
  it("bold jadi <strong>, bukan bintang literal", () => {
    const out = html("Bahan **solid** sekali");
    expect(out).toContain("<strong");
    expect(out).toContain("solid");
    expect(out).not.toContain("**");
  });

  it("link markdown jadi <a> dengan rel aman", () => {
    const out = html("Lihat [sumber](https://contoh.test/klaim)");
    expect(out).toContain('href="https://contoh.test/klaim"');
    expect(out).toContain('rel="nofollow noopener"');
  });

  it("H1 dari model jadi h2 (judul artikel tetap satu h1)", () => {
    expect(html("# Judul")).toContain("<h2>");
    expect(html("# Judul")).not.toContain("<h1>");
  });

  it("list jadi <ul>", () => {
    const out = html("- satu\n- dua");
    expect(out).toContain("<ul");
    expect(out.match(/<li/g)?.length).toBe(2);
  });

  it("HTML mentah dari model di-escape, tidak dieksekusi", () => {
    const out = html('<img src=x onerror="alert(1)">');
    expect(out).not.toContain("<img");
    expect(out).toContain("&lt;img");
  });
});
