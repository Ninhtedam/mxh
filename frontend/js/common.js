// ===== Cấu hình & API =====
// Địa chỉ API backend. Trang HTML do chính backend phục vụ nên dùng đường dẫn tương đối,
// mở bằng localhost hay 127.0.0.1 đều gọi đúng server, không cần sửa khi đổi cổng
const API_URL = "/api";

// Đường dẫn API xác thực – sửa ở đây nếu backend đặt tên khác
const AUTH_ENDPOINTS = {
  login: "/auth/login",
  sendOtp: "/auth/send-otp",
  verifyOtp: "/auth/verify-otp",
  register: "/auth/register",
  // Quên mật khẩu: gửi OTP -> xác thực OTP (dùng chung verifyOtp ở trên) -> đặt mật khẩu mới
  forgotSendOtp: "/auth/forgot-password/send-otp",
  resetPassword: "/auth/forgot-password/reset",
};

const EMAIL_REGEX = /^\S+@\S+\.\S+$/;
const OTP_LENGTH = 6;
// Khớp với thời gian chờ giữa hai lần gửi ở backend (auth.service.ts)
const RESEND_SECONDS = 10;
// Lưu email đã xác thực OTP và giấy xác nhận email (JWT 15 phút) để dùng ở bước 2 đăng ký
const VERIFIED_EMAIL_KEY = "register_email";
const REGISTER_TOKEN_KEY = "register_token";

class ApiError extends Error {
  constructor(message, network = false) {
    super(message);
    this.network = network;
  }
}

// ===== Token đăng nhập =====
// Lưu trong localStorage: giữ cả khi đóng tab / tắt trình duyệt, tới khi token hết hạn (7 ngày)
const TOKEN_KEY = "token";

function getToken() {
  return localStorage.getItem(TOKEN_KEY);
}

function saveToken(token) {
  localStorage.setItem(TOKEN_KEY, token);
}

function clearToken() {
  localStorage.removeItem(TOKEN_KEY);
}

// Đăng xuất: xoá token và về trang đăng nhập
function logout() {
  clearToken();
  location.replace("/login");
}

// Gửi request JSON, tự gắn token đăng nhập nếu có
async function apiRequest(method, path, body) {
  const headers = {};
  if (body !== undefined) headers["Content-Type"] = "application/json";
  const token = getToken();
  if (token) headers.Authorization = `Bearer ${token}`;

  let res;
  try {
    res = await fetch(API_URL + path, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch {
    throw new ApiError("", true);
  }

  // Token hết hạn / không hợp lệ -> đăng xuất. Bỏ qua /auth/* vì các API đó cũng trả 401
  // cho lỗi thường (sai mật khẩu, phiên OTP hết hạn) và cần hiện thông báo cho người dùng.
  if (res.status === 401 && token && !path.startsWith("/auth/")) {
    logout();
    // Trang đang chuyển đi: giữ promise treo để code gọi không hiện lỗi thừa
    return new Promise(() => {});
  }

  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new ApiError(data.message || "");
  return data;
}

// Dùng apiGet/apiPost cho mọi API (kể cả feed sau này) để được xử lý 401 ở trên
const apiGet = (path) => apiRequest("GET", path);
const apiPost = (path, body) => apiRequest("POST", path, body);

const authApi = {
  login: (email, password) => apiPost(AUTH_ENDPOINTS.login, { email, password }),
  sendOtp: (email) => apiPost(AUTH_ENDPOINTS.sendOtp, { email }),
  verifyOtp: (email, otp) => apiPost(AUTH_ENDPOINTS.verifyOtp, { email, otp }),
  register: (payload) => apiPost(AUTH_ENDPOINTS.register, payload),
  forgotSendOtp: (email) => apiPost(AUTH_ENDPOINTS.forgotSendOtp, { email }),
  resetPassword: (resetToken, password) => apiPost(AUTH_ENDPOINTS.resetPassword, { resetToken, password }),
};

function getErrorMessage(err, fallback = "Có lỗi xảy ra, vui lòng thử lại") {
  if (err instanceof ApiError) return err.network ? "Không kết nối được máy chủ" : err.message || fallback;
  return fallback;
}

// ===== Tiện ích giao diện =====
const $ = (id) => document.getElementById(id);

// Hiện thông báo trong ô alert; chuỗi rỗng thì ẩn
function showMsg(el, msg) {
  el.textContent = msg || "";
  el.hidden = !msg;
}

// Bật/tắt trạng thái đang xử lý của nút (khoá nút + vòng xoay)
function setLoading(btn, loading) {
  btn.disabled = loading;
  let spinner = btn.querySelector(".spinner");
  if (loading && !spinner) {
    spinner = document.createElement("span");
    spinner.className = "spinner";
    btn.prepend(spinner);
  } else if (!loading && spinner) spinner.remove();
}

// Lỗi dưới từng ô nhập: viền đỏ + dòng chữ đỏ trong .field
function setFieldError(input, msg) {
  const field = input.closest(".field");
  input.classList.toggle("input--error", !!msg);
  let el = field.querySelector(".field__error");
  if (msg && !el) {
    el = document.createElement("span");
    el.className = "field__error";
    field.append(el);
  }
  if (el) {
    if (msg) el.textContent = msg;
    else el.remove();
  }
}

// Thanh bước dùng chung cho đăng ký và quên mật khẩu
function renderSteps(el, current, steps = ["Xác thực email", "Thông tin cá nhân"]) {
  el.className = "steps";
  el.innerHTML = steps
    .map(
      (label, i) => `<div class="steps__item${i < current ? " steps__item--active" : ""}">
        <div class="steps__bar"></div>
        <div class="steps__label">Bước ${i + 1}. ${label}</div>
      </div>`
    )
    .join("");
}

// Khung trang xác thực: cột thương hiệu bên trái + logo trên điện thoại
function mountAuthLayout() {
  const brand = document.querySelector(".auth__brand");
  if (brand) {
    brand.innerHTML = `
      ${logoSvg(60, true)}
      <div>
        <h1>Kết bạn, theo dõi và chia sẻ khoảnh khắc mỗi ngày.</h1>
        <p>Tìm bạn bè bằng mã người dùng, cập nhật bài viết và trò chuyện với những người bạn quan tâm.</p>
      </div>
      <span class="auth__brand-foot">© ${new Date().getFullYear()} mxh</span>`;
  }
  const mobileLogo = document.querySelector(".auth__mobile-logo");
  if (mobileLogo) mobileLogo.innerHTML = logoSvg(48);
}

// Nút Hiện/Ẩn mật khẩu: <div class="input-group"><input type="password"><button class="input-group__btn">
function initPasswordToggles() {
  document.querySelectorAll(".input-group__btn").forEach((btn) => {
    const input = btn.parentElement.querySelector("input");
    btn.addEventListener("click", () => {
      const show = input.type === "password";
      input.type = show ? "text" : "password";
      btn.textContent = show ? "Ẩn" : "Hiện";
    });
  });
}

// ===== Ô nhập OTP (mỗi số một ô) =====
function createOtp(container, { length = OTP_LENGTH, onChange = () => {} } = {}) {
  container.className = "otp";
  container.innerHTML = "";
  const digits = Array(length).fill("");
  const inputs = [];

  const render = () => inputs.forEach((el, i) => (el.value = digits[i]));
  const changed = () => {
    render();
    onChange(otp.value);
  };
  const focusAt = (i) => inputs[Math.max(0, Math.min(i, length - 1))].focus();

  for (let i = 0; i < length; i++) {
    const el = document.createElement("input");
    el.className = "input";
    el.inputMode = "numeric";
    el.autocomplete = i === 0 ? "one-time-code" : "off";
    el.setAttribute("aria-label", `Số thứ ${i + 1}`);

    el.addEventListener("input", () => {
      const typed = el.value.replace(/\D/g, "");
      if (!typed) return render();
      // Ô đã có số: lấy số mới gõ; nhập nhiều số một lúc (autofill): rải sang các ô sau
      const chars =
        typed.length === 2 && digits[i] ? typed.replace(digits[i], "").slice(-1) || typed[1] : typed;
      const fill = chars.slice(0, length - i).split("");
      fill.forEach((c, k) => (digits[i + k] = c));
      changed();
      focusAt(i + fill.length);
    });

    el.addEventListener("keydown", (e) => {
      if (e.key === "Backspace") {
        e.preventDefault();
        if (digits[i]) digits[i] = "";
        else if (i > 0) {
          digits[i - 1] = "";
          focusAt(i - 1);
        }
        changed();
      } else if (e.key === "ArrowLeft" && i > 0) focusAt(i - 1);
      else if (e.key === "ArrowRight") focusAt(i + 1);
    });

    el.addEventListener("paste", (e) => {
      const text = e.clipboardData.getData("text").replace(/\D/g, "").slice(0, length);
      if (!text) return;
      e.preventDefault();
      for (let k = 0; k < length; k++) digits[k] = text[k] || "";
      changed();
      focusAt(text.length);
    });

    el.addEventListener("focus", () => el.select());
    inputs.push(el);
    container.append(el);
  }

  const otp = {
    get value() {
      return digits.map((d) => d || " ").join("").trimEnd();
    },
    get complete() {
      return new RegExp(`^\\d{${length}}$`).test(otp.value);
    },
    clear() {
      digits.fill("");
      changed();
    },
    setDisabled: (b) => inputs.forEach((el) => (el.disabled = b)),
    setInvalid: (b) => inputs.forEach((el) => el.classList.toggle("input--error", b)),
    focus: () => focusAt(digits.findIndex((d) => !d)),
  };
  return otp;
}

// ===== Bước nhập email -> gửi OTP -> nhập OTP (dùng cho đăng ký và quên mật khẩu) =====
// Trang cần có các phần tử: #email-form #email #email-error #email-btn
//   #otp-form #otp-error #otp-info #otp-email #change-email #otp-box #otp-btn #resend
function initEmailOtp({ send, verify, onVerified, onPhase = () => {} }) {
  const emailForm = $("email-form");
  const emailInput = $("email");
  const emailError = $("email-error");
  const emailBtn = $("email-btn");
  const otpForm = $("otp-form");
  const otpError = $("otp-error");
  const otpInfo = $("otp-info");
  const otpBtn = $("otp-btn");
  const resendBtn = $("resend");

  let loading = false;
  let countdown = 0;
  let timer = null;

  const otp = createOtp($("otp-box"), { onChange: updateOtpBtn });

  function updateOtpBtn() {
    otpBtn.disabled = loading || !otp.complete;
  }
  function updateResend() {
    resendBtn.disabled = countdown > 0 || loading;
    resendBtn.textContent = countdown > 0 ? `Gửi lại sau ${countdown}s` : "Gửi lại mã";
  }
  function startCountdown() {
    countdown = RESEND_SECONDS;
    clearInterval(timer);
    timer = setInterval(() => {
      countdown--;
      if (countdown <= 0) clearInterval(timer);
      updateResend();
    }, 1000);
    updateResend();
  }
  function setBusy(b) {
    loading = b;
    setLoading(emailBtn, b);
    setLoading(otpBtn, b);
    otp.setDisabled(b);
    updateOtpBtn();
    updateResend();
  }
  function clearMsgs() {
    showMsg(emailError, "");
    showMsg(otpError, "");
    showMsg(otpInfo, "");
    otp.setInvalid(false);
  }
  function showOtpError(msg) {
    showMsg(otpError, msg);
    otp.setInvalid(true);
  }
  function showPhase(phase) {
    emailForm.hidden = phase !== "email";
    otpForm.hidden = phase !== "otp";
    onPhase(phase);
  }

  async function sendOtp() {
    const inOtp = !otpForm.hidden;
    const showError = inOtp ? showOtpError : (msg) => showMsg(emailError, msg);
    clearMsgs();
    const email = emailInput.value;
    if (!email) return showError("Vui lòng nhập email");
    if (!EMAIL_REGEX.test(email)) return showError("Email không hợp lệ");

    setBusy(true);
    try {
      await send(email.trim());
      $("otp-email").textContent = email.trim();
      showPhase("otp");
      otp.clear();
      startCountdown();
      showMsg(otpInfo, `Mã OTP đã được gửi tới ${email.trim()}`);
    } catch (err) {
      showError(getErrorMessage(err));
    } finally {
      setBusy(false);
    }
    if (!otpForm.hidden) otp.focus();
  }

  emailForm.addEventListener("submit", (e) => {
    e.preventDefault();
    sendOtp();
  });
  resendBtn.addEventListener("click", sendOtp);

  otpForm.addEventListener("submit", async (e) => {
    e.preventDefault();
    clearMsgs();
    if (!otp.complete) return showOtpError(`Vui lòng nhập đủ ${OTP_LENGTH} số`);

    const email = emailInput.value.trim();
    setBusy(true);
    let failed = false;
    try {
      const data = await verify(email, otp.value);
      await onVerified(data, email);
    } catch (err) {
      failed = true;
      showOtpError(getErrorMessage(err, "Mã OTP không đúng"));
      otp.clear();
    } finally {
      setBusy(false);
    }
    if (failed) otp.focus();
  });

  $("change-email").addEventListener("click", () => {
    showPhase("email");
    otp.clear();
    clearMsgs();
    emailInput.focus();
  });

  updateOtpBtn();
  updateResend();
  return { showPhase, email: () => emailInput.value.trim() };
}

// Chạy chung cho mọi trang
document.addEventListener("DOMContentLoaded", () => {
  mountAuthLayout();
  initPasswordToggles();
});
