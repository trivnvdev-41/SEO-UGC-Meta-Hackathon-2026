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

  it("list bintang dan bernomor dirender, bukan literal", () => {
    const star = html("* satu\n* dua");
    expect(star).toContain("<ul");
    expect(star).not.toContain("* satu");
    const num = html("1. satu\n2. dua");
    expect(num).toContain("<ol");
    expect(num).not.toContain("1. satu");
  });

  it("h3 dan quote dirender, bukan literal # dan >", () => {
    const h3 = html("### Sub");
    expect(h3).toContain("<h3>");
    expect(h3).not.toContain("###");
    const q = html("> Catatan penting");
    expect(q).toContain("<blockquote");
    expect(q).not.toContain("&gt; Catatan");
  });

  it("HTML mentah dari model di-escape, tidak dieksekusi", () => {
    const out = html('<img src=x onerror="alert(1)">');
    expect(out).not.toContain("<img");
    expect(out).toContain("&lt;img");
  });

  it("tabel GFM jadi <table> dengan thead/tbody", () => {
    const out = html("| A | B |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |");
    expect(out).toContain("<table");
    expect(out).toContain("<th");
    expect(out.match(/<td/g)?.length).toBe(4);
  });

  it("baris pipa tanpa delimiter bukan tabel, pipa dibuang", () => {
    const out = html("| A | B |\n| 1 | 2 |");
    expect(out).not.toContain("<table");
    expect(out).not.toContain("|");
  });

  it("heading tanpa baris kosong tetap jadi heading, bukan literal ###", () => {
    const out = html("### Kelebihan Produk\nIsi langsung tanpa jeda.");
    expect(out).toContain("<h3>");
    expect(out).toContain("Kelebihan Produk");
    expect(out).not.toContain("###");
    expect(out).toContain("<p ");
  });

  it("#### dan ## tanpa spasi tetap jadi heading; #hashtag bukan", () => {
    expect(html("#### Dalam")).toContain("<h3>");
    expect(html("##Sub")).toContain("<h2>");
    expect(html("##Sub")).not.toContain("##Sub");
    const tag = html("#hashtag populer");
    expect(tag).not.toContain("<h2>");
    expect(tag).toContain("#hashtag");
  });

  it("garis pemisah (--, ---, ***) tidak dirender", () => {
    expect(html("atas\n\n---\n\nbawah")).not.toContain("---");
    expect(html("atas\n\n--\n\nbawah")).not.toContain("--");
    expect(html("atas\n\n***\n\nbawah")).not.toContain("***");
  });

  it("tabel tanpa pipe tepi tetap jadi tabel", () => {
    const out = html("A | B\n--- | ---\n1 | 2");
    expect(out).toContain("<table");
    expect(out).not.toContain("---");
  });

  it("-- diapit spasi jadi em dash, URL tak tersentuh", () => {
    const out = html("murah -- tapi bagus [x](https://contoh.test/a--b)");
    expect(out).toContain("murah — tapi bagus");
    expect(out).toContain('href="https://contoh.test/a--b"');
  });

  it("quote tanpa garis vertikal (kartu, bukan border kiri)", () => {
    const out = html("> Catatan penting");
    expect(out).toContain("<blockquote");
    expect(out).not.toContain("border-l");
  });
});
