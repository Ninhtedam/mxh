# Những điểm cần cải thiện

Cập nhật: 19/11/2026. Đánh dấu `[x]` khi đã sửa xong.

Mức độ: **Lỗi** = chạy sai, nên sửa sớm · **Nên làm** = cải thiện đáng làm · **Tùy chọn** = làm nếu còn thời gian

---

## 1. Đăng nhập, đăng ký, quên mật khẩu

### Lỗi

- [ ] **Thông báo khóa OTP sai đơn vị (giây hiển thị thành phút).**
  `lsa` trong `email.model.ts` tính bằng **giây** (`TIMESTAMPDIFF(SECOND, last_sent_at, now())`), nhưng `auth.service.ts` ghép thẳng vào câu "phút":
  - dòng 31: `` `Nhập sai quá nhiều. Vui lòng chờ ${Math.abs(lsa)} phút` ``
  - dòng 71: `` `Nhập sai quá nhiều. Vui lòng chờ ${Math.abs(findByEmailPr.lsa)} phút` ``

  Khi bị khóa 30 phút sẽ hiện "Vui lòng chờ 1800 phút". Sửa: `Math.ceil(Math.abs(lsa) / 60)`.

- [ ] **Đăng nhập không kiểm tra `users.status`.** Tài khoản có `status = 'locked'` hoặc `'deactivated'` vẫn đăng nhập được. Thêm `status` vào câu SELECT của `loginInformation` và `throw` 403 nếu khác `'active'`.

- [ ] **Đăng ký không kiểm tra dữ liệu thông tin cá nhân ở backend.** `createUser` đưa thẳng `sex`, `birthday`, `phone` vào DB:
  - `sex` khác `'Nam'` / `'Nữ'` thì MySQL báo lỗi (cột ENUM), người dùng nhận 500 thay vì 400.
  - `birthday` sai định dạng hoặc ở tương lai, `phone` chứa chữ vẫn được lưu.

  Frontend có kiểm tra nhưng ai cũng gọi thẳng API được, nên backend phải kiểm tra lại.

### Nên làm

- [ ] **Chưa test lại thay đổi báo 429 ở lần sai mật khẩu thứ 5** (`auth.service.ts` dòng 192), vì lúc sửa MySQL đang tắt. Test: sai 5 lần, lần 5 phải nhận 429; lần 6 nhập đúng vẫn bị chặn.
- [ ] **Kiểm tra tài khoản test còn sót trong DB** (do lần test bị dừng giữa chừng):
  ```sql
  DELETE FROM users WHERE email = 'test-lock-claude@example.test';
  ```
- [ ] **Route `/api/users/me` chỉ giải mã token, không kiểm tra user còn tồn tại.** Token của tài khoản đã xóa hoặc bị khóa vẫn nhận 200. Nên truy vấn bảng `users`: không có thì trả 401, có thì trả luôn tên + avatar cho trang chủ.
- [ ] **Mã lỗi "Email chưa được đăng ký" không thống nhất:** `forgotPassword` trả 400, `resetPassword` trả 404. Nên dùng chung 404.
- [ ] **Tên `purpose` trong `jwt.ts` lệch:** hàm tên `signEmailToken` / `verifyEmailToken` nhưng `purpose` vẫn là `"register"`, trong khi token này dùng cho cả quên mật khẩu. Đổi thành `"email"` cho dễ hiểu.

### Tùy chọn

- [ ] **Gửi mail OTP thất bại vẫn tính là đã gửi.** OTP được lưu vào DB (cập nhật `last_sent_at`) trước khi gửi mail. Mail lỗi thì người dùng vẫn phải chờ 10 giây mới gửi lại được. Có thể gửi mail trước rồi mới lưu, hoặc khi lỗi thì đặt lại `last_sent_at`.
- [ ] **Đổi mật khẩu xong, token đăng nhập cũ vẫn dùng được** tới khi hết hạn (7 ngày). Muốn chặn thì thêm cột `password_changed_at`, middleware so với thời điểm tạo token (`iat`).
- [ ] **Khóa đăng nhập mở sớm khoảng 1 phút** do `TIMESTAMPDIFF(Minute, ...)` chỉ lấy phần nguyên. Đổi sang `SECOND` nếu muốn chính xác.

### Đã chấp nhận, không sửa

- Trang quên mật khẩu báo "Email chưa được đăng ký" (để lộ email nào đã có tài khoản). Trang đăng ký cũng buộc phải báo "Email đã được đăng ký" nên giấu ở chỗ khác không còn nhiều ý nghĩa.
- Không hiện số lần nhập sai mật khẩu còn lại (tránh lộ email tồn tại).
- Chỉ khóa theo email, không khóa theo IP hay thiết bị.

---

## 2. Giao diện (frontend HTML)

### Nên làm

- [ ] **Quyết định có giữ ô "Ghi nhớ đăng nhập" không.** Hiện đã bỏ ô này, token luôn lưu `localStorage`. Phương án khác: có ô ghi nhớ, tick thì lưu `localStorage`, không tick thì lưu `sessionStorage` (mất khi đóng tab). Bản này đã từng làm, khôi phục được nhanh.
- [x] **Chưa có nút đăng xuất.** Hàm `logout()` trong `common.js` đã có sẵn, chỉ cần gắn vào giao diện khi làm trang chủ.
- [x] **Trang chủ (`index.html`) đang trống.** Đã có giao diện bảng tin, hiện trạng thái trống. Khi có API bài viết / bạn bè: sửa `loadPostsPage`, `loadRequests`, `loadSuggestions` và phần đăng bài trong `js/pages/home.js`.

### Tùy chọn

- [ ] **Đã đăng nhập mà vào `/login` hoặc `/register` vẫn hiện form.** Có thể kiểm tra token rồi chuyển thẳng về `/`.

---

## 3. Cơ sở dữ liệu (`tailieu/db.sql`)

- [ ] **3 bảng chưa dùng tới:**
  - `password_reset_tokens`: đã thay bằng JWT (`signEmailToken`). Có thể xóa.
  - `login_attempts`: đã thay bằng cột `failed_login_count`, `last_failed_login_at`, `locked_until` trong `users`. Có thể xóa.
  - `user_sessions`: giữ lại nếu sau này làm "quản lý thiết bị đăng nhập", không thì xóa.
- [ ] **Ghi chú trong `db.sql` về chống spam OTP ghi "60 giây"** nhưng code đang dùng 10 giây. Sửa ghi chú cho khớp.

---

## 4. Dự án và git

- [ ] **Chưa commit** toàn bộ thay đổi backend, file `backend/src/utils/mailer.ts` và thư mục `frontend/` (HTML). Nên commit trước khi làm tính năng mới.
- [ ] **`.env` còn dòng `CLIENT_URL`** không dùng tới (đã xóa trong `.env.example`).
- [ ] **Bản React cũ** nằm ở commit `a381607` nếu cần xem lại: `git checkout a381607 -- frontend` (sẽ ghi đè thư mục `frontend` hiện tại, nên chỉ dùng ở nhánh khác).

---

## 5. Chức năng chưa làm (thứ tự đề xuất)

1. Feed bài đăng: `GET /api/posts?cursor=`, quyền xem theo `visibility`, bạn bè, chặn.
2. Bình luận: trả lời 1 cấp, kiểm tra `comments_locked`.
3. Thông báo: lưu DB trước, frontend tải khi mở trang.
4. Nhắn tin: Socket.IO, xác thực JWT khi kết nối.
5. Gắn thông báo vào Socket.IO để đẩy realtime.
