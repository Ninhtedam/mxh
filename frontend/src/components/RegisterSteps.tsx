const STEPS = ["Xác thực email", "Thông tin cá nhân"];

export default function RegisterSteps({ current }: { current: 1 | 2 }) {
  return (
    <div className="steps">
      {STEPS.map((label, i) => (
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
