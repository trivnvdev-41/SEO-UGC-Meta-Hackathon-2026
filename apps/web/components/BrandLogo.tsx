/// Header brand logo (SABA lockup). Shared by home/article/creator headers.
export function BrandLogo({ width = 86 }: { width?: number }) {
  return (
    <img
      src="/logo.png"
      alt="SABA"
      width={width}
      height={Math.round((width * 533) / 1600)}
      className="block h-auto"
      loading="eager"
    />
  );
}
