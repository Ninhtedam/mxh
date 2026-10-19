import { useState, type FormEvent } from "react";
import { Link, useNavigate } from "react-router-dom";
import AuthLayout from "../components/AuthLayout";
import PasswordInput from "../components/PasswordInput";
import { authApi, getErrorMessage, EMAIL_REGEX } from "../api/auth";

export default function Login() {
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError("");
    if (!email || !password) return setError("Vui lòng nhập email và mật khẩu");
    if (!EMAIL_REGEX.test(email)) return setError("Email không hợp lệ");

    setLoading(true);
    try {
      const data = await authApi.login(email.trim(), password);
      localStorage.setItem("token", data.token);
      navigate("/", { replace: true });
    } catch (err) {
      setError(getErrorMessage(err, "Email hoặc mật khẩu không đúng"));
    } finally {
      setLoading(false);
    }
  }

  return (
    <AuthLayout>
      <div className="auth__head">
        <h2>Đăng nhập</h2>
        <p>Chào mừng bạn quay lại.</p>
      </div>

      <form className="form" onSubmit={handleSubmit} noValidate>
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

        <label className="field">
          <span className="field__label">Mật khẩu</span>
          <PasswordInput
            autoComplete="current-password"
            placeholder="Nhập mật khẩu"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
        </label>

        <div className="form__meta">
          <label className="check">
            <input type="checkbox" defaultChecked /> Ghi nhớ đăng nhập
          </label>
          <Link to="/quen-mat-khau">Quên mật khẩu?</Link>
        </div>

        <button className="btn btn--primary btn--block" disabled={loading}>
          {loading && <span className="spinner" />}
          Đăng nhập
        </button>
      </form>

      <p className="auth__foot">
        Chưa có tài khoản? <Link to="/dangky">Đăng ký</Link>
      </p>
    </AuthLayout>
  );
}
