-- =====================================================================
--  CƠ SỞ DỮ LIỆU MẠNG XÃ HỘI (chỉ gồm các bảng)
--  MySQL 8.0 - utf8mb4
-- =====================================================================

SET NAMES utf8mb4;

DROP DATABASE IF EXISTS social_network;
CREATE DATABASE social_network CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE social_network;

-- =====================================================================
-- 1. TÀI KHOẢN & XÁC THỰC
-- =====================================================================

-- Chỉ tạo bản ghi users SAU KHI người dùng nhập đúng OTP (xem bảng pending_registrations)
-- Đăng nhập bằng email + password
CREATE TABLE users (
  id                  BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_code           VARCHAR(20)  NOT NULL UNIQUE,     -- mã người dùng (MND), dùng để tìm bạn
  username            VARCHAR(50)  NOT NULL DEFAULT 'Người dùng',  -- tên hiển thị, không bắt buộc, được trùng
  email               VARCHAR(255) NOT NULL UNIQUE,     -- bắt buộc, dùng để đăng nhập
  password_hash       VARCHAR(255) NOT NULL,            -- bắt buộc, mã hóa bcrypt / Argon2
  phone               VARCHAR(20),
  sex                 ENUM('Nam', 'Nữ'),
  birthday            DATE,
  avatar_url          VARCHAR(500),
  bia_url             VARCHAR(500),                     -- ảnh bìa
  bio                 VARCHAR(500),                     -- tiểu sử
  address             VARCHAR(255),
  role                VARCHAR(20)  NOT NULL DEFAULT 'user',    -- user | admin
  status              VARCHAR(20)  NOT NULL DEFAULT 'active',  -- active | locked | deactivated
  failed_login_count  INT NOT NULL DEFAULT 0,
  last_failed_login_at DATETIME,                        -- lần nhập sai mật khẩu gần nhất
  locked_until        DATETIME,
  last_login_at       DATETIME,
  created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE privacy_settings (
  user_id                 BIGINT PRIMARY KEY,
  profile_visibility      VARCHAR(20) NOT NULL DEFAULT 'public',  -- public | friends | private
  birthday_visibility     VARCHAR(20) NOT NULL DEFAULT 'friends',
  email_visibility        VARCHAR(20) NOT NULL DEFAULT 'private',
  phone_visibility        VARCHAR(20) NOT NULL DEFAULT 'private',
  friend_list_visibility  VARCHAR(20) NOT NULL DEFAULT 'public',
  default_post_visibility VARCHAR(20) NOT NULL DEFAULT 'public',
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- OTP xác thực email khi đăng ký (bảng chỉ lưu OTP, không lưu thông tin đăng ký):
--  1. Nhấn "Đăng ký" -> sinh OTP, lưu hash vào bảng này + gửi OTP về email
--  2. Nhập đúng OTP  -> tạo bản ghi users (sinh user_code) rồi xóa dòng này
--  Gửi lại OTP cho cùng email thì cập nhật dòng cũ (email là UNIQUE):
--    otp_hash mới, otp_expires_at mới, last_sent_at = NOW(), attempt_count = 0, last_attempt_at = NULL
--  Chống spam: chỉ cho gửi lại khi NOW() >= last_sent_at + 60 giây
--  (không dùng updated_at vì nhập sai OTP cũng làm updated_at thay đổi)
CREATE TABLE pending_registrations (
  id             BIGINT AUTO_INCREMENT PRIMARY KEY,
  email          VARCHAR(255) NOT NULL UNIQUE,
  otp_hash       CHAR(64)     NOT NULL,          -- SHA-256 của mã OTP (không lưu mã gốc)
  otp_expires_at DATETIME     NOT NULL,          -- VD: 5 phút sau khi gửi
  last_sent_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,  -- lần gửi OTP gần nhất, chống spam 60 giây
  attempt_count  INT NOT NULL DEFAULT 0,         -- số lần nhập sai OTP
  last_attempt_at DATETIME,                      -- lần nhập OTP gần nhất (NULL = chưa nhập lần nào)
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE password_reset_tokens (
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id     BIGINT NOT NULL,
  token       VARCHAR(255) NOT NULL UNIQUE,
  expires_at  DATETIME NOT NULL,
  used_at     DATETIME,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Duy trì đăng nhập (session id hoặc refresh token JWT)
CREATE TABLE user_sessions (
  id             BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id        BIGINT NOT NULL,
  refresh_token  VARCHAR(500) NOT NULL,
  user_agent     VARCHAR(500),
  ip_address     VARCHAR(45),
  expires_at     DATETIME NOT NULL,
  revoked_at     DATETIME,
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Nhật ký đăng nhập (giới hạn số lần đăng nhập sai)
CREATE TABLE login_attempts (
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id     BIGINT,
  email       VARCHAR(255) NOT NULL,
  ip_address  VARCHAR(45),
  is_success  BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- =====================================================================
-- 2. BÀI ĐĂNG
-- =====================================================================

CREATE TABLE posts (
  id              BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id         BIGINT NOT NULL,
  content         TEXT,
  visibility      VARCHAR(20) NOT NULL DEFAULT 'public',  -- public | friends | private
  shared_post_id  BIGINT,                                 -- bài gốc khi chia sẻ
  status          VARCHAR(20) NOT NULL DEFAULT 'active',  -- active | hidden | deleted
  comments_locked BOOLEAN NOT NULL DEFAULT FALSE,         -- khóa bình luận
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (shared_post_id) REFERENCES posts(id) ON DELETE SET NULL
);

-- Ảnh / video của bài đăng (nhiều file trong 1 bài)
CREATE TABLE post_media (
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  post_id     BIGINT NOT NULL,
  media_url   VARCHAR(500) NOT NULL,
  media_type  VARCHAR(20) NOT NULL,    -- image | video
  file_size   BIGINT,
  sort_order  INT NOT NULL DEFAULT 0,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE
);

CREATE TABLE hashtags (
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(100) NOT NULL UNIQUE,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE post_hashtags (
  post_id     BIGINT NOT NULL,
  hashtag_id  BIGINT NOT NULL,
  PRIMARY KEY (post_id, hashtag_id),
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  FOREIGN KEY (hashtag_id) REFERENCES hashtags(id) ON DELETE CASCADE
);

-- =====================================================================
-- 3. TƯƠNG TÁC
-- =====================================================================

-- Thích / cảm xúc với bài đăng (mỗi người 1 cảm xúc / bài)
CREATE TABLE post_reactions (
  post_id        BIGINT NOT NULL,
  user_id        BIGINT NOT NULL,
  reaction_type  VARCHAR(20) NOT NULL DEFAULT 'like',  -- like | love | haha | wow | sad | angry
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (post_id, user_id),
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Bình luận và trả lời bình luận (parent_id)
CREATE TABLE comments (
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  post_id     BIGINT NOT NULL,
  user_id     BIGINT NOT NULL,
  parent_id   BIGINT,
  content     TEXT NOT NULL,
  status      VARCHAR(20) NOT NULL DEFAULT 'active',  -- active | hidden | deleted
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (parent_id) REFERENCES comments(id) ON DELETE CASCADE
);

CREATE TABLE comment_likes (
  comment_id  BIGINT NOT NULL,
  user_id     BIGINT NOT NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (comment_id, user_id),
  FOREIGN KEY (comment_id) REFERENCES comments(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- =====================================================================
-- 4. BẠN BÈ, THEO DÕI, CHẶN
-- =====================================================================

CREATE TABLE friend_requests (
  id           BIGINT AUTO_INCREMENT PRIMARY KEY,
  sender_id    BIGINT NOT NULL,
  receiver_id  BIGINT NOT NULL,
  status       VARCHAR(20) NOT NULL DEFAULT 'pending',  -- pending | accepted | rejected | cancelled
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (receiver_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE friendships (
  user_id     BIGINT NOT NULL,
  friend_id   BIGINT NOT NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, friend_id),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (friend_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE follows (
  follower_id   BIGINT NOT NULL,   -- người theo dõi
  following_id  BIGINT NOT NULL,   -- người được theo dõi
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (follower_id, following_id),
  FOREIGN KEY (follower_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (following_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE blocks (
  blocker_id  BIGINT NOT NULL,
  blocked_id  BIGINT NOT NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (blocker_id, blocked_id),
  FOREIGN KEY (blocker_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (blocked_id) REFERENCES users(id) ON DELETE CASCADE
);

-- =====================================================================
-- 5. TIN NHẮN
-- =====================================================================

CREATE TABLE conversations (
  id               BIGINT AUTO_INCREMENT PRIMARY KEY,
  last_message_at  DATETIME,
  created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE conversation_members (
  conversation_id  BIGINT NOT NULL,
  user_id          BIGINT NOT NULL,
  last_read_at     DATETIME,                       -- dùng để tính đã đọc / chưa đọc
  is_unread        BOOLEAN NOT NULL DEFAULT FALSE, -- người dùng tự đánh dấu chưa đọc
  joined_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (conversation_id, user_id),
  FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE messages (
  id               BIGINT AUTO_INCREMENT PRIMARY KEY,
  conversation_id  BIGINT NOT NULL,
  sender_id        BIGINT NOT NULL,
  content          TEXT,
  image_url        VARCHAR(500),
  is_read          BOOLEAN NOT NULL DEFAULT FALSE,
  created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
  FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE
);

-- =====================================================================
-- 6. THÔNG BÁO
-- =====================================================================

CREATE TABLE notifications (
  id            BIGINT AUTO_INCREMENT PRIMARY KEY,
  recipient_id  BIGINT NOT NULL,   -- người nhận
  actor_id      BIGINT,            -- người gây ra thông báo
  type          VARCHAR(30) NOT NULL,
  -- friend_request | friend_accept | post_like | post_comment | comment_reply | new_message
  post_id       BIGINT,
  comment_id    BIGINT,
  message_id    BIGINT,
  content       VARCHAR(500),
  is_read       BOOLEAN NOT NULL DEFAULT FALSE,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (recipient_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (actor_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  FOREIGN KEY (comment_id) REFERENCES comments(id) ON DELETE CASCADE,
  FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE
);

-- =====================================================================
-- 7. BÁO CÁO VI PHẠM & QUẢN TRỊ
-- =====================================================================

CREATE TABLE reports (
  id           BIGINT AUTO_INCREMENT PRIMARY KEY,
  reporter_id  BIGINT NOT NULL,
  post_id      BIGINT,             -- báo cáo bài đăng
  comment_id   BIGINT,             -- hoặc báo cáo bình luận
  reason       VARCHAR(255) NOT NULL,
  description  TEXT,
  status       VARCHAR(20) NOT NULL DEFAULT 'pending',  -- pending | resolved | rejected
  handled_by   BIGINT,             -- admin xử lý
  handled_at   DATETIME,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (reporter_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE SET NULL,
  FOREIGN KEY (comment_id) REFERENCES comments(id) ON DELETE SET NULL,
  FOREIGN KEY (handled_by) REFERENCES users(id) ON DELETE SET NULL
);

-- Lịch sử xử lý vi phạm của admin
CREATE TABLE moderation_logs (
  id           BIGINT AUTO_INCREMENT PRIMARY KEY,
  admin_id     BIGINT NOT NULL,
  report_id    BIGINT,
  action       VARCHAR(50) NOT NULL,   -- hide_post | delete_post | delete_comment | lock_user | unlock_user ...
  target_type  VARCHAR(20) NOT NULL,   -- post | comment | user
  target_id    BIGINT NOT NULL,
  note         TEXT,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (admin_id) REFERENCES users(id),
  FOREIGN KEY (report_id) REFERENCES reports(id) ON DELETE SET NULL
);

-- Kháng cáo vi phạm: người dùng không đồng ý với quyết định xử lý của admin
CREATE TABLE appeals (
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id     BIGINT NOT NULL,                 -- người kháng cáo
  report_id   BIGINT NOT NULL,                 -- vi phạm bị xử lý
  reason      TEXT NOT NULL,
  status      VARCHAR(20) NOT NULL DEFAULT 'pending',  -- pending | accepted | rejected
  handled_by  BIGINT,                          -- admin xử lý kháng cáo
  handled_at  DATETIME,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (report_id) REFERENCES reports(id) ON DELETE CASCADE,
  FOREIGN KEY (handled_by) REFERENCES users(id) ON DELETE SET NULL
);
