import * as React from "react";
import type { SVGProps } from "react";
import { memo } from "react";
const SvgBackground = (props: SVGProps<SVGSVGElement>) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    width="1em"
    height="1em"
    fill="none"
    viewBox="0 0 36 28"
    {...props}
  >
    <path
      fill="#EFF6FF"
      d="M14 0h8c7.732 0 14 6.268 14 14s-6.268 14-14 14h-8C6.268 28 0 21.732 0 14S6.268 0 14 0"
    />
    <g clipPath="url(#background_svg__a)" opacity={0.15}>
      <path
        fill="#0866FF"
        d="m18 6.242 4.716 4.717a6.666 6.666 0 0 1-9.43 9.426 6.667 6.667 0 0 1-.003-9.426z"
      />
    </g>
    <g clipPath="url(#background_svg__a)">
      <path
        fill="#0866FF"
        d="M18 6.5 9.667 14h2.5v6.667c0 .46.373.833.833.833h3.334v-5h3.333v5H23a.833.833 0 0 0 .834-.833V14h2.5z"
      />
    </g>
    <defs>
      <clipPath id="background_svg__a">
        <path d="M8 4h20v20H8Z" />
      </clipPath>
    </defs>
  </svg>
);
const Memo = memo(SvgBackground);
export default Memo;
