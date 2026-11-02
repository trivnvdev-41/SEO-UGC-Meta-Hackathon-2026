import * as React from "react";
import type { SVGProps } from "react";
import { memo } from "react";
const SvgContainer9 = (props: SVGProps<SVGSVGElement>) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    width="1em"
    height="1em"
    fill="none"
    viewBox="0 0 15 15"
    {...props}
  >
    <path
      fill="#727687"
      d="M0 15V1.5Q0 .881.441.441A1.44 1.44 0 0 1 1.5 0h12q.619 0 1.059.441Q15 .881 15 1.5v9q0 .619-.441 1.059A1.44 1.44 0 0 1 13.5 12H3zm2.362-4.5H13.5v-9h-12v9.844zm-.862 0v-9z"
    />
  </svg>
);
const Memo = memo(SvgContainer9);
export default Memo;
