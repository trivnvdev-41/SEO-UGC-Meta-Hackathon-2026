import * as React from "react";
import type { SVGProps } from "react";
import { memo } from "react";
const SvgButtonNotifikasi = (props: SVGProps<SVGSVGElement>) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    width="1em"
    height="1em"
    fill="none"
    viewBox="0 0 36 46"
    {...props}
  >
    <path
      fill="#444"
      d="M25.324 25.75q-.312-.566-.693-2.061-.381-1.494-.381-3.564a6.2 6.2 0 0 0-1.826-4.424A6.2 6.2 0 0 0 18 13.875a6.2 6.2 0 0 0-4.424 1.826 6.2 6.2 0 0 0-1.826 4.424q0 2.07-.381 3.564t-.693 2.061a1.5 1.5 0 0 0-.127.293 1.202 1.202 0 0 0 .322 1.211q.37.37.879.371h3.184a3.15 3.15 0 0 0 1.084 1.787 3 3 0 0 0 1.982.713 3 3 0 0 0 1.982-.713 3.14 3.14 0 0 0 1.084-1.767v-.02h3.184q.508 0 .879-.371a1.2 1.2 0 0 0 .322-1.211 2 2 0 0 0-.127-.313zM18 28.875a1.78 1.78 0 0 1-1.084-.352 1.9 1.9 0 0 1-.674-.878v-.02h3.516q-.195.547-.674.898a1.78 1.78 0 0 1-1.084.352m-6.25-2.5q.234-.39.449-1.016a14.3 14.3 0 0 0 .684-3.222A17 17 0 0 0 13 20.125q0-1.035.391-1.953a5.1 5.1 0 0 1 1.074-1.582 5.1 5.1 0 0 1 1.582-1.074A4.9 4.9 0 0 1 18 15.125q1.035 0 1.953.391.898.39 1.582 1.074t1.074 1.582q.391.918.391 1.953 0 1.055.117 2.012.098.976.283 1.787.186.81.401 1.435.215.626.449 1.016z"
    />
    <path fill="#0866FF" d="M25 4a7 7 0 1 1 0 14 7 7 0 1 1 0-14" />
    <g filter="url(#button-notifikasi_svg__a)" opacity={0.3}>
      <path fill="#06F" d="M25 6a5 5 0 0 1 0 10 5 5 0 0 1 0-10" />
      <path
        stroke="#06F"
        strokeWidth={2}
        d="M25 6a5 5 0 0 1 0 10 5 5 0 0 1 0-10Z"
      />
    </g>
    <path fill="none" d="M25 6a5 5 0 0 1 0 10 5 5 0 0 1 0-10" />
    <path
      stroke="#FFF"
      strokeWidth={2}
      d="M19 11a6 6 0 1 1 12 0 6 6 0 1 1-12 0Z"
    />
    <defs>
      <filter
        id="button-notifikasi_svg__a"
        width={22}
        height={22}
        x={14}
        y={0}
        colorInterpolationFilters="sRGB"
        filterUnits="userSpaceOnUse"
      >
        <feImage
          width={12}
          height={12}
          x={19}
          y={5}
          href="data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjE5IDUgMTIgMTIiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiI+PHBhdGggdHJhbnNmb3JtPSJtYXRyaXgoMSAwIDAgMSAyMCA2KSIgZD0iTTUgMEw1IDBDNy43NjEgMCAxMCAyLjIzOSAxMCA1TDEwIDVMMTAgNUMxMCA3Ljc2MSA3Ljc2MSAxMCA1IDEwTDUgMTBMNSAxMEMyLjIzOSAxMCAwIDcuNzYxIDAgNUwwIDVMMCA1QzAgMi4yMzkgMi4yMzkgMCA1IDBMNSAwWiIvPjwvc3ZnPg=="
          preserveAspectRatio="none"
          result="cover"
        />
        <feComposite in="SourceGraphic" in2="cover" operator="out" />
      </filter>
    </defs>
  </svg>
);
const Memo = memo(SvgButtonNotifikasi);
export default Memo;
