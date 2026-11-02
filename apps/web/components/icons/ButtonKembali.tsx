import * as React from "react";
import type { SVGProps } from "react";
import { memo } from "react";
const SvgButtonKembali = (props: SVGProps<SVGSVGElement>) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    width="1em"
    height="1em"
    fill="none"
    viewBox="4 14 16 16"
    {...props}
  >
    <path
      transform="matrix(1 0 0 1 4.01 14)"
      d="M3.825 9L9.425 14.6L8 16L0 8L8 0L9.425 1.4L3.825 7L16 7L16 9L3.825 9L3.825 9Z"
      fill="#1C1B1B"
    />
  </svg>
);
const Memo = memo(SvgButtonKembali);
export default Memo;
