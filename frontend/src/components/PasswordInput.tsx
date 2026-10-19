import { useState, type InputHTMLAttributes } from "react";

type Props = Omit<InputHTMLAttributes<HTMLInputElement>, "type"> & { invalid?: boolean };

export default function PasswordInput({ invalid, className, ...rest }: Props) {
  const [show, setShow] = useState(false);
  return (
    <div className="input-group">
      <input
        {...rest}
        type={show ? "text" : "password"}
        className={`input${invalid ? " input--error" : ""}${className ? ` ${className}` : ""}`}
      />
      <button type="button" className="input-group__btn" onClick={() => setShow((s) => !s)} tabIndex={-1}>
        {show ? "Ẩn" : "Hiện"}
      </button>
    </div>
  );
}
