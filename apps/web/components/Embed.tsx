import Script from "next/script";
import { cn } from "@/lib/utils";
import { youtubeId } from "@/lib/video";

const TIKTOK_ID = /tiktok\.com\/@[^/]+\/(?:video|photo)\/(\d+)/;
const INSTAGRAM = /instagram\.com\/(?:reel|reels|p|tv)\/([\w-]+)/;

export function Embed({ url }: { url: string }) {
  const yt = youtubeId(url);
  if (yt) {
    return (
      <iframe
        className="my-4 aspect-video w-full rounded-lg border-0"
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
          className={cn("tiktok-embed my-4")}
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
          className="instagram-media my-4"
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
    <p className="my-4 font-sans text-sm">
      <a href={url} target="_blank" rel="noreferrer">
        Tonton video asli
      </a>
    </p>
  );
}
