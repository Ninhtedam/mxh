// Đăng ký bước 1: nhập email -> gửi OTP -> nhập OTP
renderSteps($("steps"), 1);

initEmailOtp({
  send: (email) => authApi.sendOtp(email),
  verify: (email, otp) => authApi.verifyOtp(email, otp),
  onVerified: ({ registerToken }, email) => {
    sessionStorage.setItem(VERIFIED_EMAIL_KEY, email);
    sessionStorage.setItem(REGISTER_TOKEN_KEY, registerToken);
    location.href = "/register/info";
  },
  onPhase: (phase) => {
    $("subtitle").textContent =
      phase === "email"
        ? "Nhập email của bạn, chúng tôi sẽ gửi mã xác thực."
        : `Nhập mã gồm ${OTP_LENGTH} số đã gửi tới email của bạn.`;
  },
});
