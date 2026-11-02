import * as React from "react";
import type { SVGProps } from "react";
import { memo } from "react";
const SvgButtonSimpan = (props: SVGProps<SVGSVGElement>) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    width="1em"
    height="1em"
    fill="none"
    viewBox="0 0 32 32"
    {...props}
  >
    <path
      transform="matrix(1 0 0 1 10.75 9.25)"
      d="M0 13.5L0 1.5C0 1.088 0.147 0.734 0.441 0.441C0.734 0.147 1.088 0 1.5 0L9 0C9.412 0 9.766 0.147 10.059 0.441C10.353 0.734 10.5 1.088 10.5 1.5L10.5 13.5L5.25 11.25L0 13.5ZM1.5 11.212L5.25 9.6L9 11.212L9 1.5L1.5 1.5L1.5 11.212Z"
      fill="#727687"
    />
  </svg>
);
const Memo = memo(SvgButtonSimpan);
export default Memo;
