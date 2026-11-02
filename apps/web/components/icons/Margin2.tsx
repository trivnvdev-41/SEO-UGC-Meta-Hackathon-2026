import * as React from "react";
import type { SVGProps } from "react";
import { memo } from "react";
const SvgMargin2 = (props: SVGProps<SVGSVGElement>) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    width="1em"
    height="1em"
    fill="none"
    viewBox="0 0 5.75 6.875"
    {...props}
  >
    <path
      fill="#0866FF"
      d="M5.662 3.662 2.537 6.787a.5.5 0 0 1-.102.064.3.3 0 0 1-.122.024.3.3 0 0 1-.22-.093A.3.3 0 0 1 2 6.563a.3.3 0 0 1 .024-.123.5.5 0 0 1 .064-.102l2.91-2.9L2.088.537a.5.5 0 0 1-.064-.102A.3.3 0 0 1 2 .313a.3.3 0 0 1 .093-.22.3.3 0 0 1 .22-.093q.068 0 .122.024.053.025.102.064l3.125 3.125a.5.5 0 0 1 .064.102.3.3 0 0 1 .024.123.3.3 0 0 1-.024.122.5.5 0 0 1-.064.102"
    />
  </svg>
);
const Memo = memo(SvgMargin2);
export default Memo;
