// Đăng ký bước 2: thông tin cá nhân (chỉ mật khẩu là bắt buộc)
// Đọc một lần khi mở trang (việc chuyển về bước 1 nếu thiếu đã làm ở <head>)
const regEmail = sessionStorage.getItem(VERIFIED_EMAIL_KEY);
const registerToken = sessionStorage.getItem(REGISTER_TOKEN_KEY);
const today = new Date().toISOString().slice(0, 10);

renderSteps($("steps"), 2);
$("reg-email").textContent = regEmail || "";
$("birthday").max = today;

const fields = {
  username: $("username"),
  birthday: $("birthday"),
  phone: $("phone"),
  address: $("address"),
  password: $("password"),
  confirmPassword: $("confirm-password"),
};

function readForm() {
  const sex = document.querySelector('input[name="sex"]:checked');
  return {
    username: fields.username.value,
    sex: sex ? sex.value : "",
    birthday: fields.birthday.value,
    phone: fields.phone.value,
    address: fields.address.value,
    password: fields.password.value,
    confirmPassword: fields.confirmPassword.value,
  };
}

function validate(f) {
  const e = {};
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

// Gõ lại thì bỏ lỗi của ô đó; số điện thoại chỉ giữ chữ số
Object.values(fields).forEach((input) => input.addEventListener("input", () => setFieldError(input, "")));
fields.phone.addEventListener("input", () => {
  fields.phone.value = fields.phone.value.replace(/\D/g, "");
});

// Bấm lại vào giới tính đang chọn thì bỏ chọn
let currentSex = "";
document.querySelectorAll('input[name="sex"]').forEach((radio) => {
  radio.addEventListener("click", () => {
    if (currentSex === radio.value) {
      radio.checked = false;
      currentSex = "";
    } else currentSex = radio.value;
  });
});

const infoError = $("error");
const infoBtn = $("submit");

$("info-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  showMsg(infoError, "");
  const form = readForm();
  const errs = validate(form);
  Object.entries(fields).forEach(([key, input]) => setFieldError(input, errs[key]));
  if (Object.keys(errs).length || !registerToken) return;

  const payload = {
    registerToken,
    password: form.password,
    username: form.username.trim() || undefined,
    sex: form.sex || undefined,
    birthday: form.birthday || undefined,
    phone: form.phone || undefined,
    address: form.address.trim() || undefined,
  };

  setLoading(infoBtn, true);
  try {
    const data = await authApi.register(payload);
    sessionStorage.removeItem(VERIFIED_EMAIL_KEY);
    sessionStorage.removeItem(REGISTER_TOKEN_KEY);
    saveToken(data.token);
    location.replace("/");
  } catch (err) {
    showMsg(infoError, getErrorMessage(err));
    setLoading(infoBtn, false);
  }
});
