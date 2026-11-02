import * as React from "react";
import type { SVGProps } from "react";
import { memo } from "react";
const SvgButtonMenuOpsi = (props: SVGProps<SVGSVGElement>) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    width="1em"
    height="1em"
    fill="none"
    viewBox="0 0 19.25 10.688"
    {...props}
  >
    <path
      fill="#8590A6"
      d="M10.469 4.844a.81.81 0 0 1-.246.597.82.82 0 0 1-.598.247.82.82 0 0 1-.598-.247.81.81 0 0 1-.246-.597q0-.352.246-.598A.82.82 0 0 1 9.625 4q.351 0 .598.246a.81.81 0 0 1 .246.598M14.406 4a.81.81 0 0 0-.597.246.81.81 0 0 0-.246.598q0 .351.246.597a.81.81 0 0 0 .597.247.81.81 0 0 0 .598-.247.81.81 0 0 0 .246-.597.81.81 0 0 0-.246-.598.81.81 0 0 0-.598-.246M4.844 4a.81.81 0 0 0-.598.246.81.81 0 0 0-.246.598q0 .351.246.597a.81.81 0 0 0 .598.247.81.81 0 0 0 .597-.247.81.81 0 0 0 .247-.597.81.81 0 0 0-.247-.598A.81.81 0 0 0 4.844 4"
    />
  </svg>
);
const Memo = memo(SvgButtonMenuOpsi);
export default Memo;
