import * as React from "react";
import type { SVGProps } from "react";
import { memo } from "react";
// Bubble komen bersih dari Container15: badge biru bawaan aset dibuang
// (di mock, ikon komen polos tanpa badge).
const SvgButtonKomentar = (props: SVGProps<SVGSVGElement>) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    width="1em"
    height="1em"
    fill="none"
    viewBox="6 2 24 24"
    {...props}
  >
    <path
      stroke="#727687"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth={1.667}
      d="M25.5 13.583a7 7 0 0 1-.75 3.167 7.08 7.08 0 0 1-6.333 3.917 7 7 0 0 1-3.167-.75L10.5 21.5l1.583-4.75a7 7 0 0 1-.75-3.167A7.08 7.08 0 0 1 15.25 7.25a7 7 0 0 1 3.167-.75h.416a7.066 7.066 0 0 1 6.667 6.667z"
    />
  </svg>
);
const Memo = memo(SvgButtonKomentar);
export default Memo;
