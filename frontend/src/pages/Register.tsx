import { useEffect, useState, type FormEvent } from "react";
import { Link, useNavigate } from "react-router-dom";
import AuthLayout from "../components/AuthLayout";
import RegisterSteps from "../components/RegisterSteps";
import OtpInput from "../components/OtpInput";
import { authApi, getErrorMessage, EMAIL_REGEX, VERIFIED_EMAIL_KEY, REGISTER_TOKEN_KEY } from "../api/auth";

// Khớp với thời gian chờ giữa hai lần gửi ở backend (auth.service.ts)
const RESEND_SECONDS = 10;
const OTP_LENGTH = 6;

// Đăng ký bước 1: nhập email -> gửi OTP -> nhập OTP
export default function Register() {
  const navigate = useNavigate();
  const [phase, setPhase] = useState<"email" | "otp">("email");
  const [email, setEmail] = useState("");
  const [otp, setOtp] = useState("");
  const [error, setError] = useState("");
  const [info, setInfo] = useState("");
  const [loading, setLoading] = useState(false);
  const [countdown, setCountdown] = useState(0);
  const otpComplete = otp.length === OTP_LENGTH && /^\d+$/.test(otp);

  useEffect(() => {
    if (countdown <= 0) return;
    const t = setTimeout(() => setCountdown((c) => c - 1), 1000);
    return () => clearTimeout(t);
  }, [countdown]);

  async function sendOtp() {
    setError("");
    setInfo("");
    if (!email) return setError("Vui lòng nhập email");
    if (!EMAIL_REGEX.test(email)) return setError("Email không hợp lệ");

    setLoading(true);
    try {
      await authApi.sendOtp(email.trim());
      setPhase("otp");
      setOtp("");
      setCountdown(RESEND_SECONDS);
      setInfo(`Mã OTP đã được gửi tới ${email.trim()}`);
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setLoading(false);
    }
  }

  async function handleEmailSubmit(e: FormEvent) {
    e.preventDefault();
    await sendOtp();
  }

  async function handleOtpSubmit(e: FormEvent) {
    e.preventDefault();
    setError("");
    setInfo("");
    if (!otpComplete) return setError(`Vui lòng nhập đủ ${OTP_LENGTH} số`);

    setLoading(true);
    try {
      const { registerToken } = await authApi.verifyOtp(email.trim(), otp);
      sessionStorage.setItem(VERIFIED_EMAIL_KEY, email.trim());
      sessionStorage.setItem(REGISTER_TOKEN_KEY, registerToken);
      navigate("/register/info");
    } catch (err) {
      setError(getErrorMessage(err, "Mã OTP không đúng"));
      setOtp("");
    } finally {
      setLoading(false);
    }
  }

  function changeEmail() {
    setPhase("email");
    setOtp("");
    setError("");
    setInfo("");
  }

  return (
    <AuthLayout>
      <RegisterSteps current={1} />
      <div className="auth__head">
        <h2>Tạo tài khoản</h2>
        <p>
          {phase === "email"
            ? "Nhập email của bạn, chúng tôi sẽ gửi mã xác thực."
            : `Nhập mã gồm ${OTP_LENGTH} số đã gửi tới email của bạn.`}
        </p>
      </div>

      {phase === "email" ? (
        <form className="form" onSubmit={handleEmailSubmit} noValidate>
          {error && <div className="alert alert--error">{error}</div>}
          <label className="field">
            <span className="field__label">Email</span>
            <input
              className="input"
              type="email"
              autoComplete="email"
              placeholder="ban@email.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              autoFocus
            />
            <span className="field__hint">Email này sẽ dùng để đăng nhập.</span>
          </label>
          <button className="btn btn--primary btn--block" disabled={loading}>
            {loading && <span className="spinner" />}
            Gửi mã OTP
          </button>
        </form>
      ) : (
        <form className="form" onSubmit={handleOtpSubmit} noValidate>
          {error && <div className="alert alert--error">{error}</div>}
          {info && !error && <div className="alert alert--success">{info}</div>}

          <div className="email-chip">
            <strong>{email}</strong>
            <button type="button" className="link-btn" onClick={changeEmail}>
              Đổi email
            </button>
          </div>

          <div className="field">
            <span className="field__label">Mã OTP</span>
            <OtpInput value={otp} onChange={setOtp} length={OTP_LENGTH} disabled={loading} invalid={!!error} />
            <span className="field__hint">Mã có hiệu lực trong 10 phút.</span>
          </div>

          <button className="btn btn--primary btn--block" disabled={loading || !otpComplete}>
            {loading && <span className="spinner" />}
            Xác thực
          </button>

          <p className="otp__resend">
            Chưa nhận được mã?{" "}
            <button type="button" className="link-btn" onClick={sendOtp} disabled={countdown > 0 || loading}>
              {countdown > 0 ? `Gửi lại sau ${countdown}s` : "Gửi lại mã"}
            </button>
          </p>
        </form>
      )}

      <p className="auth__foot">
        Đã có tài khoản? <Link to="/login">Đăng nhập</Link>
      </p>
    </AuthLayout>
  );
}
