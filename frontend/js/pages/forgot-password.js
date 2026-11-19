// Quên mật khẩu: nhập email -> nhập OTP -> đặt mật khẩu mới
const FORGOT_STEPS = ["Xác thực email", "Mật khẩu mới"];
const passwordForm = $("password-form");
const passwordError = $("password-error");
const passwordBtn = $("password-btn");
const passwordInput = $("password");
const confirmInput = $("confirm-password");
let resetToken = "";

function onPhase(phase) {
  passwordForm.hidden = phase !== "password";
  renderSteps($("steps"), phase === "password" ? 2 : 1, FORGOT_STEPS);
  $("title").textContent = phase === "password" ? "Đặt mật khẩu mới" : "Quên mật khẩu";
  const subtitle = $("subtitle");
  if (phase === "email") subtitle.textContent = "Nhập email đã đăng ký, chúng tôi sẽ gửi mã xác thực.";
  else if (phase === "otp") subtitle.textContent = `Nhập mã gồm ${OTP_LENGTH} số đã gửi tới email của bạn.`;
  else {
    subtitle.textContent = "Đặt mật khẩu mới cho ";
    const strong = document.createElement("strong");
    strong.textContent = flow.email();
    subtitle.append(strong, ".");
  }
}

const flow = initEmailOtp({
  send: (email) => authApi.forgotSendOtp(email),
  // Dùng chung bước xác thực OTP với đăng ký, backend trả về registerToken
  verify: (email, otp) => authApi.verifyOtp(email, otp),
  onVerified: (data) => {
    resetToken = data.registerToken;
    flow.showPhase("password");
    passwordInput.focus();
  },
  onPhase,
});
onPhase("email");

// Gõ lại thì bỏ lỗi của ô đó
passwordInput.addEventListener("input", () => setFieldError(passwordInput, ""));
confirmInput.addEventListener("input", () => setFieldError(confirmInput, ""));

passwordForm.addEventListener("submit", async (e) => {
  e.preventDefault();
  showMsg(passwordError, "");
  const password = passwordInput.value;
  const confirm = confirmInput.value;

  let pwErr = "";
  if (!password) pwErr = "Vui lòng nhập mật khẩu mới";
  else if (password.length < 6) pwErr = "Mật khẩu phải từ 6 ký tự";
  let cfErr = "";
  if (!confirm) cfErr = "Vui lòng nhập lại mật khẩu";
  else if (confirm !== password) cfErr = "Mật khẩu nhập lại không khớp";
  setFieldError(passwordInput, pwErr);
  setFieldError(confirmInput, cfErr);
  if (pwErr || cfErr) return;

  setLoading(passwordBtn, true);
  try {
    await authApi.resetPassword(resetToken, password);
    $("flow").hidden = true;
    $("done").hidden = false;
  } catch (err) {
    showMsg(passwordError, getErrorMessage(err));
  } finally {
    setLoading(passwordBtn, false);
  }
});
