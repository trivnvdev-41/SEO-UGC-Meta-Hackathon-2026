import * as React from "react";
import type { SVGProps } from "react";
import { memo } from "react";
const SvgFrostedGlassNavigationBarOptimizedForMobileIosSafeBottom = (
  props: SVGProps<SVGSVGElement>
) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    width="1em"
    height="1em"
    fill="none"
    viewBox="0 0 116 116"
    {...props}
  >
    <g filter="url(#frosted-glass-navigation-bar-optimized-for-mobile-ios-safe-bottom_svg__a)">
      <path
        fill="#0866FF"
        d="M58 22c15.464 0 28 12.536 28 28S73.464 78 58 78 30 65.464 30 50s12.536-28 28-28"
      />
      <path
        fill="#FFF"
        d="M67.375 50q0 .469-.328.797a1.08 1.08 0 0 1-.797.328h-7.125v7.125q0 .469-.328.797a1.08 1.08 0 0 1-.797.328q-.468 0-.797-.328a1.08 1.08 0 0 1-.328-.797v-7.125H49.75q-.468 0-.797-.328a1.08 1.08 0 0 1-.328-.797q0-.468.328-.797.329-.328.797-.328h7.125V41.75q0-.468.328-.797.329-.328.797-.328t.797.328.328.797v7.125h7.125q.469 0 .797.328.328.329.328.797"
      />
      <path
        stroke="#FFF"
        strokeWidth={2}
        d="M31 50c0-14.912 12.088-27 27-27s27 12.088 27 27-12.088 27-27 27-27-12.088-27-27Z"
      />
    </g>
    <defs>
      <filter
        id="frosted-glass-navigation-bar-optimized-for-mobile-ios-safe-bottom_svg__a"
        width={212}
        height={212}
        x={-48}
        y={-48}
        colorInterpolationFilters="sRGB"
        filterUnits="userSpaceOnUse"
      >
        <feOffset dy={8} in="SourceAlpha" />
        <feGaussianBlur stdDeviation={10} />
        <feColorMatrix
          result="s0"
          values="0 0 0 0 0.031 0 0 0 0 0.4 0 0 0 0 1 0 0 0 0.35 0"
        />
        <feComposite in="s0" in2="SourceAlpha" operator="out" result="s0" />
        <feMerge>
          <feMergeNode in="s0" />
          <feMergeNode in="SourceGraphic" />
        </feMerge>
      </filter>
    </defs>
  </svg>
);
const Memo = memo(SvgFrostedGlassNavigationBarOptimizedForMobileIosSafeBottom);
export default Memo;
