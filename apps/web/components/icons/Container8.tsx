import * as React from "react";
import type { SVGProps } from "react";
import { memo } from "react";
const SvgContainer8 = (props: SVGProps<SVGSVGElement>) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    width="1em"
    height="1em"
    fill="none"
    viewBox="0 0 12 12"
    {...props}
  >
    <path
      fill="#FFF"
      d="M5.25 12V2.869l-4.2 4.2L0 6l6-6 6 6-1.05 1.069-4.2-4.2V12z"
    />
  </svg>
);
const Memo = memo(SvgContainer8);
export default Memo;
