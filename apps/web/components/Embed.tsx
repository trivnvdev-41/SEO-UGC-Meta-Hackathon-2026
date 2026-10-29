import Script from "next/script";

export function Embed({ url }: { url: string }) {
  if (url.includes("tiktok.com")) {
    return (
      <>
        <blockquote className="tiktok-embed" cite={url} data-video-id="">
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
  if (url.includes("instagram.com")) {
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
  return (
    <p>
      <a href={url} target="_blank" rel="noreferrer">
        Tonton video asli
      </a>
    </p>
  );
}
