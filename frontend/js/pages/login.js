// Đăng nhập
const loginForm = $("login-form");
const loginError = $("error");
const loginBtn = $("submit");

loginForm.addEventListener("submit", async (e) => {
  e.preventDefault();
  showMsg(loginError, "");
  const email = $("email").value;
  const password = $("password").value;
  if (!email || !password) return showMsg(loginError, "Vui lòng nhập email và mật khẩu");
  if (!EMAIL_REGEX.test(email)) return showMsg(loginError, "Email không hợp lệ");

  setLoading(loginBtn, true);
  try {
    const data = await authApi.login(email.trim(), password);
    saveToken(data.token);
    location.replace("/");
  } catch (err) {
    showMsg(loginError, getErrorMessage(err, "Email hoặc mật khẩu không đúng"));
    setLoading(loginBtn, false);
  }
});
