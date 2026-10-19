import { useId } from "react";
import { HANDS_PATH } from "./logoHands";

type LogoProps = {
  /** Chiều cao logo (px), chiều rộng tự tính theo tỉ lệ */
  size?: number;
  /** Bản trắng dùng trên nền xanh */
  inverse?: boolean;
};

const VIEW_W = 352;
const VIEW_H = 186;

// Logo mxh: m hai vòm, x là "ɔ" ghép "c" với hai bàn tay nắm nhau ở giữa, h nhỏ trong lòng chữ c.
// Tô bằng currentColor; --logo-bg là màu nền để tách bàn tay khỏi nét chữ.
export default function Logo({ size = 36, inverse = false }: LogoProps) {
  const clipId = useId();

  return (
    <svg
      className={`logo${inverse ? " logo--inverse" : ""}`}
      height={size}
      width={(size * VIEW_W) / VIEW_H}
      viewBox={`22 32 ${VIEW_W} ${VIEW_H}`}
      role="img"
      aria-label="mxh"
    >
      <defs>
        <clipPath id={clipId}>
          <circle cx="428" cy="456" r="262" />
        </clipPath>
      </defs>
      <g fill="none" stroke="currentColor" strokeWidth="28" strokeLinecap="round" strokeLinejoin="round">
        <path d="M40 200 V105 C40 72 62 50 88 50 C114 50 135 72 135 105 V200" />
        <path d="M135 105 C135 72 160 50 187 50 A75 75 0 0 1 262 125 A75 75 0 0 1 187 200" />
        <path d="M343 50 A75 75 0 0 0 268 125 A75 75 0 0 0 343 200" />
      </g>
      <path
        d="M332 100 V154 M332 136 C332 126 338 120 346 120 C354 120 360 126 360 136 V154"
        fill="none"
        stroke="currentColor"
        strokeWidth="13"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <g transform="translate(265 125) scale(0.0912) translate(-428 -456)">
        <circle cx="428" cy="456" r="250" fill="var(--logo-bg)" />
        <path clipPath={`url(#${clipId})`} fill="currentColor" fillRule="evenodd" d={HANDS_PATH} />
      </g>
    </svg>
  );
}
