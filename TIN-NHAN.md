# Kế hoạch làm chức năng nhắn tin

Cập nhật: 19/11/2026. Đánh dấu `[x]` khi đã làm xong.

## 0. Tách riêng hay dùng chung cấu trúc MVC?

**Dùng chung cấu trúc hiện tại** (router → controller → service → model), **chỉ thêm một thư mục `socket/`** cho phần realtime. Không tách thành project hay server riêng.

Lý do:

- Nhắn tin cần dùng lại những thứ đã có: kết nối DB (`config/db.ts`), token đăng nhập (`utils/jwt.ts`), bảng `users`, sau này là `blocks` và `friendships`. Tách server riêng thì phải chép lại hoặc chia sẻ chúng, phức tạp hơn mà không được lợi gì.
- Socket.IO chạy **chung cổng 3000** với Express, nên frontend không phải cấu hình thêm và không vướng CORS.
- Phần lớn chức năng nhắn tin vẫn là API bình thường (lấy danh sách cuộc trò chuyện, tải tin cũ, gửi tin, đánh dấu đã đọc). Chỉ việc **đẩy tin mới xuống người nhận** là cần realtime.

### Nguyên tắc chia việc giữa REST và Socket.IO

| Việc | Dùng | Vì sao |
|---|---|---|
| Gửi tin, tải tin, đánh dấu đã đọc | **REST** (`apiGet` / `apiPost`) | Dùng lại `requireAuth`, `handleError`, xử lý 401 trong `common.js`. Dễ test bằng Postman/curl |
| Báo cho người nhận có tin mới | **Socket.IO** (server → client) | Server phải tự đẩy xuống, client không biết lúc nào mà hỏi |
| "Đang soạn tin…" (tùy chọn) | Socket.IO (client → server → client) | Không cần lưu DB |

Tức là: **mọi việc ghi vào DB đi qua REST**. Service sau khi lưu xong thì gọi Socket.IO để đẩy tin xuống. Thư mục `socket/` chỉ lo xác thực kết nối và đưa user vào đúng "phòng", nên rất mỏng.

---

## 1. Cài thêm

```bash
npm install socket.io
```

(chạy trong `backend`). Gói này có sẵn kiểu TypeScript. Phía trình duyệt **không cần cài**: server tự phục vụ file `/socket.io/socket.io.js`.

---

## 2. Backend

### File mới

| File | Việc |
|---|---|
| `src/socket/index.ts` | `initSocket(server)`: tạo `io`, kiểm tra token khi kết nối (dùng `verifyLoginToken`), cho mỗi user vào phòng `user:<id>`. Xuất hàm `emitToUser(userId, event, data)` để service gọi |
| `src/routers/message.routers.ts` | Khai báo các route ở mục 2.3, tất cả gắn `requireAuth` |
| `src/controllers/message.controller.ts` | Đọc `req.user.userId`, `req.params`, `req.body`, gọi service, trả JSON. Dùng `handleError` giống `auth.controller.ts` |
| `src/service/message.service.ts` | Logic: kiểm tra là thành viên cuộc trò chuyện, kiểm tra chặn, tạo cuộc trò chuyện 1-1, lưu tin rồi gọi `emitToUser` |
| `src/models/conversation.model.ts` | SQL bảng `conversations` + `conversation_members` |
| `src/models/message.model.ts` | SQL bảng `messages` |

Nên chuyển `handleError` ra một file dùng chung (ví dụ `src/utils/handleError.ts`), vì controller mới cũng cần nó.

### File cần sửa

| File | Sửa gì |
|---|---|
| `src/index.ts` | Đổi `app.listen(...)` thành `const server = http.createServer(app); initSocket(server); server.listen(...)`. Thêm `app.use("/api/conversations", messageRoutes)` |
| `package.json` | Thêm `socket.io` (lệnh `npm install` tự làm) |

### API

| Method | Đường dẫn | Việc |
|---|---|---|
| `GET` | `/api/conversations` | Danh sách cuộc trò chuyện của mình: người kia (tên, avatar), tin cuối, số tin chưa đọc. Sắp theo `last_message_at` mới nhất |
| `POST` | `/api/conversations` | Body `{ userId }`. Tìm cuộc trò chuyện 1-1 với người đó, chưa có thì tạo mới. Trả về `id` |
| `GET` | `/api/conversations/:id/messages?before=<messageId>` | 30 tin, cũ dần. `before` để tải tiếp khi cuộn lên (phân trang bằng cursor như feed) |
| `POST` | `/api/conversations/:id/messages` | Body `{ content }`. Lưu tin, cập nhật `last_message_at`, đẩy `message:new` tới người nhận |
| `POST` | `/api/conversations/:id/read` | Cập nhật `last_read_at = NOW()` của mình, đẩy `conversation:read` tới người kia |

### Sự kiện Socket.IO

| Sự kiện | Chiều | Dữ liệu |
|---|---|---|
| `message:new` | server → người nhận (và các tab khác của người gửi) | Tin vừa gửi + `conversation_id` |
| `conversation:read` | server → người kia | `conversation_id`, thời điểm đã đọc (để hiện "Đã xem") |
| `typing` (tùy chọn) | client → server → người kia | `conversation_id` |

### Kiểm tra bắt buộc ở service

- [ ] **Mọi API có `:id` phải kiểm tra mình là thành viên** của cuộc trò chuyện đó. Thiếu bước này thì ai cũng đọc được tin của người khác chỉ bằng cách đổi số `id` trên URL.
- [ ] Không cho nhắn với người đã chặn mình hoặc mình đã chặn (bảng `blocks`).
- [ ] Không cho tạo cuộc trò chuyện với chính mình.
- [ ] `content` không rỗng (sau khi `trim`) và có giới hạn độ dài (ví dụ 2000 ký tự).
- [ ] Socket: token sai hoặc hết hạn thì từ chối kết nối.

### Cần quyết định trước

- [ ] **Ai được nhắn cho ai:** chỉ bạn bè, hay ai cũng nhắn được (giống Messenger có "tin nhắn chờ")? Quyết định này ảnh hưởng tới `POST /api/conversations`.
- [ ] **Chỉ nhắn 1-1** hay có nhóm? Đề xuất làm 1-1 trước. Schema đã hỗ trợ nhóm (`conversation_members` nhiều người) nên sau này mở rộng được.

---

## 3. Cơ sở dữ liệu

Các bảng `conversations`, `conversation_members`, `messages` đã có sẵn. Cần xem lại 2 điểm:

- [ ] **`messages.is_read` và `conversation_members.last_read_at` bị trùng ý nghĩa.** Nên dùng `last_read_at`: số tin chưa đọc là số tin có `created_at > last_read_at` và không phải do mình gửi. Chỉ cần cập nhật một dòng thay vì cập nhật từng tin. Bỏ cột `is_read` cho gọn.
- [ ] **Chưa có gì ngăn tạo 2 cuộc trò chuyện 1-1 cho cùng một cặp người** (ví dụ cả hai bấm "Nhắn tin" cùng lúc). Cách gọn: thêm cột `direct_key VARCHAR(50) UNIQUE` vào `conversations`, giá trị là `"<id nhỏ>_<id lớn>"`. Tạo trùng thì MySQL báo `ER_DUP_ENTRY`, lúc đó lấy lại cuộc trò chuyện đã có.
- [ ] Nên thêm index: `messages (conversation_id, id)` để tải tin nhanh, `conversation_members (user_id)` để lấy danh sách cuộc trò chuyện nhanh.

---

## 4. Frontend

### File mới

| File | Việc |
|---|---|
| `messages.html` | Trang tin nhắn: cột trái danh sách cuộc trò chuyện, cột phải khung chat + ô nhập. Nạp `/socket.io/socket.io.js`, `common.js`, `socket.js`, `pages/messages.js` |
| `js/socket.js` | Kết nối Socket.IO bằng `getToken()`, tự kết nối lại khi mất mạng. **Dùng chung** cho tin nhắn và sau này cho thông báo realtime |
| `js/pages/messages.js` | Tải danh sách, mở cuộc trò chuyện, tải tin cũ khi cuộn lên, gửi tin, nhận `message:new`, đánh dấu đã đọc |
| `css/messages.css` | Giao diện trang tin nhắn |

### File cần sửa

| File | Sửa gì |
|---|---|
| `index.html` | Link "Tin nhắn" (thanh trên và cột trái) đổi `href="#"` thành `href="/messages"`, bỏ `data-soon` |
| `js/common.js` | Thêm `messageApi` (giống `authApi`) gọi các API ở mục 2 |
| `js/pages/home.js` | (Tùy chọn) hiện chấm đỏ số tin chưa đọc trên icon tin nhắn |

`backend/src/index.ts` đã phục vụ file tĩnh với `extensions: ["html"]`, nên `/messages` tự trả về `messages.html`, không cần thêm route.

### Lưu ý khi làm giao diện

- [ ] Hiện nội dung tin bằng `textContent` hoặc `escapeHtml` (đã có trong `home.js`), **không** dùng `innerHTML` với nội dung người dùng gõ, nếu không sẽ bị chèn mã độc (XSS).
- [ ] Khi đang mở đúng cuộc trò chuyện có tin mới thì thêm tin vào khung chat và gọi `/read`. Nếu đang mở cuộc khác thì chỉ tăng số chưa đọc ở danh sách.
- [ ] Mở 2 tab cùng một tài khoản: tin mình gửi ở tab này cũng phải hiện ở tab kia. Server đẩy `message:new` vào phòng `user:<id người gửi>`, nên tự lo được việc này.

---

## 5. Thứ tự làm đề xuất

1. [ ] Sửa schema (mục 3), chạy lại SQL.
2. [ ] Model, service, controller, router cho 5 API. **Chưa cần socket.** Test bằng curl/Postman với 2 tài khoản.
3. [ ] Trang `messages.html` dùng REST: chọn người, gửi tin, tải lại trang thì thấy tin. Lúc này đã nhắn được, chỉ chưa realtime.
4. [ ] Cài `socket.io`, viết `socket/index.ts`, sửa `index.ts`, viết `js/socket.js`.
5. [ ] Service gọi `emitToUser` sau khi lưu tin, frontend nghe `message:new`. Test bằng **2 trình duyệt khác nhau** (hoặc 1 trình duyệt thường + 1 tab ẩn danh) đăng nhập 2 tài khoản.
6. [ ] Đã đọc / chưa đọc, chấm đỏ trên icon.
7. [ ] (Tùy chọn) "Đang soạn tin…", gửi ảnh (`image_url`).

Làm theo thứ tự này thì sau bước 3 đã có thứ chạy được để demo, và phần khó (realtime) được tách riêng để dễ tìm lỗi.
