import Script from "next/script";

const TIKTOK_ID = /tiktok\.com\/@[^/]+\/(?:video|photo)\/(\d+)/;
const INSTAGRAM = /instagram\.com\/(?:reel|reels|p|tv)\/([\w-]+)/;
const YOUTUBE_ID = [
  /youtu\.be\/([\w-]{11})/,
  /youtube\.com\/(?:watch\?v=|shorts\/|embed\/)([\w-]{11})/,
];

function youtubeId(url: string): string | null {
  for (const re of YOUTUBE_ID) {
    const m = url.match(re);
    if (m) return m[1];
  }
  return null;
}

export function Embed({ url }: { url: string }) {
  const yt = youtubeId(url);
  if (yt) {
    return (
      <iframe
        className="embed-video"
        src={`https://www.youtube-nocookie.com/embed/${yt}`}
        title="Video YouTube"
        loading="lazy"
        allow="accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
        allowFullScreen
      />
    );
  }

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
