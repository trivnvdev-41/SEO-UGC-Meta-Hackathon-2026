import Script from "next/script";

const TIKTOK_ID = /tiktok\.com\/@[^/]+\/(?:video|photo)\/(\d+)/;
const INSTAGRAM = /instagram\.com\/(?:reel|reels|p|tv)\/([\w-]+)/;

export function Embed({ url }: { url: string }) {
  const tiktok = url.match(TIKTOK_ID);
  if (tiktok) {
    return (
      <>
        <blockquote
          className="tiktok-embed"
          cite={url}
          data-video-id={tiktok[1]}
        >
          <section>
            <a target="_blank" rel="noreferrer" href={url}>
              Tonton video asli di TikTok
            </a>
          </section>
        </blockquote>
        <Script async src="https://www.tiktok.com/embed.js" />
      </>
    );
  }

  if (INSTAGRAM.test(url)) {
    return (
      <>
        <blockquote
          className="instagram-media"
          data-instgrm-permalink={url}
          data-instgrm-version="14"
        >
          <a target="_blank" rel="noreferrer" href={url}>
            Tonton video asli di Instagram
          </a>
        </blockquote>
        <Script async src="https://www.instagram.com/embed.js" />
      </>
    );
  }

  // URL short (vt.tiktok.com) / tanpa id: jangan render widget rusak.
  return (
    <p>
      <a href={url} target="_blank" rel="noreferrer">
        Tonton video asli
      </a>
    </p>
  );
}
