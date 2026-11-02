import * as React from "react";
import type { SVGProps } from "react";
import { memo } from "react";
const SvgContainer16 = (props: SVGProps<SVGSVGElement>) => (
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
    <path
      fill="#F0F2F5"
      d="M18 2c6.627 0 12 5.373 12 12s-5.373 12-12 12S6 20.627 6 14 11.373 2 18 2"
    />
    <g clipPath="url(#container-16_svg__a)">
      <path
        stroke="#8590A6"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={1.333}
        d="M23.334 20v-1.333A2.67 2.67 0 0 0 20.667 16h-5.333a2.67 2.67 0 0 0-2.667 2.667V20"
      />
    </g>
    <g clipPath="url(#container-16_svg__a)">
      <path
        stroke="#8590A6"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={1.333}
        d="M15.333 10.667A2.67 2.67 0 0 0 18 13.333a2.67 2.67 0 0 0 2.666-2.666A2.67 2.67 0 0 0 18 8a2.67 2.67 0 0 0-2.667 2.667"
      />
    </g>
    <path
      stroke="#D5DCE5"
      d="M6.5 14C6.5 7.649 11.649 2.5 18 2.5S29.5 7.649 29.5 14 24.351 25.5 18 25.5 6.5 20.351 6.5 14Z"
    />
    <defs>
      <clipPath id="container-16_svg__b">
        <path d="M18 2c6.627 0 12 5.373 12 12s-5.373 12-12 12S6 20.627 6 14 11.373 2 18 2" />
      </clipPath>
      <clipPath id="container-16_svg__a" clipPath="url(#container-16_svg__b)">
        <path d="M10 6h16v16H10Z" />
      </clipPath>
    </defs>
  </svg>
);
const Memo = memo(SvgContainer16);
export default Memo;
