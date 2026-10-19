import { useState, type FormEvent } from "react";
import { Link, Navigate, useNavigate } from "react-router-dom";
import AuthLayout from "../components/AuthLayout";
import RegisterSteps from "../components/RegisterSteps";
import PasswordInput from "../components/PasswordInput";
import { authApi, getErrorMessage, VERIFIED_EMAIL_KEY, type RegisterPayload } from "../api/auth";

type Form = {
  username: string;
  sex: "" | "Nam" | "Nữ";
  birthday: string;
  phone: string;
  address: string;
  password: string;
  confirmPassword: string;
};
type Errors = Partial<Record<keyof Form, string>>;

const today = new Date().toISOString().slice(0, 10);

function validate(f: Form): Errors {
  const e: Errors = {};
  if (!f.password) e.password = "Vui lòng nhập mật khẩu";
  else if (f.password.length < 6) e.password = "Mật khẩu phải từ 6 ký tự";
  if (!f.confirmPassword) e.confirmPassword = "Vui lòng nhập lại mật khẩu";
  else if (f.confirmPassword !== f.password) e.confirmPassword = "Mật khẩu nhập lại không khớp";
  if (f.username.length > 50) e.username = "Tên tối đa 50 ký tự";
  if (f.phone && !/^0\d{9,10}$/.test(f.phone)) e.phone = "Số điện thoại không hợp lệ";
  if (f.birthday && f.birthday > today) e.birthday = "Ngày sinh không hợp lệ";
  if (f.address.length > 255) e.address = "Địa chỉ tối đa 255 ký tự";
  return e;
}

// Đăng ký bước 2: thông tin cá nhân (chỉ mật khẩu là bắt buộc)
export default function RegisterInfo() {
  const navigate = useNavigate();
  const email = sessionStorage.getItem(VERIFIED_EMAIL_KEY);
  const [form, setForm] = useState<Form>({
    username: "",
    sex: "",
    birthday: "",
    phone: "",
    address: "",
    password: "",
    confirmPassword: "",
  });
  const [errors, setErrors] = useState<Errors>({});
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  if (!email) return <Navigate to="/dangky" replace />;

  function set<K extends keyof Form>(key: K, value: Form[K]) {
    setForm((f) => ({ ...f, [key]: value }));
    if (errors[key]) setErrors((e) => ({ ...e, [key]: undefined }));
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError("");
    const errs = validate(form);
    setErrors(errs);
    if (Object.keys(errs).length || !email) return;

    const payload: RegisterPayload = {
      email,
      password: form.password,
      username: form.username.trim() || undefined,
      sex: form.sex || undefined,
      birthday: form.birthday || undefined,
      phone: form.phone || undefined,
      address: form.address.trim() || undefined,
    };

    setLoading(true);
    try {
      const data = await authApi.register(payload);
      sessionStorage.removeItem(VERIFIED_EMAIL_KEY);
      localStorage.setItem("token", data.token);
      navigate("/", { replace: true, state: { firstLogin: true } });
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setLoading(false);
    }
  }

  return (
    <AuthLayout>
      <RegisterSteps current={2} />
      <div className="auth__head">
        <h2>Thông tin cá nhân</h2>
        <p>
          Đăng ký cho <strong>{email}</strong>. Các mục không bắt buộc có thể bổ sung sau.
        </p>
      </div>

      <form className="form" onSubmit={handleSubmit} noValidate>
        {error && <div className="alert alert--error">{error}</div>}

        <label className="field">
          <span className="field__label">
            Tên hiển thị<span className="opt">(không bắt buộc)</span>
          </span>
          <input
            className={`input${errors.username ? " input--error" : ""}`}
            placeholder="Người dùng"
            maxLength={50}
            autoComplete="nickname"
            value={form.username}
            onChange={(e) => set("username", e.target.value)}
            autoFocus
          />
          {errors.username && <span className="field__error">{errors.username}</span>}
        </label>

        <div className="form__row">
          <div className="field">
            <span className="field__label">
              Giới tính<span className="opt">(không bắt buộc)</span>
            </span>
            <div className="radio-group" role="radiogroup">
              {(["Nam", "Nữ"] as const).map((s) => (
                <label key={s} className="radio">
                  <input
                    type="radio"
                    name="sex"
                    checked={form.sex === s}
                    onChange={() => set("sex", s)}
                    onClick={() => form.sex === s && set("sex", "")}
                  />
                  {s}
                </label>
              ))}
            </div>
          </div>

          <label className="field">
            <span className="field__label">
              Ngày sinh<span className="opt">(không bắt buộc)</span>
            </span>
            <input
              type="date"
              className={`input${errors.birthday ? " input--error" : ""}`}
              max={today}
              value={form.birthday}
              onChange={(e) => set("birthday", e.target.value)}
            />
            {errors.birthday && <span className="field__error">{errors.birthday}</span>}
          </label>
        </div>

        <label className="field">
          <span className="field__label">
            Số điện thoại<span className="opt">(không bắt buộc)</span>
          </span>
          <input
            type="tel"
            inputMode="numeric"
            className={`input${errors.phone ? " input--error" : ""}`}
            placeholder="0912345678"
            maxLength={11}
            autoComplete="tel"
            value={form.phone}
            onChange={(e) => set("phone", e.target.value.replace(/\D/g, ""))}
          />
          {errors.phone && <span className="field__error">{errors.phone}</span>}
        </label>

        <label className="field">
          <span className="field__label">
            Địa chỉ<span className="opt">(không bắt buộc)</span>
          </span>
          <input
            className={`input${errors.address ? " input--error" : ""}`}
            placeholder="Quận/Huyện, Tỉnh/Thành phố"
            maxLength={255}
            autoComplete="street-address"
            value={form.address}
            onChange={(e) => set("address", e.target.value)}
          />
          {errors.address && <span className="field__error">{errors.address}</span>}
        </label>

        <label className="field">
          <span className="field__label">
            Mật khẩu<span className="req">*</span>
          </span>
          <PasswordInput
            autoComplete="new-password"
            placeholder="Ít nhất 6 ký tự"
            invalid={!!errors.password}
            value={form.password}
            onChange={(e) => set("password", e.target.value)}
          />
          {errors.password && <span className="field__error">{errors.password}</span>}
        </label>

        <label className="field">
          <span className="field__label">
            Nhập lại mật khẩu<span className="req">*</span>
          </span>
          <PasswordInput
            autoComplete="new-password"
            placeholder="Nhập lại mật khẩu"
            invalid={!!errors.confirmPassword}
            value={form.confirmPassword}
            onChange={(e) => set("confirmPassword", e.target.value)}
          />
          {errors.confirmPassword && <span className="field__error">{errors.confirmPassword}</span>}
        </label>

        <button className="btn btn--primary btn--block" disabled={loading}>
          {loading && <span className="spinner" />}
          Hoàn tất đăng ký
        </button>
      </form>

      <p className="auth__foot">
        <Link to="/dangky">← Quay lại bước 1</Link>
      </p>
    </AuthLayout>
  );
}
