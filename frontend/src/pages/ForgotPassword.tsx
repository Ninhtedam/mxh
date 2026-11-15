import { useEffect, useState, type FormEvent } from "react";
import { Link } from "react-router-dom";
import AuthLayout from "../components/AuthLayout";
import RegisterSteps from "../components/RegisterSteps";
import OtpInput from "../components/OtpInput";
import PasswordInput from "../components/PasswordInput";
import { authApi, getErrorMessage, EMAIL_REGEX } from "../api/auth";

// Khớp với thời gian chờ giữa hai lần gửi ở backend (auth.service.ts)
const RESEND_SECONDS = 10;
const OTP_LENGTH = 6;
const STEPS = ["Xác thực email", "Mật khẩu mới"];

type Phase = "email" | "otp" | "password" | "done";

// Quên mật khẩu: nhập email -> nhập OTP -> đặt mật khẩu mới
export default function ForgotPassword() {
  const [phase, setPhase] = useState<Phase>("email");
  const [email, setEmail] = useState("");
  const [otp, setOtp] = useState("");
  const [resetToken, setResetToken] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [errors, setErrors] = useState<{ password?: string; confirmPassword?: string }>({});
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
      await authApi.forgotSendOtp(email.trim());
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
      const data = await authApi.forgotVerifyOtp(email.trim(), otp);
      setResetToken(data.resetToken);
      setPhase("password");
    } catch (err) {
      setError(getErrorMessage(err, "Mã OTP không đúng"));
      setOtp("");
    } finally {
      setLoading(false);
    }
  }

  async function handlePasswordSubmit(e: FormEvent) {
    e.preventDefault();
    setError("");
    const errs: typeof errors = {};
    if (!password) errs.password = "Vui lòng nhập mật khẩu mới";
    else if (password.length < 6) errs.password = "Mật khẩu phải từ 6 ký tự";
    if (!confirmPassword) errs.confirmPassword = "Vui lòng nhập lại mật khẩu";
    else if (confirmPassword !== password) errs.confirmPassword = "Mật khẩu nhập lại không khớp";
    setErrors(errs);
    if (Object.keys(errs).length) return;

    setLoading(true);
    try {
      await authApi.resetPassword(resetToken, password);
      setPhase("done");
    } catch (err) {
      setError(getErrorMessage(err));
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

  if (phase === "done") {
    return (
      <AuthLayout>
        <div className="auth__head">
          <h2>Đổi mật khẩu thành công</h2>
          <p>Bạn có thể đăng nhập bằng mật khẩu mới.</p>
        </div>
        <Link to="/login" className="btn btn--primary btn--block">
          Về trang đăng nhập
        </Link>
      </AuthLayout>
    );
  }

  return (
    <AuthLayout>
      <RegisterSteps current={phase === "password" ? 2 : 1} steps={STEPS} />
      <div className="auth__head">
        <h2>{phase === "password" ? "Đặt mật khẩu mới" : "Quên mật khẩu"}</h2>
        <p>
          {phase === "email" && "Nhập email đã đăng ký, chúng tôi sẽ gửi mã xác thực."}
          {phase === "otp" && `Nhập mã gồm ${OTP_LENGTH} số đã gửi tới email của bạn.`}
          {phase === "password" && (
            <>
              Đặt mật khẩu mới cho <strong>{email}</strong>.
            </>
          )}
        </p>
      </div>

      {phase === "email" && (
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
          </label>
          <button className="btn btn--primary btn--block" disabled={loading}>
            {loading && <span className="spinner" />}
            Gửi mã OTP
          </button>
        </form>
      )}

      {phase === "otp" && (
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

      {phase === "password" && (
        <form className="form" onSubmit={handlePasswordSubmit} noValidate>
          {error && <div className="alert alert--error">{error}</div>}

          <label className="field">
            <span className="field__label">
              Mật khẩu mới<span className="req">*</span>
            </span>
            <PasswordInput
              autoComplete="new-password"
              placeholder="Ít nhất 6 ký tự"
              invalid={!!errors.password}
              value={password}
              onChange={(e) => {
                setPassword(e.target.value);
                setErrors((x) => ({ ...x, password: undefined }));
              }}
              autoFocus
            />
            {errors.password && <span className="field__error">{errors.password}</span>}
          </label>

          <label className="field">
            <span className="field__label">
              Nhập lại mật khẩu<span className="req">*</span>
            </span>
            <PasswordInput
              autoComplete="new-password"
              placeholder="Nhập lại mật khẩu mới"
              invalid={!!errors.confirmPassword}
              value={confirmPassword}
              onChange={(e) => {
                setConfirmPassword(e.target.value);
                setErrors((x) => ({ ...x, confirmPassword: undefined }));
              }}
            />
            {errors.confirmPassword && <span className="field__error">{errors.confirmPassword}</span>}
          </label>

          <button className="btn btn--primary btn--block" disabled={loading}>
            {loading && <span className="spinner" />}
            Đổi mật khẩu
          </button>
        </form>
      )}

      <p className="auth__foot">
        <Link to="/login">← Quay lại đăng nhập</Link>
      </p>
    </AuthLayout>
  );
}
