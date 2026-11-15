const STEPS = ["Xác thực email", "Thông tin cá nhân"];

// Thanh bước dùng chung cho đăng ký và quên mật khẩu
export default function RegisterSteps({ current, steps = STEPS }: { current: number; steps?: string[] }) {
  return (
    <div className="steps">
      {steps.map((label, i) => (
        <div key={label} className={`steps__item${i < current ? " steps__item--active" : ""}`}>
          <div className="steps__bar" />
          <div className="steps__label">
            Bước {i + 1}. {label}
          </div>
        </div>
      ))}
    </div>
  );
}
