import * as React from "react";
import type { SVGProps } from "react";
import { memo } from "react";
const SvgContainer15 = (props: SVGProps<SVGSVGElement>) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    width="1em"
    height="1em"
    fill="none"
    viewBox="0 0 36 28"
    {...props}
  >
    <path
      fill="#F0F2F5"
      d="M14 0h8c7.732 0 14 6.268 14 14s-6.268 14-14 14h-8C6.268 28 0 21.732 0 14S6.268 0 14 0"
    />
    <g clipPath="url(#container-15_svg__a)">
      <path
        stroke="#8590A6"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={1.667}
        d="M25.5 13.583a7 7 0 0 1-.75 3.167 7.08 7.08 0 0 1-6.333 3.917 7 7 0 0 1-3.167-.75L10.5 21.5l1.583-4.75a7 7 0 0 1-.75-3.167A7.08 7.08 0 0 1 15.25 7.25a7 7 0 0 1 3.167-.75h.416a7.066 7.066 0 0 1 6.667 6.667z"
      />
    </g>
    <path fill="#0866FF" d="M28 0a6 6 0 1 1 0 12 6 6 0 1 1 0-12" />
    <g filter="url(#container-15_svg__b)" opacity={0.3}>
      <path fill="#06F" d="M28 2a4 4 0 0 1 0 8 4 4 0 0 1 0-8" />
      <path
        stroke="#06F"
        strokeWidth={2}
        d="M28 2a4 4 0 0 1 0 8 4 4 0 0 1 0-8Z"
      />
    </g>
    <path fill="none" d="M28 2a4 4 0 0 1 0 8 4 4 0 0 1 0-8" />
    <path
      stroke="#FFF"
      strokeWidth={2}
      d="M23 6a5 5 0 0 1 10 0 5 5 0 0 1-10 0Z"
    />
    <defs>
      <clipPath id="container-15_svg__a">
        <path d="M8 4h20v20H8Z" />
      </clipPath>
      <filter
        id="container-15_svg__b"
        width={20}
        height={20}
        x={18}
        y={-4}
        colorInterpolationFilters="sRGB"
        filterUnits="userSpaceOnUse"
      >
        <feImage
          width={10}
          height={10}
          x={23}
          y={1}
          href="data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjIzIDEgMTAgMTAiIHdpZHRoPSIxMCIgaGVpZ2h0PSIxMCI+PHBhdGggdHJhbnNmb3JtPSJtYXRyaXgoMSAwIDAgMSAyNCAyKSIgZD0iTTQgMEw0IDBDNi4yMDkgMCA4IDEuNzkxIDggNEw4IDRMOCA0QzggNi4yMDkgNi4yMDkgOCA0IDhMNCA4TDQgOEMxLjc5MSA4IDAgNi4yMDkgMCA0TDAgNEwwIDRDMCAxLjc5MSAxLjc5MSAwIDQgMEw0IDBaIi8+PC9zdmc+"
          preserveAspectRatio="none"
          result="cover"
        />
        <feComposite in="SourceGraphic" in2="cover" operator="out" />
      </filter>
    </defs>
  </svg>
);
const Memo = memo(SvgContainer15);
export default Memo;
