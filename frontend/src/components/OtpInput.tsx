import { useRef, type ClipboardEvent, type Dispatch, type KeyboardEvent, type SetStateAction } from "react";

type Props = { value: string; onChange: Dispatch<SetStateAction<string>>; length?: number; disabled?: boolean; invalid?: boolean };

export default function OtpInput({ value, onChange, length = 6, disabled, invalid }: Props) {
  const refs = useRef<(HTMLInputElement | null)[]>([]);
  const digits = Array.from({ length }, (_, i) => (value[i] ?? "").trim());

  // Cập nhật theo giá trị trước đó để gõ nhanh không bị ghi đè
  function setAt(i: number, d: string) {
    onChange((prev) => {
      const next = Array.from({ length }, (_, k) => prev[k] ?? " ");
      next[i] = d || " ";
      return next.join("").trimEnd();
    });
  }

  function handleChange(i: number, raw: string) {
    const typed = raw.replace(/\D/g, "");
    if (!typed) return;
    // Ô đã có số: lấy số mới gõ; nhập nhiều số một lúc (autofill): rải sang các ô sau
    const chars = typed.length === 2 && digits[i] ? typed.replace(digits[i], "").slice(-1) || typed[1] : typed;
    const fill = chars.slice(0, length - i).split("");
    fill.forEach((c, k) => setAt(i + k, c));
    refs.current[Math.min(i + fill.length, length - 1)]?.focus();
  }

  function handleKeyDown(i: number, e: KeyboardEvent<HTMLInputElement>) {
    if (e.key === "Backspace") {
      e.preventDefault();
      if (digits[i]) setAt(i, "");
      else if (i > 0) {
        setAt(i - 1, "");
        refs.current[i - 1]?.focus();
      }
    } else if (e.key === "ArrowLeft") refs.current[i - 1]?.focus();
    else if (e.key === "ArrowRight") refs.current[i + 1]?.focus();
  }

  function handlePaste(e: ClipboardEvent<HTMLInputElement>) {
    const text = e.clipboardData.getData("text").replace(/\D/g, "").slice(0, length);
    if (!text) return;
    e.preventDefault();
    onChange(text);
    refs.current[Math.min(text.length, length - 1)]?.focus();
  }

  return (
    <div className="otp">
      {digits.map((d, i) => (
        <input
          key={i}
          ref={(el) => {
            refs.current[i] = el;
          }}
          className={`input${invalid ? " input--error" : ""}`}
          inputMode="numeric"
          autoComplete={i === 0 ? "one-time-code" : "off"}
          aria-label={`Số thứ ${i + 1}`}
          value={d}
          disabled={disabled}
          onChange={(e) => handleChange(i, e.target.value)}
          onKeyDown={(e) => handleKeyDown(i, e)}
          onPaste={handlePaste}
          onFocus={(e) => e.target.select()}
          autoFocus={i === 0}
        />
      ))}
    </div>
  );
}
