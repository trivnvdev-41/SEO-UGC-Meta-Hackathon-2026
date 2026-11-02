import * as React from "react";
import type { SVGProps } from "react";
import { memo } from "react";
const SvgContainer10 = (props: SVGProps<SVGSVGElement>) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    width="1em"
    height="1em"
    fill="none"
    viewBox="0 0 10.5 13.5"
    {...props}
  >
    <path
      fill="#727687"
      d="M0 13.5v-12Q0 .881.441.441A1.44 1.44 0 0 1 1.5 0H9q.619 0 1.059.441.441.44.441 1.059v12l-5.25-2.25zm1.5-2.288L5.25 9.6 9 11.212V1.5H1.5zm0-9.712H9 1.5"
    />
  </svg>
);
const Memo = memo(SvgContainer10);
export default Memo;
