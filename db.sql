-- =====================================================================
--  CƠ SỞ DỮ LIỆU MẠNG XÃ HỘI
--  Hệ quản trị : MySQL 8.0.16+ (InnoDB, utf8mb4, utf8mb4_0900_ai_ci)
--  Mô hình     : KẾT HỢP  Kết bạn (giống Facebook) + Theo dõi (giống Instagram)
--  Chạy file   : mysql -u root -p < mxh.sql
--                (hoặc mở bằng MySQL Workbench / DBeaver và chạy toàn bộ script)
--
--  Ghi chú bảo mật:
--   * Mật khẩu chỉ lưu dạng HASH (bcrypt/Argon2) – băm ở tầng ứng dụng.
--   * Token (xác thực email, đặt lại mật khẩu, refresh token) chỉ lưu SHA-256
--     của token, không lưu token gốc.
--   * Ứng dụng phải dùng prepared statement / ORM để chống SQL injection;
--     escape HTML khi hiển thị để chống XSS.
--   * Trigger KHÔNG chạy khi xóa dây chuyền bằng FOREIGN KEY CASCADE, vì vậy
--     người dùng / bài đăng / bình luận được "xóa mềm" (status = 'deleted').
-- =====================================================================

SET NAMES utf8mb4;

-- DROP DATABASE IF EXISTS mxh;   -- bỏ comment nếu muốn tạo lại từ đầu
CREATE DATABASE IF NOT EXISTS mxh
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;   -- ai_ci: tìm kiếm không phân biệt dấu/hoa thường
USE mxh;

-- =====================================================================
-- 1. TÀI KHOẢN & XÁC THỰC
-- =====================================================================

CREATE TABLE users (
  id                  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  username            VARCHAR(30)  NOT NULL,
  email               VARCHAR(255) NOT NULL,
  password_hash       VARCHAR(255) NOT NULL COMMENT 'bcrypt/Argon2 – không bao giờ lưu mật khẩu gốc',
  full_name           VARCHAR(100) NOT NULL,
  avatar_url          VARCHAR(500) NULL,
  cover_url           VARCHAR(500) NULL,
  bio                 VARCHAR(500) NULL,
  date_of_birth       DATE         NULL,
  gender              ENUM('male','female','other','unspecified') NOT NULL DEFAULT 'unspecified',
  phone               VARCHAR(20)  NULL,
  location            VARCHAR(150) NULL,
  website             VARCHAR(255) NULL,
  role                ENUM('user','moderator','admin') NOT NULL DEFAULT 'user',
  status              ENUM('pending','active','locked','deactivated','deleted') NOT NULL DEFAULT 'pending'
                      COMMENT 'pending = chưa xác thực email; locked = admin khóa; deactivated = tự vô hiệu hóa',
  locked_reason       VARCHAR(500) NULL,
  locked_until        DATETIME     NULL COMMENT 'NULL khi status=locked nghĩa là khóa vĩnh viễn',
  email_verified_at   DATETIME     NULL,
  password_changed_at DATETIME     NULL COMMENT 'JWT phát hành trước mốc này coi như hết hiệu lực',
  failed_login_count  INT UNSIGNED NOT NULL DEFAULT 0,
  login_locked_until  DATETIME     NULL COMMENT 'Tạm khóa đăng nhập khi nhập sai mật khẩu nhiều lần',
  last_login_at       DATETIME     NULL,
  last_active_at      DATETIME     NULL,
  friend_count        INT UNSIGNED NOT NULL DEFAULT 0,
  follower_count      INT UNSIGNED NOT NULL DEFAULT 0,
  following_count     INT UNSIGNED NOT NULL DEFAULT 0,
  post_count          INT UNSIGNED NOT NULL DEFAULT 0,
  created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deactivated_at      DATETIME NULL,
  CONSTRAINT uq_users_username UNIQUE (username),
  CONSTRAINT uq_users_email    UNIQUE (email),
  CONSTRAINT chk_users_username CHECK (username REGEXP '^[A-Za-z0-9._]{3,30}$'),
  CONSTRAINT chk_users_email    CHECK (email LIKE '%_@_%._%'),
  INDEX idx_users_status (status),
  INDEX idx_users_created (created_at),
  FULLTEXT INDEX ft_users_search (full_name, username)
) ENGINE=InnoDB COMMENT='Người dùng & quản trị viên (phân biệt bằng role)';

CREATE TABLE user_privacy_settings (
  user_id                      BIGINT UNSIGNED PRIMARY KEY,
  profile_visibility           ENUM('public','friends','private') NOT NULL DEFAULT 'public',
  email_visibility             ENUM('public','friends','private') NOT NULL DEFAULT 'private',
  phone_visibility             ENUM('public','friends','private') NOT NULL DEFAULT 'private',
  birthday_visibility          ENUM('public','friends','private') NOT NULL DEFAULT 'friends',
  friend_list_visibility       ENUM('public','friends','private') NOT NULL DEFAULT 'public',
  follower_list_visibility     ENUM('public','friends','private') NOT NULL DEFAULT 'public',
  default_post_visibility      ENUM('public','friends','private') NOT NULL DEFAULT 'friends',
  who_can_send_friend_request  ENUM('everyone','friends_of_friends','nobody') NOT NULL DEFAULT 'everyone',
  who_can_message              ENUM('everyone','friends','nobody') NOT NULL DEFAULT 'everyone',
  show_online_status           TINYINT(1) NOT NULL DEFAULT 1,
  updated_at                   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_privacy_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB COMMENT='Cấu hình quyền riêng tư (tự tạo khi đăng ký)';

CREATE TABLE email_verification_tokens (
  id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id     BIGINT UNSIGNED NOT NULL,
  token_hash  CHAR(64) NOT NULL COMMENT 'SHA-256 của token gửi qua email',
  expires_at  DATETIME NOT NULL,
  used_at     DATETIME NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_evt_token UNIQUE (token_hash),
  CONSTRAINT fk_evt_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_evt_user (user_id)
) ENGINE=InnoDB;

CREATE TABLE password_reset_tokens (
  id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id     BIGINT UNSIGNED NOT NULL,
  token_hash  CHAR(64) NOT NULL,
  request_ip  VARCHAR(45) NULL,
  expires_at  DATETIME NOT NULL,
  used_at     DATETIME NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_prt_token UNIQUE (token_hash),
  CONSTRAINT fk_prt_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_prt_user (user_id)
) ENGINE=InnoDB;

CREATE TABLE user_sessions (
  id                  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id             BIGINT UNSIGNED NOT NULL,
  refresh_token_hash  CHAR(64) NOT NULL COMMENT 'SHA-256 của refresh token (JWT) hoặc session id',
  device_name         VARCHAR(100) NULL,
  user_agent          VARCHAR(500) NULL,
  ip_address          VARCHAR(45)  NULL,
  created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_used_at        DATETIME NULL,
  expires_at          DATETIME NOT NULL,
  revoked_at          DATETIME NULL COMMENT 'Đăng xuất / đổi mật khẩu / bị khóa',
  CONSTRAINT uq_sessions_token UNIQUE (refresh_token_hash),
  CONSTRAINT fk_sessions_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_sessions_user (user_id, revoked_at)
) ENGINE=InnoDB COMMENT='Duy trì đăng nhập (session / refresh token JWT)';

CREATE TABLE login_attempts (
  id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id         BIGINT UNSIGNED NULL,
  identifier      VARCHAR(255) NOT NULL COMMENT 'email hoặc username đã nhập',
  ip_address      VARCHAR(45)  NOT NULL,
  user_agent      VARCHAR(500) NULL,
  is_success      TINYINT(1)   NOT NULL,
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_login_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
  INDEX idx_login_identifier (identifier, created_at),
  INDEX idx_login_ip (ip_address, created_at)
) ENGINE=InnoDB COMMENT='Nhật ký đăng nhập – phục vụ giới hạn số lần đăng nhập';

CREATE TABLE api_rate_limits (
  rate_key       VARCHAR(191) NOT NULL COMMENT 'VD: ip:1.2.3.4:login, user:15:post_create',
  window_start   DATETIME NOT NULL,
  request_count  INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (rate_key, window_start)
) ENGINE=InnoDB COMMENT='Giới hạn tần suất request (có thể thay bằng Redis khi triển khai thật)';

-- =====================================================================
-- 2. FILE TẢI LÊN (ảnh, video)
-- =====================================================================

CREATE TABLE media_files (
  id                BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  uploader_id       BIGINT UNSIGNED NOT NULL,
  purpose           ENUM('post','comment','message','avatar','cover') NOT NULL,
  media_type        ENUM('image','video') NOT NULL,
  mime_type         VARCHAR(100) NOT NULL,
  file_size         BIGINT UNSIGNED NOT NULL COMMENT 'byte',
  storage_key       VARCHAR(500) NOT NULL COMMENT 'Tên file đã đổi ngẫu nhiên trên storage (S3/Cloudinary/đĩa)',
  url               VARCHAR(500) NOT NULL,
  original_name     VARCHAR(255) NULL,
  width             INT UNSIGNED NULL,
  height            INT UNSIGNED NULL,
  duration_seconds  INT UNSIGNED NULL,
  checksum_sha256   CHAR(64) NULL,
  status            ENUM('uploading','ready','deleted') NOT NULL DEFAULT 'ready',
  created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_media_uploader FOREIGN KEY (uploader_id) REFERENCES users(id) ON DELETE CASCADE,
  -- Kiểm tra loại file & dung lượng (ứng dụng vẫn phải kiểm tra magic bytes khi upload)
  CONSTRAINT chk_media_mime CHECK (
       (media_type = 'image' AND mime_type IN ('image/jpeg','image/png','image/webp','image/gif'))
    OR (media_type = 'video' AND mime_type IN ('video/mp4','video/webm','video/quicktime'))
  ),
  CONSTRAINT chk_media_size CHECK (
       (media_type = 'image' AND file_size BETWEEN 1 AND 10485760)     -- tối đa 10 MB
    OR (media_type = 'video' AND file_size BETWEEN 1 AND 104857600)    -- tối đa 100 MB
  ),
  INDEX idx_media_uploader (uploader_id, created_at)
) ENGINE=InnoDB;

-- =====================================================================
-- 3. BÀI ĐĂNG
-- =====================================================================

CREATE TABLE posts (
  id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id         BIGINT UNSIGNED NOT NULL,
  content         TEXT NULL,
  visibility      ENUM('public','friends','private') NOT NULL DEFAULT 'public',
  post_type       ENUM('text','media','share') NOT NULL DEFAULT 'text',
  shared_post_id  BIGINT UNSIGNED NULL COMMENT 'Bài gốc khi chia sẻ',
  status          ENUM('active','hidden','deleted') NOT NULL DEFAULT 'active'
                  COMMENT 'hidden = admin ẩn do vi phạm; deleted = xóa mềm',
  hidden_reason   VARCHAR(500) NULL,
  hidden_by       BIGINT UNSIGNED NULL,
  reaction_count  INT UNSIGNED NOT NULL DEFAULT 0,
  comment_count   INT UNSIGNED NOT NULL DEFAULT 0,
  share_count     INT UNSIGNED NOT NULL DEFAULT 0,
  is_edited       TINYINT(1) NOT NULL DEFAULT 0,
  edited_at       DATETIME NULL,
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at      DATETIME NULL,
  CONSTRAINT fk_posts_user   FOREIGN KEY (user_id)        REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_posts_shared FOREIGN KEY (shared_post_id) REFERENCES posts(id) ON DELETE SET NULL,
  CONSTRAINT fk_posts_hidden FOREIGN KEY (hidden_by)      REFERENCES users(id) ON DELETE SET NULL,
  INDEX idx_posts_user_feed (user_id, status, id),
  INDEX idx_posts_status_vis (status, visibility, id),
  INDEX idx_posts_shared (shared_post_id),
  INDEX idx_posts_created (created_at),
  FULLTEXT INDEX ft_posts_content (content)
) ENGINE=InnoDB;

CREATE TABLE post_media (
  post_id     BIGINT UNSIGNED NOT NULL,
  media_id    BIGINT UNSIGNED NOT NULL,
  sort_order  TINYINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (post_id, media_id),
  CONSTRAINT fk_pm_post  FOREIGN KEY (post_id)  REFERENCES posts(id)       ON DELETE CASCADE,
  CONSTRAINT fk_pm_media FOREIGN KEY (media_id) REFERENCES media_files(id) ON DELETE CASCADE,
  INDEX idx_pm_order (post_id, sort_order)
) ENGINE=InnoDB COMMENT='Nhiều ảnh/video trong một bài (tối đa 10)';

CREATE TABLE post_edit_history (
  id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  post_id      BIGINT UNSIGNED NOT NULL,
  old_content  TEXT NULL,
  edited_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_peh_post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  INDEX idx_peh_post (post_id, edited_at)
) ENGINE=InnoDB;

CREATE TABLE hashtags (
  id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  tag           VARCHAR(100) NOT NULL COMMENT 'Lưu chữ thường, không có dấu #',
  post_count    INT UNSIGNED NOT NULL DEFAULT 0,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_used_at  DATETIME NULL,
  CONSTRAINT uq_hashtags_tag UNIQUE (tag),
  INDEX idx_hashtags_popular (post_count)
) ENGINE=InnoDB;

CREATE TABLE post_hashtags (
  post_id     BIGINT UNSIGNED NOT NULL,
  hashtag_id  BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (post_id, hashtag_id),
  CONSTRAINT fk_ph_post FOREIGN KEY (post_id)    REFERENCES posts(id)    ON DELETE CASCADE,
  CONSTRAINT fk_ph_tag  FOREIGN KEY (hashtag_id) REFERENCES hashtags(id) ON DELETE CASCADE,
  INDEX idx_ph_tag (hashtag_id, post_id)
) ENGINE=InnoDB;

-- =====================================================================
-- 4. TƯƠNG TÁC: CẢM XÚC, BÌNH LUẬN
-- =====================================================================

CREATE TABLE post_reactions (
  post_id        BIGINT UNSIGNED NOT NULL,
  user_id        BIGINT UNSIGNED NOT NULL,
  reaction_type  ENUM('like','love','care','haha','wow','sad','angry') NOT NULL DEFAULT 'like',
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (post_id, user_id) COMMENT 'Mỗi người 1 cảm xúc / bài',
  CONSTRAINT fk_pr_post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  CONSTRAINT fk_pr_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_pr_user (user_id),
  INDEX idx_pr_type (post_id, reaction_type),
  INDEX idx_pr_created (created_at)
) ENGINE=InnoDB;

CREATE TABLE comments (
  id                BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  post_id           BIGINT UNSIGNED NOT NULL,
  user_id           BIGINT UNSIGNED NOT NULL,
  parent_id         BIGINT UNSIGNED NULL COMMENT 'Trả lời bình luận (tối đa 2 cấp như Facebook)',
  reply_to_user_id  BIGINT UNSIGNED NULL,
  content           TEXT NULL,
  media_id          BIGINT UNSIGNED NULL,
  status            ENUM('active','hidden','deleted') NOT NULL DEFAULT 'active',
  like_count        INT UNSIGNED NOT NULL DEFAULT 0,
  is_edited         TINYINT(1) NOT NULL DEFAULT 0,
  created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at        DATETIME NULL,
  CONSTRAINT fk_cmt_post     FOREIGN KEY (post_id)          REFERENCES posts(id)       ON DELETE CASCADE,
  CONSTRAINT fk_cmt_user     FOREIGN KEY (user_id)          REFERENCES users(id)       ON DELETE CASCADE,
  CONSTRAINT fk_cmt_parent   FOREIGN KEY (parent_id)        REFERENCES comments(id)    ON DELETE CASCADE,
  CONSTRAINT fk_cmt_reply_to FOREIGN KEY (reply_to_user_id) REFERENCES users(id)       ON DELETE SET NULL,
  CONSTRAINT fk_cmt_media    FOREIGN KEY (media_id)         REFERENCES media_files(id) ON DELETE SET NULL,
  INDEX idx_cmt_post (post_id, parent_id, id),
  INDEX idx_cmt_user (user_id),
  INDEX idx_cmt_created (created_at)
) ENGINE=InnoDB;

CREATE TABLE comment_reactions (
  comment_id     BIGINT UNSIGNED NOT NULL,
  user_id        BIGINT UNSIGNED NOT NULL,
  reaction_type  ENUM('like','love','care','haha','wow','sad','angry') NOT NULL DEFAULT 'like',
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (comment_id, user_id),
  CONSTRAINT fk_cr_comment FOREIGN KEY (comment_id) REFERENCES comments(id) ON DELETE CASCADE,
  CONSTRAINT fk_cr_user    FOREIGN KEY (user_id)    REFERENCES users(id)    ON DELETE CASCADE,
  INDEX idx_cr_user (user_id)
) ENGINE=InnoDB;

-- =====================================================================
-- 5. BẠN BÈ, THEO DÕI, CHẶN
-- =====================================================================

CREATE TABLE friend_requests (
  id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sender_id     BIGINT UNSIGNED NOT NULL,
  receiver_id   BIGINT UNSIGNED NOT NULL,
  status        ENUM('pending','accepted','rejected','cancelled') NOT NULL DEFAULT 'pending',
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  responded_at  DATETIME NULL,
  CONSTRAINT uq_fr_pair UNIQUE (sender_id, receiver_id) COMMENT 'Gửi lại thì cập nhật dòng cũ về pending',
  CONSTRAINT fk_fr_sender   FOREIGN KEY (sender_id)   REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_fr_receiver FOREIGN KEY (receiver_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_fr_receiver (receiver_id, status, created_at),
  INDEX idx_fr_sender (sender_id, status, created_at)
) ENGINE=InnoDB;

CREATE TABLE friendships (
  user_low_id   BIGINT UNSIGNED NOT NULL COMMENT 'Luôn là id nhỏ hơn (trigger tự sắp xếp)',
  user_high_id  BIGINT UNSIGNED NOT NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_low_id, user_high_id),
  CONSTRAINT fk_fs_low  FOREIGN KEY (user_low_id)  REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_fs_high FOREIGN KEY (user_high_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_fs_high (user_high_id)
) ENGINE=InnoDB COMMENT='Mỗi cặp bạn bè chỉ lưu 1 dòng';

CREATE TABLE follows (
  follower_id   BIGINT UNSIGNED NOT NULL,
  following_id  BIGINT UNSIGNED NOT NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (follower_id, following_id),
  CONSTRAINT fk_fo_follower  FOREIGN KEY (follower_id)  REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_fo_following FOREIGN KEY (following_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_fo_following (following_id, created_at)
) ENGINE=InnoDB;

CREATE TABLE user_blocks (
  blocker_id  BIGINT UNSIGNED NOT NULL,
  blocked_id  BIGINT UNSIGNED NOT NULL,
  reason      VARCHAR(255) NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (blocker_id, blocked_id),
  CONSTRAINT fk_ub_blocker FOREIGN KEY (blocker_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_ub_blocked FOREIGN KEY (blocked_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_ub_blocked (blocked_id)
) ENGINE=InnoDB;

-- =====================================================================
-- 6. TIN NHẮN
-- =====================================================================

CREATE TABLE conversations (
  id                 BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  conversation_type  ENUM('direct') NOT NULL DEFAULT 'direct' COMMENT 'Có thể mở rộng thêm group sau',
  user_low_id        BIGINT UNSIGNED NULL,
  user_high_id       BIGINT UNSIGNED NULL,
  last_message_id    BIGINT UNSIGNED NULL,
  last_message_at    DATETIME NULL,
  created_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_conv_direct UNIQUE (user_low_id, user_high_id) COMMENT 'Mỗi cặp chỉ 1 cuộc trò chuyện riêng',
  CONSTRAINT fk_conv_low  FOREIGN KEY (user_low_id)  REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_conv_high FOREIGN KEY (user_high_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_conv_last (last_message_at)
) ENGINE=InnoDB;

CREATE TABLE conversation_participants (
  conversation_id            BIGINT UNSIGNED NOT NULL,
  user_id                    BIGINT UNSIGNED NOT NULL,
  last_read_message_id       BIGINT UNSIGNED NULL,
  last_read_at               DATETIME NULL,
  unread_count               INT UNSIGNED NOT NULL DEFAULT 0,
  is_marked_unread           TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Người dùng tự đánh dấu chưa đọc',
  is_muted                   TINYINT(1) NOT NULL DEFAULT 0,
  cleared_before_message_id  BIGINT UNSIGNED NULL COMMENT 'Xóa lịch sử phía mình',
  hidden_at                  DATETIME NULL COMMENT 'Ẩn cuộc trò chuyện; tự hiện lại khi có tin mới',
  joined_at                  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (conversation_id, user_id),
  CONSTRAINT fk_cp_conv FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
  CONSTRAINT fk_cp_user FOREIGN KEY (user_id)         REFERENCES users(id)         ON DELETE CASCADE,
  INDEX idx_cp_user (user_id, hidden_at)
) ENGINE=InnoDB;

CREATE TABLE messages (
  id                 BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  conversation_id    BIGINT UNSIGNED NOT NULL,
  sender_id          BIGINT UNSIGNED NOT NULL,
  message_type       ENUM('text','image','system') NOT NULL DEFAULT 'text',
  content            TEXT NULL,
  client_message_id  VARCHAR(64) NULL COMMENT 'ID do client (Socket.IO) sinh ra để chống gửi trùng',
  created_at         DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  edited_at          DATETIME NULL,
  deleted_at         DATETIME NULL COMMENT 'Thu hồi tin nhắn',
  CONSTRAINT uq_msg_client UNIQUE (sender_id, client_message_id),
  CONSTRAINT fk_msg_conv   FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
  CONSTRAINT fk_msg_sender FOREIGN KEY (sender_id)       REFERENCES users(id)         ON DELETE CASCADE,
  INDEX idx_msg_conv (conversation_id, id)
) ENGINE=InnoDB;

CREATE TABLE message_attachments (
  message_id  BIGINT UNSIGNED NOT NULL,
  media_id    BIGINT UNSIGNED NOT NULL,
  sort_order  TINYINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (message_id, media_id),
  CONSTRAINT fk_ma_msg   FOREIGN KEY (message_id) REFERENCES messages(id)    ON DELETE CASCADE,
  CONSTRAINT fk_ma_media FOREIGN KEY (media_id)   REFERENCES media_files(id) ON DELETE CASCADE
) ENGINE=InnoDB;

ALTER TABLE conversations
  ADD CONSTRAINT fk_conv_last_msg FOREIGN KEY (last_message_id) REFERENCES messages(id) ON DELETE SET NULL;

-- =====================================================================
-- 7. THÔNG BÁO
-- =====================================================================

CREATE TABLE notifications (
  id                 BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  recipient_id       BIGINT UNSIGNED NOT NULL,
  actor_id           BIGINT UNSIGNED NULL COMMENT 'Người gây ra thông báo (NULL = hệ thống)',
  type               ENUM('friend_request','friend_accept','new_follower',
                          'post_reaction','post_comment','comment_reply','comment_reaction',
                          'post_share','new_message','report_resolved','account_warning','system') NOT NULL,
  post_id            BIGINT UNSIGNED NULL,
  comment_id         BIGINT UNSIGNED NULL,
  friend_request_id  BIGINT UNSIGNED NULL,
  conversation_id    BIGINT UNSIGNED NULL,
  content            VARCHAR(500) NULL COMMENT 'Nội dung tùy chỉnh (thông báo hệ thống)',
  is_read            TINYINT(1) NOT NULL DEFAULT 0,
  read_at            DATETIME NULL,
  created_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_nt_recipient FOREIGN KEY (recipient_id)      REFERENCES users(id)           ON DELETE CASCADE,
  CONSTRAINT fk_nt_actor     FOREIGN KEY (actor_id)          REFERENCES users(id)           ON DELETE CASCADE,
  CONSTRAINT fk_nt_post      FOREIGN KEY (post_id)           REFERENCES posts(id)           ON DELETE CASCADE,
  CONSTRAINT fk_nt_comment   FOREIGN KEY (comment_id)        REFERENCES comments(id)        ON DELETE CASCADE,
  CONSTRAINT fk_nt_fr        FOREIGN KEY (friend_request_id) REFERENCES friend_requests(id) ON DELETE CASCADE,
  CONSTRAINT fk_nt_conv      FOREIGN KEY (conversation_id)   REFERENCES conversations(id)   ON DELETE CASCADE,
  INDEX idx_nt_recipient (recipient_id, is_read, id)
) ENGINE=InnoDB;

-- =====================================================================
-- 8. BÁO CÁO VI PHẠM & QUẢN TRỊ
-- =====================================================================

CREATE TABLE reports (
  id                BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  reporter_id       BIGINT UNSIGNED NOT NULL,
  target_type       ENUM('post','comment','user','message') NOT NULL,
  post_id           BIGINT UNSIGNED NULL,
  comment_id        BIGINT UNSIGNED NULL,
  message_id        BIGINT UNSIGNED NULL,
  reported_user_id  BIGINT UNSIGNED NULL COMMENT 'Chủ nội dung bị báo cáo (trigger tự điền)',
  reason            ENUM('spam','harassment','hate_speech','violence','nudity','false_information',
                         'scam','intellectual_property','self_harm','impersonation','other') NOT NULL,
  description       VARCHAR(1000) NULL,
  status            ENUM('pending','reviewing','resolved','rejected') NOT NULL DEFAULT 'pending',
  handled_by        BIGINT UNSIGNED NULL,
  handled_at        DATETIME NULL,
  resolution_note   VARCHAR(1000) NULL,
  created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_rp_reporter FOREIGN KEY (reporter_id)      REFERENCES users(id)    ON DELETE CASCADE,
  CONSTRAINT fk_rp_post     FOREIGN KEY (post_id)          REFERENCES posts(id)    ON DELETE SET NULL,
  CONSTRAINT fk_rp_comment  FOREIGN KEY (comment_id)       REFERENCES comments(id) ON DELETE SET NULL,
  CONSTRAINT fk_rp_message  FOREIGN KEY (message_id)       REFERENCES messages(id) ON DELETE SET NULL,
  CONSTRAINT fk_rp_user     FOREIGN KEY (reported_user_id) REFERENCES users(id)    ON DELETE SET NULL,
  CONSTRAINT fk_rp_handler  FOREIGN KEY (handled_by)       REFERENCES users(id)    ON DELETE SET NULL,
  INDEX idx_rp_status (status, created_at),
  INDEX idx_rp_post (post_id),
  INDEX idx_rp_comment (comment_id),
  INDEX idx_rp_user (reported_user_id)
) ENGINE=InnoDB;

CREATE TABLE moderation_logs (
  id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  admin_id     BIGINT UNSIGNED NOT NULL,
  report_id    BIGINT UNSIGNED NULL,
  action       ENUM('hide_post','unhide_post','delete_post','restore_post',
                    'hide_comment','unhide_comment','delete_comment','restore_comment',
                    'lock_user','unlock_user','warn_user','change_role',
                    'resolve_report','reject_report') NOT NULL,
  target_type  ENUM('post','comment','user','message','report') NOT NULL,
  target_id    BIGINT UNSIGNED NOT NULL COMMENT 'Không đặt FK để giữ lịch sử kể cả khi nội dung bị xóa',
  reason       VARCHAR(1000) NULL,
  metadata     JSON NULL,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_ml_admin  FOREIGN KEY (admin_id)  REFERENCES users(id)   ON DELETE RESTRICT,
  CONSTRAINT fk_ml_report FOREIGN KEY (report_id) REFERENCES reports(id) ON DELETE SET NULL,
  INDEX idx_ml_target (target_type, target_id),
  INDEX idx_ml_admin (admin_id, created_at),
  INDEX idx_ml_created (created_at)
) ENGINE=InnoDB COMMENT='Lịch sử xử lý vi phạm';

CREATE TABLE search_history (
  id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id      BIGINT UNSIGNED NOT NULL,
  keyword      VARCHAR(255) NOT NULL,
  search_type  ENUM('all','user','post','hashtag') NOT NULL DEFAULT 'all',
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_sh_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_sh_user (user_id, created_at)
) ENGINE=InnoDB;

-- =====================================================================
-- 9. VIEW
-- =====================================================================

-- Danh sách bạn bè theo 2 chiều (dễ truy vấn hơn bảng friendships)
CREATE OR REPLACE VIEW v_user_friends AS
  SELECT user_low_id AS user_id, user_high_id AS friend_id, created_at FROM friendships
  UNION ALL
  SELECT user_high_id AS user_id, user_low_id AS friend_id, created_at FROM friendships;

-- Bài đăng kèm tác giả và danh sách media (JSON)
CREATE OR REPLACE VIEW v_post_details AS
SELECT p.id, p.user_id, u.username, u.full_name, u.avatar_url, u.status AS author_status,
       p.content, p.visibility, p.post_type, p.status, p.shared_post_id,
       p.reaction_count, p.comment_count, p.share_count,
       p.is_edited, p.edited_at, p.created_at,
       (SELECT JSON_ARRAYAGG(JSON_OBJECT('id', m.id, 'url', m.url, 'type', m.media_type,
                                         'width', m.width, 'height', m.height, 'order', pm.sort_order))
          FROM post_media pm JOIN media_files m ON m.id = pm.media_id
         WHERE pm.post_id = p.id AND m.status = 'ready') AS media
FROM posts p
JOIN users u ON u.id = p.user_id;

-- Thống kê tổng quan cho trang quản trị
CREATE OR REPLACE VIEW v_admin_overview AS
SELECT
  (SELECT COUNT(*) FROM users WHERE status <> 'deleted')                          AS total_users,
  (SELECT COUNT(*) FROM users WHERE status = 'active')                            AS active_users,
  (SELECT COUNT(*) FROM users WHERE status = 'locked')                            AS locked_users,
  (SELECT COUNT(*) FROM users WHERE created_at >= CURDATE())                      AS new_users_today,
  (SELECT COUNT(*) FROM users WHERE last_active_at >= NOW() - INTERVAL 1 DAY)     AS daily_active_users,
  (SELECT COUNT(*) FROM posts WHERE status = 'active')                            AS total_posts,
  (SELECT COUNT(*) FROM posts WHERE created_at >= CURDATE())                      AS posts_today,
  (SELECT COUNT(*) FROM comments WHERE status = 'active')                         AS total_comments,
  (SELECT COUNT(*) FROM post_reactions)                                           AS total_post_reactions,
  (SELECT COUNT(*) FROM posts WHERE shared_post_id IS NOT NULL)                   AS total_shares,
  (SELECT COUNT(*) FROM messages)                                                 AS total_messages,
  (SELECT COUNT(*) FROM reports WHERE status IN ('pending','reviewing'))          AS open_reports;

-- Thống kê theo ngày (30 ngày gần nhất)
CREATE OR REPLACE VIEW v_admin_daily_stats AS
WITH RECURSIVE days AS (
  SELECT CURDATE() - INTERVAL 29 DAY AS stat_date
  UNION ALL
  SELECT stat_date + INTERVAL 1 DAY FROM days WHERE stat_date < CURDATE()
)
SELECT d.stat_date,
  (SELECT COUNT(*) FROM users u    WHERE u.created_at  >= d.stat_date AND u.created_at  < d.stat_date + INTERVAL 1 DAY) AS new_users,
  (SELECT COUNT(*) FROM posts p    WHERE p.created_at  >= d.stat_date AND p.created_at  < d.stat_date + INTERVAL 1 DAY) AS new_posts,
  (SELECT COUNT(*) FROM comments c WHERE c.created_at  >= d.stat_date AND c.created_at  < d.stat_date + INTERVAL 1 DAY) AS new_comments,
  (SELECT COUNT(*) FROM post_reactions r WHERE r.created_at >= d.stat_date AND r.created_at < d.stat_date + INTERVAL 1 DAY) AS new_reactions,
  (SELECT COUNT(*) FROM reports rp WHERE rp.created_at >= d.stat_date AND rp.created_at < d.stat_date + INTERVAL 1 DAY) AS new_reports
FROM days d;

-- Hàng đợi báo cáo vi phạm cho admin
CREATE OR REPLACE VIEW v_report_queue AS
SELECT r.id, r.target_type, r.post_id, r.comment_id, r.message_id, r.reported_user_id,
       ru.username AS reported_username,
       r.reason, r.description, r.status, r.created_at,
       rp.username AS reporter_username,
       CASE r.target_type
         WHEN 'post'    THEN LEFT(p.content, 200)
         WHEN 'comment' THEN LEFT(c.content, 200)
         WHEN 'message' THEN LEFT(m.content, 200)
         WHEN 'user'    THEN ru.full_name
       END AS target_preview,
       (SELECT COUNT(*) FROM reports r2
         WHERE r2.target_type = r.target_type
           AND r2.status IN ('pending','reviewing')
           AND r2.post_id    <=> r.post_id
           AND r2.comment_id <=> r.comment_id
           AND r2.message_id <=> r.message_id
           AND r2.reported_user_id <=> r.reported_user_id) AS open_reports_on_target
FROM reports r
JOIN users rp      ON rp.id = r.reporter_id
LEFT JOIN users ru ON ru.id = r.reported_user_id
LEFT JOIN posts p  ON p.id  = r.post_id
LEFT JOIN comments c ON c.id = r.comment_id
LEFT JOIN messages m ON m.id = r.message_id
WHERE r.status IN ('pending','reviewing');

-- =====================================================================
-- 10. FUNCTION (kiểm tra quan hệ & quyền xem)
-- =====================================================================
DELIMITER $$

CREATE FUNCTION fn_are_friends(p_a BIGINT UNSIGNED, p_b BIGINT UNSIGNED)
RETURNS TINYINT(1) READS SQL DATA
BEGIN
  IF p_a IS NULL OR p_b IS NULL OR p_a = p_b THEN RETURN 0; END IF;
  RETURN EXISTS (SELECT 1 FROM friendships
                  WHERE user_low_id = LEAST(p_a, p_b) AND user_high_id = GREATEST(p_a, p_b));
END$$

CREATE FUNCTION fn_is_blocked(p_a BIGINT UNSIGNED, p_b BIGINT UNSIGNED)
RETURNS TINYINT(1) READS SQL DATA
COMMENT 'TRUE nếu một trong hai người đã chặn người kia'
BEGIN
  IF p_a IS NULL OR p_b IS NULL THEN RETURN 0; END IF;
  RETURN EXISTS (SELECT 1 FROM user_blocks
                  WHERE (blocker_id = p_a AND blocked_id = p_b)
                     OR (blocker_id = p_b AND blocked_id = p_a));
END$$

CREATE FUNCTION fn_is_admin(p_user_id BIGINT UNSIGNED)
RETURNS TINYINT(1) READS SQL DATA
BEGIN
  RETURN EXISTS (SELECT 1 FROM users WHERE id = p_user_id
                    AND role IN ('admin','moderator') AND status = 'active');
END$$

-- Kiểm tra 1 mức hiển thị (public/friends/private) giữa người xem và chủ sở hữu
CREATE FUNCTION fn_check_visibility(p_viewer_id BIGINT UNSIGNED, p_owner_id BIGINT UNSIGNED, p_visibility VARCHAR(10))
RETURNS TINYINT(1) READS SQL DATA
BEGIN
  IF p_viewer_id IS NOT NULL AND p_viewer_id = p_owner_id THEN RETURN 1; END IF;
  IF fn_is_blocked(p_viewer_id, p_owner_id) THEN RETURN 0; END IF;
  RETURN CASE p_visibility
           WHEN 'public'  THEN 1
           WHEN 'friends' THEN fn_are_friends(p_viewer_id, p_owner_id)
           ELSE 0
         END;
END$$

-- Người xem có được xem bài đăng không (p_viewer_id = NULL: khách chưa đăng nhập)
CREATE FUNCTION fn_can_view_post(p_viewer_id BIGINT UNSIGNED, p_post_id BIGINT UNSIGNED)
RETURNS TINYINT(1) READS SQL DATA
BEGIN
  DECLARE v_owner BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_visibility VARCHAR(10);
  DECLARE v_status VARCHAR(10);
  DECLARE v_owner_status VARCHAR(20);
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_owner = NULL;

  IF p_post_id IS NULL THEN RETURN 0; END IF;
  SELECT p.user_id, p.visibility, p.status, u.status
    INTO v_owner, v_visibility, v_status, v_owner_status
    FROM posts p JOIN users u ON u.id = p.user_id
   WHERE p.id = p_post_id;

  IF v_owner IS NULL OR v_status = 'deleted' THEN RETURN 0; END IF;
  IF p_viewer_id IS NOT NULL AND p_viewer_id = v_owner THEN RETURN 1; END IF;  -- chủ bài thấy cả bài bị ẩn
  IF v_status <> 'active' OR v_owner_status <> 'active' THEN RETURN 0; END IF;
  RETURN fn_check_visibility(p_viewer_id, v_owner, v_visibility);
END$$

-- Có được đăng nhập không: chống brute-force theo tài khoản và theo IP
CREATE FUNCTION fn_can_attempt_login(p_identifier VARCHAR(255), p_ip VARCHAR(45))
RETURNS TINYINT(1) READS SQL DATA
BEGIN
  IF EXISTS (SELECT 1 FROM users
              WHERE (email = p_identifier OR username = p_identifier)
                AND login_locked_until > NOW()) THEN
    RETURN 0;
  END IF;
  IF (SELECT COUNT(*) FROM login_attempts
       WHERE ip_address = p_ip AND is_success = 0
         AND created_at >= NOW() - INTERVAL 15 MINUTE) >= 20 THEN
    RETURN 0;
  END IF;
  RETURN 1;
END$$

DELIMITER ;

-- =====================================================================
-- 11. TRIGGER (toàn vẹn dữ liệu, bộ đếm, quyền sở hữu)
-- =====================================================================
DELIMITER $$

-- ---------- users ----------
CREATE TRIGGER trg_users_ai AFTER INSERT ON users FOR EACH ROW
BEGIN
  INSERT INTO user_privacy_settings (user_id) VALUES (NEW.id);
END$$

-- ---------- friend_requests ----------
CREATE TRIGGER trg_fr_bi BEFORE INSERT ON friend_requests FOR EACH ROW
BEGIN
  IF NEW.sender_id = NEW.receiver_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Không thể tự gửi lời mời kết bạn';
  END IF;
  IF fn_is_blocked(NEW.sender_id, NEW.receiver_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Không thể gửi lời mời cho người dùng này';
  END IF;
END$$

-- ---------- friendships ----------
CREATE TRIGGER trg_fs_bi BEFORE INSERT ON friendships FOR EACH ROW
BEGIN
  DECLARE v_a BIGINT UNSIGNED DEFAULT NEW.user_low_id;
  DECLARE v_b BIGINT UNSIGNED DEFAULT NEW.user_high_id;
  IF v_a = v_b THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Không thể tự kết bạn với chính mình';
  END IF;
  SET NEW.user_low_id = LEAST(v_a, v_b), NEW.user_high_id = GREATEST(v_a, v_b);
END$$

CREATE TRIGGER trg_fs_ai AFTER INSERT ON friendships FOR EACH ROW
BEGIN
  UPDATE users SET friend_count = friend_count + 1 WHERE id IN (NEW.user_low_id, NEW.user_high_id);
END$$

CREATE TRIGGER trg_fs_ad AFTER DELETE ON friendships FOR EACH ROW
BEGIN
  UPDATE users SET friend_count = IF(friend_count > 0, friend_count - 1, 0)
   WHERE id IN (OLD.user_low_id, OLD.user_high_id);
END$$

-- ---------- follows ----------
CREATE TRIGGER trg_fo_bi BEFORE INSERT ON follows FOR EACH ROW
BEGIN
  IF NEW.follower_id = NEW.following_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Không thể tự theo dõi chính mình';
  END IF;
  IF fn_is_blocked(NEW.follower_id, NEW.following_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Không thể theo dõi người dùng này';
  END IF;
END$$

CREATE TRIGGER trg_fo_ai AFTER INSERT ON follows FOR EACH ROW
BEGIN
  UPDATE users SET following_count = following_count + 1 WHERE id = NEW.follower_id;
  UPDATE users SET follower_count  = follower_count  + 1 WHERE id = NEW.following_id;
END$$

CREATE TRIGGER trg_fo_ad AFTER DELETE ON follows FOR EACH ROW
BEGIN
  UPDATE users SET following_count = IF(following_count > 0, following_count - 1, 0) WHERE id = OLD.follower_id;
  UPDATE users SET follower_count  = IF(follower_count  > 0, follower_count  - 1, 0) WHERE id = OLD.following_id;
END$$

-- ---------- user_blocks: chặn => hủy kết bạn, hủy theo dõi, hủy lời mời ----------
CREATE TRIGGER trg_ub_bi BEFORE INSERT ON user_blocks FOR EACH ROW
BEGIN
  IF NEW.blocker_id = NEW.blocked_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Không thể tự chặn chính mình';
  END IF;
END$$

CREATE TRIGGER trg_ub_ai AFTER INSERT ON user_blocks FOR EACH ROW
BEGIN
  DELETE FROM friendships
   WHERE user_low_id = LEAST(NEW.blocker_id, NEW.blocked_id)
     AND user_high_id = GREATEST(NEW.blocker_id, NEW.blocked_id);
  DELETE FROM follows
   WHERE (follower_id = NEW.blocker_id AND following_id = NEW.blocked_id)
      OR (follower_id = NEW.blocked_id AND following_id = NEW.blocker_id);
  UPDATE friend_requests SET status = 'cancelled', responded_at = NOW()
   WHERE status = 'pending'
     AND ((sender_id = NEW.blocker_id AND receiver_id = NEW.blocked_id)
       OR (sender_id = NEW.blocked_id AND receiver_id = NEW.blocker_id));
END$$

-- ---------- posts ----------
CREATE TRIGGER trg_posts_bi BEFORE INSERT ON posts FOR EACH ROW
BEGIN
  DECLARE v_root BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_root_owner BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_root_vis VARCHAR(10);
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_root_owner = NULL;

  IF NEW.shared_post_id IS NOT NULL THEN
    -- Chia sẻ một bài chia sẻ => trỏ về bài gốc
    SELECT IFNULL(shared_post_id, id) INTO v_root FROM posts WHERE id = NEW.shared_post_id;
    SET NEW.shared_post_id = IFNULL(v_root, NEW.shared_post_id);
    SET NEW.post_type = 'share';

    SELECT user_id, visibility INTO v_root_owner, v_root_vis FROM posts WHERE id = NEW.shared_post_id;
    IF NOT fn_can_view_post(NEW.user_id, NEW.shared_post_id) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bạn không có quyền chia sẻ bài đăng này';
    END IF;
    IF v_root_owner <> NEW.user_id AND v_root_vis <> 'public' THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Chỉ có thể chia sẻ bài đăng công khai của người khác';
    END IF;
  END IF;
END$$

CREATE TRIGGER trg_posts_ai AFTER INSERT ON posts FOR EACH ROW
BEGIN
  IF NEW.status = 'active' THEN
    UPDATE users SET post_count = post_count + 1 WHERE id = NEW.user_id;
  END IF;
  -- Lưu ý: share_count của bài gốc được cập nhật ở tầng ứng dụng (MySQL không cho
  -- trigger cập nhật chính bảng posts), xem sp_share_post bên dưới.
END$$

CREATE TRIGGER trg_posts_bu BEFORE UPDATE ON posts FOR EACH ROW
BEGIN
  IF NOT (OLD.content <=> NEW.content) THEN
    SET NEW.is_edited = 1, NEW.edited_at = NOW();
  END IF;
  IF NEW.status = 'deleted' AND OLD.status <> 'deleted' THEN
    SET NEW.deleted_at = NOW();
  END IF;
END$$

CREATE TRIGGER trg_posts_au AFTER UPDATE ON posts FOR EACH ROW
BEGIN
  IF NOT (OLD.content <=> NEW.content) THEN
    INSERT INTO post_edit_history (post_id, old_content) VALUES (OLD.id, OLD.content);
  END IF;
  IF OLD.status = 'active' AND NEW.status <> 'active' THEN
    UPDATE users SET post_count = IF(post_count > 0, post_count - 1, 0) WHERE id = NEW.user_id;
  ELSEIF OLD.status <> 'active' AND NEW.status = 'active' THEN
    UPDATE users SET post_count = post_count + 1 WHERE id = NEW.user_id;
  END IF;
END$$

-- ---------- post_media: tối đa 10 file, phải là file của chủ bài ----------
CREATE TRIGGER trg_pm_bi BEFORE INSERT ON post_media FOR EACH ROW
BEGIN
  IF (SELECT COUNT(*) FROM post_media WHERE post_id = NEW.post_id) >= 10 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Mỗi bài đăng tối đa 10 ảnh/video';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM posts p JOIN media_files m ON m.id = NEW.media_id
                  WHERE p.id = NEW.post_id AND m.uploader_id = p.user_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'File đính kèm không thuộc về người đăng bài';
  END IF;
END$$

-- ---------- post_hashtags ----------
CREATE TRIGGER trg_ph_ai AFTER INSERT ON post_hashtags FOR EACH ROW
BEGIN
  UPDATE hashtags SET post_count = post_count + 1, last_used_at = NOW() WHERE id = NEW.hashtag_id;
END$$

CREATE TRIGGER trg_ph_ad AFTER DELETE ON post_hashtags FOR EACH ROW
BEGIN
  UPDATE hashtags SET post_count = IF(post_count > 0, post_count - 1, 0) WHERE id = OLD.hashtag_id;
END$$

-- ---------- post_reactions ----------
CREATE TRIGGER trg_pr_bi BEFORE INSERT ON post_reactions FOR EACH ROW
BEGIN
  IF NOT fn_can_view_post(NEW.user_id, NEW.post_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bạn không có quyền tương tác với bài đăng này';
  END IF;
END$$

CREATE TRIGGER trg_pr_ai AFTER INSERT ON post_reactions FOR EACH ROW
BEGIN
  UPDATE posts SET reaction_count = reaction_count + 1 WHERE id = NEW.post_id;
END$$

CREATE TRIGGER trg_pr_ad AFTER DELETE ON post_reactions FOR EACH ROW
BEGIN
  UPDATE posts SET reaction_count = IF(reaction_count > 0, reaction_count - 1, 0) WHERE id = OLD.post_id;
END$$

-- ---------- comments ----------
CREATE TRIGGER trg_cmt_bi BEFORE INSERT ON comments FOR EACH ROW
BEGIN
  DECLARE v_parent_post BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_parent_parent BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_parent_user BIGINT UNSIGNED DEFAULT NULL;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_parent_post = NULL;

  IF (NEW.content IS NULL OR TRIM(NEW.content) = '') AND NEW.media_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bình luận không được để trống';
  END IF;
  IF NOT fn_can_view_post(NEW.user_id, NEW.post_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bạn không có quyền bình luận bài đăng này';
  END IF;
  IF NEW.parent_id IS NOT NULL THEN
    SELECT post_id, parent_id, user_id INTO v_parent_post, v_parent_parent, v_parent_user
      FROM comments WHERE id = NEW.parent_id AND status = 'active';
    IF v_parent_post IS NULL OR v_parent_post <> NEW.post_id THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bình luận gốc không tồn tại';
    END IF;
    -- Giữ tối đa 2 cấp: trả lời một câu trả lời => gắn vào bình luận gốc
    IF v_parent_parent IS NOT NULL THEN SET NEW.parent_id = v_parent_parent; END IF;
    IF NEW.reply_to_user_id IS NULL THEN SET NEW.reply_to_user_id = v_parent_user; END IF;
  END IF;
END$$

CREATE TRIGGER trg_cmt_ai AFTER INSERT ON comments FOR EACH ROW
BEGIN
  IF NEW.status = 'active' THEN
    UPDATE posts SET comment_count = comment_count + 1 WHERE id = NEW.post_id;
  END IF;
END$$

CREATE TRIGGER trg_cmt_bu BEFORE UPDATE ON comments FOR EACH ROW
BEGIN
  IF NOT (OLD.content <=> NEW.content) THEN SET NEW.is_edited = 1; END IF;
  IF NEW.status = 'deleted' AND OLD.status <> 'deleted' THEN SET NEW.deleted_at = NOW(); END IF;
END$$

CREATE TRIGGER trg_cmt_au AFTER UPDATE ON comments FOR EACH ROW
BEGIN
  IF OLD.status = 'active' AND NEW.status <> 'active' THEN
    UPDATE posts SET comment_count = IF(comment_count > 0, comment_count - 1, 0) WHERE id = NEW.post_id;
  ELSEIF OLD.status <> 'active' AND NEW.status = 'active' THEN
    UPDATE posts SET comment_count = comment_count + 1 WHERE id = NEW.post_id;
  END IF;
END$$

-- ---------- comment_reactions ----------
CREATE TRIGGER trg_cr_ai AFTER INSERT ON comment_reactions FOR EACH ROW
BEGIN
  UPDATE comments SET like_count = like_count + 1 WHERE id = NEW.comment_id;
END$$

CREATE TRIGGER trg_cr_ad AFTER DELETE ON comment_reactions FOR EACH ROW
BEGIN
  UPDATE comments SET like_count = IF(like_count > 0, like_count - 1, 0) WHERE id = OLD.comment_id;
END$$

-- ---------- conversations ----------
CREATE TRIGGER trg_conv_bi BEFORE INSERT ON conversations FOR EACH ROW
BEGIN
  DECLARE v_a BIGINT UNSIGNED DEFAULT NEW.user_low_id;
  DECLARE v_b BIGINT UNSIGNED DEFAULT NEW.user_high_id;
  IF NEW.conversation_type = 'direct' THEN
    IF v_a IS NULL OR v_b IS NULL OR v_a = v_b THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cuộc trò chuyện riêng cần đúng 2 người khác nhau';
    END IF;
    SET NEW.user_low_id = LEAST(v_a, v_b), NEW.user_high_id = GREATEST(v_a, v_b);
  END IF;
END$$

-- ---------- messages ----------
CREATE TRIGGER trg_msg_bi BEFORE INSERT ON messages FOR EACH ROW
BEGIN
  DECLARE v_low BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_high BIGINT UNSIGNED DEFAULT NULL;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_low = NULL;

  IF NOT EXISTS (SELECT 1 FROM conversation_participants
                  WHERE conversation_id = NEW.conversation_id AND user_id = NEW.sender_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bạn không thuộc cuộc trò chuyện này';
  END IF;
  SELECT user_low_id, user_high_id INTO v_low, v_high FROM conversations WHERE id = NEW.conversation_id;
  IF v_low IS NOT NULL AND fn_is_blocked(v_low, v_high) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Không thể nhắn tin cho người dùng này';
  END IF;
  IF NEW.message_type = 'text' AND (NEW.content IS NULL OR TRIM(NEW.content) = '') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tin nhắn không được để trống';
  END IF;
END$$

CREATE TRIGGER trg_msg_ai AFTER INSERT ON messages FOR EACH ROW
BEGIN
  UPDATE conversations SET last_message_id = NEW.id, last_message_at = NEW.created_at
   WHERE id = NEW.conversation_id;
  UPDATE conversation_participants
     SET unread_count = IF(user_id <> NEW.sender_id, unread_count + 1, unread_count),
         last_read_message_id = IF(user_id = NEW.sender_id, NEW.id, last_read_message_id),
         hidden_at = NULL
   WHERE conversation_id = NEW.conversation_id;
END$$

CREATE TRIGGER trg_ma_bi BEFORE INSERT ON message_attachments FOR EACH ROW
BEGIN
  IF NOT EXISTS (SELECT 1 FROM messages msg JOIN media_files m ON m.id = NEW.media_id
                  WHERE msg.id = NEW.message_id AND m.uploader_id = msg.sender_id
                    AND m.media_type = 'image') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ảnh đính kèm không hợp lệ';
  END IF;
END$$

-- ---------- reports: tự điền chủ nội dung, chống báo cáo trùng ----------
CREATE TRIGGER trg_rp_bi BEFORE INSERT ON reports FOR EACH ROW
BEGIN
  DECLARE v_owner BIGINT UNSIGNED DEFAULT NULL;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_owner = NULL;

  CASE NEW.target_type
    WHEN 'post'    THEN SELECT user_id   INTO v_owner FROM posts    WHERE id = NEW.post_id;
    WHEN 'comment' THEN SELECT user_id   INTO v_owner FROM comments WHERE id = NEW.comment_id;
    WHEN 'message' THEN SELECT sender_id INTO v_owner FROM messages WHERE id = NEW.message_id;
    WHEN 'user'    THEN SELECT id        INTO v_owner FROM users    WHERE id = NEW.reported_user_id;
  END CASE;

  IF v_owner IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nội dung bị báo cáo không tồn tại';
  END IF;
  IF v_owner = NEW.reporter_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Không thể tự báo cáo nội dung của mình';
  END IF;
  SET NEW.reported_user_id = v_owner;

  IF EXISTS (SELECT 1 FROM reports r
              WHERE r.reporter_id = NEW.reporter_id AND r.target_type = NEW.target_type
                AND r.status IN ('pending','reviewing')
                AND r.post_id <=> NEW.post_id AND r.comment_id <=> NEW.comment_id
                AND r.message_id <=> NEW.message_id AND r.reported_user_id <=> NEW.reported_user_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bạn đã báo cáo nội dung này và đang chờ xử lý';
  END IF;
END$$

DELIMITER ;

-- =====================================================================
-- 12. STORED PROCEDURE
-- =====================================================================
DELIMITER $$

-- ---------------------------------------------------------------------
-- 12.1 Xác thực & bảo mật
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_record_login_attempt(
  IN p_identifier VARCHAR(255), IN p_ip VARCHAR(45), IN p_user_agent VARCHAR(500), IN p_success TINYINT)
BEGIN
  DECLARE v_user_id BIGINT UNSIGNED DEFAULT NULL;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_user_id = NULL;

  SELECT id INTO v_user_id FROM users WHERE email = p_identifier OR username = p_identifier LIMIT 1;
  INSERT INTO login_attempts (user_id, identifier, ip_address, user_agent, is_success)
  VALUES (v_user_id, p_identifier, p_ip, p_user_agent, p_success);

  IF v_user_id IS NOT NULL THEN
    IF p_success THEN
      UPDATE users SET failed_login_count = 0, login_locked_until = NULL,
                       last_login_at = NOW(), last_active_at = NOW()
       WHERE id = v_user_id;
    ELSE
      -- MySQL đánh giá phép gán từ trái sang phải: failed_login_count đã được tăng
      UPDATE users SET failed_login_count = failed_login_count + 1,
                       login_locked_until = IF(failed_login_count >= 5, NOW() + INTERVAL 15 MINUTE, login_locked_until)
       WHERE id = v_user_id;
    END IF;
  END IF;
END$$

CREATE PROCEDURE sp_check_rate_limit(
  IN p_key VARCHAR(191), IN p_window_seconds INT, IN p_max_requests INT,
  OUT p_allowed TINYINT, OUT p_current INT)
BEGIN
  DECLARE v_window DATETIME DEFAULT FROM_UNIXTIME(FLOOR(UNIX_TIMESTAMP() / p_window_seconds) * p_window_seconds);
  INSERT INTO api_rate_limits (rate_key, window_start, request_count) VALUES (p_key, v_window, 1)
  ON DUPLICATE KEY UPDATE request_count = request_count + 1;
  SELECT request_count INTO p_current FROM api_rate_limits WHERE rate_key = p_key AND window_start = v_window;
  SET p_allowed = (p_current <= p_max_requests);
END$$

-- Xác thực email bằng hash của token
CREATE PROCEDURE sp_verify_email(IN p_token_hash CHAR(64))
BEGIN
  DECLARE v_user_id BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_token_id BIGINT UNSIGNED;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_user_id = NULL;

  SELECT id, user_id INTO v_token_id, v_user_id FROM email_verification_tokens
   WHERE token_hash = p_token_hash AND used_at IS NULL AND expires_at > NOW();
  IF v_user_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Liên kết xác thực không hợp lệ hoặc đã hết hạn';
  END IF;
  UPDATE email_verification_tokens SET used_at = NOW() WHERE id = v_token_id;
  UPDATE users SET email_verified_at = NOW(),
                   status = IF(status = 'pending', 'active', status)
   WHERE id = v_user_id;
  SELECT v_user_id AS user_id;
END$$

-- Đặt lại mật khẩu (hash mới do ứng dụng tạo bằng bcrypt/Argon2)
CREATE PROCEDURE sp_reset_password(IN p_token_hash CHAR(64), IN p_new_password_hash VARCHAR(255))
BEGIN
  DECLARE v_user_id BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_token_id BIGINT UNSIGNED;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_user_id = NULL;

  SELECT id, user_id INTO v_token_id, v_user_id FROM password_reset_tokens
   WHERE token_hash = p_token_hash AND used_at IS NULL AND expires_at > NOW();
  IF v_user_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Liên kết đặt lại mật khẩu không hợp lệ hoặc đã hết hạn';
  END IF;
  UPDATE password_reset_tokens SET used_at = NOW() WHERE user_id = v_user_id AND used_at IS NULL;
  CALL sp_change_password_hash(v_user_id, p_new_password_hash);
END$$

-- Đổi mật khẩu: lưu hash mới + thu hồi toàn bộ phiên đăng nhập
CREATE PROCEDURE sp_change_password_hash(IN p_user_id BIGINT UNSIGNED, IN p_new_password_hash VARCHAR(255))
BEGIN
  UPDATE users SET password_hash = p_new_password_hash, password_changed_at = NOW(),
                   failed_login_count = 0, login_locked_until = NULL
   WHERE id = p_user_id;
  UPDATE user_sessions SET revoked_at = NOW() WHERE user_id = p_user_id AND revoked_at IS NULL;
END$$

-- Người dùng tự vô hiệu hóa / kích hoạt lại tài khoản
CREATE PROCEDURE sp_set_account_deactivated(IN p_user_id BIGINT UNSIGNED, IN p_deactivate TINYINT)
BEGIN
  IF p_deactivate THEN
    UPDATE users SET status = 'deactivated', deactivated_at = NOW() WHERE id = p_user_id AND status = 'active';
    UPDATE user_sessions SET revoked_at = NOW() WHERE user_id = p_user_id AND revoked_at IS NULL;
  ELSE
    UPDATE users SET status = 'active', deactivated_at = NULL WHERE id = p_user_id AND status = 'deactivated';
  END IF;
  SELECT ROW_COUNT() AS affected;
END$$

-- ---------------------------------------------------------------------
-- 12.2 Hồ sơ cá nhân (đã áp dụng quyền riêng tư)
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_get_user_profile(IN p_viewer_id BIGINT UNSIGNED, IN p_user_id BIGINT UNSIGNED)
BEGIN
  SELECT u.id, u.username, u.full_name, u.avatar_url, u.cover_url,
         fn_check_visibility(p_viewer_id, u.id, s.profile_visibility) AS can_view_full_profile,
         IF(fn_check_visibility(p_viewer_id, u.id, s.profile_visibility), u.bio, NULL)        AS bio,
         IF(fn_check_visibility(p_viewer_id, u.id, s.profile_visibility), u.location, NULL)   AS location,
         IF(fn_check_visibility(p_viewer_id, u.id, s.profile_visibility), u.website, NULL)    AS website,
         IF(fn_check_visibility(p_viewer_id, u.id, s.birthday_visibility), u.date_of_birth, NULL) AS date_of_birth,
         IF(fn_check_visibility(p_viewer_id, u.id, s.email_visibility), u.email, NULL)        AS email,
         IF(fn_check_visibility(p_viewer_id, u.id, s.phone_visibility), u.phone, NULL)        AS phone,
         u.gender, u.friend_count, u.follower_count, u.following_count, u.post_count, u.created_at,
         fn_check_visibility(p_viewer_id, u.id, s.friend_list_visibility)   AS can_view_friends,
         fn_check_visibility(p_viewer_id, u.id, s.follower_list_visibility) AS can_view_followers,
         (p_viewer_id = u.id)                  AS is_me,
         fn_are_friends(p_viewer_id, u.id)     AS is_friend,
         EXISTS (SELECT 1 FROM follows WHERE follower_id = p_viewer_id AND following_id = u.id) AS is_following,
         EXISTS (SELECT 1 FROM follows WHERE follower_id = u.id AND following_id = p_viewer_id) AS follows_me,
         (SELECT CASE WHEN fr.sender_id = p_viewer_id THEN 'sent' ELSE 'received' END
            FROM friend_requests fr
           WHERE fr.status = 'pending'
             AND ((fr.sender_id = p_viewer_id AND fr.receiver_id = u.id)
               OR (fr.sender_id = u.id AND fr.receiver_id = p_viewer_id))
           LIMIT 1) AS pending_request,
         (SELECT COUNT(*) FROM v_user_friends a JOIN v_user_friends b ON a.friend_id = b.friend_id
           WHERE a.user_id = p_viewer_id AND b.user_id = u.id) AS mutual_friends
    FROM users u
    JOIN user_privacy_settings s ON s.user_id = u.id
   WHERE u.id = p_user_id
     AND (u.status = 'active' OR u.id = p_viewer_id)
     AND NOT fn_is_blocked(p_viewer_id, u.id);
END$$

CREATE PROCEDURE sp_get_friend_list(
  IN p_viewer_id BIGINT UNSIGNED, IN p_user_id BIGINT UNSIGNED, IN p_offset INT, IN p_limit INT)
BEGIN
  DECLARE v_limit INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 20), 1), 100);
  DECLARE v_offset INT DEFAULT GREATEST(IFNULL(p_offset, 0), 0);
  IF NOT fn_check_visibility(p_viewer_id, p_user_id,
       (SELECT friend_list_visibility FROM user_privacy_settings WHERE user_id = p_user_id)) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Danh sách bạn bè được đặt ở chế độ riêng tư';
  END IF;
  SELECT u.id, u.username, u.full_name, u.avatar_url, f.created_at AS friends_since,
         fn_are_friends(p_viewer_id, u.id) AS is_my_friend
    FROM v_user_friends f JOIN users u ON u.id = f.friend_id
   WHERE f.user_id = p_user_id AND u.status = 'active'
     AND NOT fn_is_blocked(p_viewer_id, u.id)
   ORDER BY u.full_name
   LIMIT v_offset, v_limit;
END$$

CREATE PROCEDURE sp_get_followers(
  IN p_viewer_id BIGINT UNSIGNED, IN p_user_id BIGINT UNSIGNED, IN p_offset INT, IN p_limit INT)
BEGIN
  DECLARE v_limit INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 20), 1), 100);
  DECLARE v_offset INT DEFAULT GREATEST(IFNULL(p_offset, 0), 0);
  IF NOT fn_check_visibility(p_viewer_id, p_user_id,
       (SELECT follower_list_visibility FROM user_privacy_settings WHERE user_id = p_user_id)) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Danh sách người theo dõi được đặt ở chế độ riêng tư';
  END IF;
  SELECT u.id, u.username, u.full_name, u.avatar_url, fo.created_at AS followed_at
    FROM follows fo JOIN users u ON u.id = fo.follower_id
   WHERE fo.following_id = p_user_id AND u.status = 'active'
     AND NOT fn_is_blocked(p_viewer_id, u.id)
   ORDER BY fo.created_at DESC
   LIMIT v_offset, v_limit;
END$$

-- ---------------------------------------------------------------------
-- 12.3 Bài đăng & bảng tin (phân trang kiểu cursor: truyền id nhỏ nhất đã tải)
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_get_news_feed(IN p_viewer_id BIGINT UNSIGNED, IN p_cursor_id BIGINT UNSIGNED, IN p_limit INT)
BEGIN
  DECLARE v_limit INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 20), 1), 50);
  SELECT v.*, pr.reaction_type AS my_reaction,
         fn_can_view_post(p_viewer_id, v.shared_post_id) AS shared_post_visible
    FROM v_post_details v
    LEFT JOIN post_reactions pr ON pr.post_id = v.id AND pr.user_id = p_viewer_id
   WHERE v.status = 'active' AND v.author_status = 'active'
     AND (p_cursor_id IS NULL OR v.id < p_cursor_id)
     AND (
          v.user_id = p_viewer_id
       OR (v.visibility IN ('public','friends') AND EXISTS (
             SELECT 1 FROM friendships f
              WHERE f.user_low_id = LEAST(v.user_id, p_viewer_id)
                AND f.user_high_id = GREATEST(v.user_id, p_viewer_id)))
       OR (v.visibility = 'public' AND EXISTS (
             SELECT 1 FROM follows fo WHERE fo.follower_id = p_viewer_id AND fo.following_id = v.user_id))
     )
     AND NOT EXISTS (SELECT 1 FROM user_blocks b
                      WHERE (b.blocker_id = p_viewer_id AND b.blocked_id = v.user_id)
                         OR (b.blocker_id = v.user_id AND b.blocked_id = p_viewer_id))
   ORDER BY v.id DESC
   LIMIT v_limit;
END$$

CREATE PROCEDURE sp_get_user_posts(
  IN p_viewer_id BIGINT UNSIGNED, IN p_user_id BIGINT UNSIGNED, IN p_cursor_id BIGINT UNSIGNED, IN p_limit INT)
BEGIN
  DECLARE v_limit INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 20), 1), 50);
  SELECT v.*, pr.reaction_type AS my_reaction,
         fn_can_view_post(p_viewer_id, v.shared_post_id) AS shared_post_visible
    FROM v_post_details v
    LEFT JOIN post_reactions pr ON pr.post_id = v.id AND pr.user_id = p_viewer_id
   WHERE v.user_id = p_user_id
     AND v.status <> 'deleted'
     AND (p_cursor_id IS NULL OR v.id < p_cursor_id)
     AND fn_can_view_post(p_viewer_id, v.id)
   ORDER BY v.id DESC
   LIMIT v_limit;
END$$

CREATE PROCEDURE sp_get_post(IN p_viewer_id BIGINT UNSIGNED, IN p_post_id BIGINT UNSIGNED)
BEGIN
  IF NOT fn_can_view_post(p_viewer_id, p_post_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bài đăng không tồn tại hoặc bạn không có quyền xem';
  END IF;
  SELECT v.*, pr.reaction_type AS my_reaction,
         fn_can_view_post(p_viewer_id, v.shared_post_id) AS shared_post_visible
    FROM v_post_details v
    LEFT JOIN post_reactions pr ON pr.post_id = v.id AND pr.user_id = p_viewer_id
   WHERE v.id = p_post_id;
END$$

-- Chia sẻ bài đăng (tạo bài mới + tăng share_count của bài gốc trong 1 transaction)
CREATE PROCEDURE sp_share_post(
  IN p_user_id BIGINT UNSIGNED, IN p_post_id BIGINT UNSIGNED, IN p_content TEXT, IN p_visibility VARCHAR(10))
BEGIN
  DECLARE v_new_id BIGINT UNSIGNED;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  START TRANSACTION;
    INSERT INTO posts (user_id, content, visibility, post_type, shared_post_id)
    VALUES (p_user_id, p_content, IFNULL(p_visibility, 'public'), 'share', p_post_id);
    SET v_new_id = LAST_INSERT_ID();
    UPDATE posts SET share_count = share_count + 1
     WHERE id = (SELECT shared_post_id FROM (SELECT shared_post_id FROM posts WHERE id = v_new_id) t);
  COMMIT;
  SELECT v_new_id AS post_id;
END$$

-- Sửa / xóa bài: kiểm tra quyền sở hữu
CREATE PROCEDURE sp_update_post(
  IN p_user_id BIGINT UNSIGNED, IN p_post_id BIGINT UNSIGNED, IN p_content TEXT, IN p_visibility VARCHAR(10))
BEGIN
  UPDATE posts SET content = p_content, visibility = IFNULL(p_visibility, visibility)
   WHERE id = p_post_id AND user_id = p_user_id AND status <> 'deleted';
  IF ROW_COUNT() = 0 AND NOT EXISTS (SELECT 1 FROM posts WHERE id = p_post_id AND user_id = p_user_id
                                        AND status <> 'deleted' AND content <=> p_content) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Không tìm thấy bài đăng hoặc bạn không phải chủ bài';
  END IF;
END$$

CREATE PROCEDURE sp_delete_post(IN p_user_id BIGINT UNSIGNED, IN p_post_id BIGINT UNSIGNED)
BEGIN
  UPDATE posts SET status = 'deleted' WHERE id = p_post_id AND user_id = p_user_id AND status <> 'deleted';
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Không tìm thấy bài đăng hoặc bạn không phải chủ bài';
  END IF;
END$$

-- Gắn hashtag cho bài (ứng dụng tách #hashtag từ nội dung rồi gọi)
CREATE PROCEDURE sp_add_post_hashtag(IN p_post_id BIGINT UNSIGNED, IN p_tag VARCHAR(100))
BEGIN
  DECLARE v_tag VARCHAR(100) DEFAULT LOWER(TRIM(LEADING '#' FROM TRIM(p_tag)));
  DECLARE v_tag_id BIGINT UNSIGNED;
  IF v_tag = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Hashtag không hợp lệ';
  END IF;
  INSERT INTO hashtags (tag) VALUES (v_tag)
  ON DUPLICATE KEY UPDATE id = LAST_INSERT_ID(id);
  SET v_tag_id = LAST_INSERT_ID();
  INSERT IGNORE INTO post_hashtags (post_id, hashtag_id) VALUES (p_post_id, v_tag_id);
END$$

-- Thả / đổi / bỏ cảm xúc (p_type = NULL để bỏ)
CREATE PROCEDURE sp_react_post(IN p_user_id BIGINT UNSIGNED, IN p_post_id BIGINT UNSIGNED, IN p_type VARCHAR(10))
BEGIN
  IF p_type IS NULL THEN
    DELETE FROM post_reactions WHERE post_id = p_post_id AND user_id = p_user_id;
  ELSE
    INSERT INTO post_reactions (post_id, user_id, reaction_type) VALUES (p_post_id, p_user_id, p_type)
    ON DUPLICATE KEY UPDATE reaction_type = VALUES(reaction_type);
  END IF;
  SELECT reaction_count FROM posts WHERE id = p_post_id;
END$$

-- Bình luận gốc + số câu trả lời (phân trang cursor)
CREATE PROCEDURE sp_get_comments(
  IN p_viewer_id BIGINT UNSIGNED, IN p_post_id BIGINT UNSIGNED, IN p_parent_id BIGINT UNSIGNED,
  IN p_cursor_id BIGINT UNSIGNED, IN p_limit INT)
BEGIN
  DECLARE v_limit INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 20), 1), 50);
  IF NOT fn_can_view_post(p_viewer_id, p_post_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bạn không có quyền xem bài đăng này';
  END IF;
  SELECT c.id, c.post_id, c.parent_id, c.content, c.like_count, c.is_edited, c.created_at,
         c.user_id, u.username, u.full_name, u.avatar_url,
         c.reply_to_user_id, ru.username AS reply_to_username,
         m.url AS media_url,
         (SELECT COUNT(*) FROM comments r WHERE r.parent_id = c.id AND r.status = 'active') AS reply_count,
         EXISTS (SELECT 1 FROM comment_reactions cr WHERE cr.comment_id = c.id AND cr.user_id = p_viewer_id) AS liked_by_me
    FROM comments c
    JOIN users u ON u.id = c.user_id AND u.status = 'active'
    LEFT JOIN users ru ON ru.id = c.reply_to_user_id
    LEFT JOIN media_files m ON m.id = c.media_id
   WHERE c.post_id = p_post_id
     AND c.parent_id <=> p_parent_id
     AND c.status = 'active'
     AND (p_cursor_id IS NULL OR (IF(p_parent_id IS NULL, c.id < p_cursor_id, c.id > p_cursor_id)))
     AND NOT fn_is_blocked(p_viewer_id, c.user_id)
   ORDER BY CASE WHEN p_parent_id IS NULL THEN -CAST(c.id AS SIGNED) ELSE c.id END  -- bình luận gốc mới nhất trước, trả lời theo thứ tự thời gian
   LIMIT v_limit;
END$$

-- Xóa bình luận: chủ bình luận hoặc chủ bài đăng
CREATE PROCEDURE sp_delete_comment(IN p_user_id BIGINT UNSIGNED, IN p_comment_id BIGINT UNSIGNED)
BEGIN
  UPDATE comments c JOIN posts p ON p.id = c.post_id
     SET c.status = 'deleted'
   WHERE c.id = p_comment_id AND c.status <> 'deleted'
     AND (c.user_id = p_user_id OR p.user_id = p_user_id);
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Không tìm thấy bình luận hoặc bạn không có quyền xóa';
  END IF;
END$$

-- ---------------------------------------------------------------------
-- 12.4 Bạn bè & theo dõi
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_respond_friend_request(
  IN p_user_id BIGINT UNSIGNED, IN p_request_id BIGINT UNSIGNED, IN p_action VARCHAR(10))
BEGIN
  DECLARE v_sender BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_receiver BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_status VARCHAR(10);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  START TRANSACTION;
    SELECT sender_id, receiver_id, status INTO v_sender, v_receiver, v_status
      FROM friend_requests WHERE id = p_request_id FOR UPDATE;
    IF v_receiver IS NULL OR v_receiver <> p_user_id THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bạn không có quyền xử lý lời mời này';
    END IF;
    IF v_status <> 'pending' THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lời mời đã được xử lý trước đó';
    END IF;

    IF p_action = 'accept' THEN
      UPDATE friend_requests SET status = 'accepted', responded_at = NOW() WHERE id = p_request_id;
      INSERT INTO friendships (user_low_id, user_high_id) VALUES (v_sender, v_receiver)
      ON DUPLICATE KEY UPDATE created_at = created_at;
      -- Kết bạn thì tự theo dõi lẫn nhau (để bài công khai hiện trên bảng tin)
      INSERT INTO follows (follower_id, following_id) VALUES (v_sender, v_receiver)
      ON DUPLICATE KEY UPDATE created_at = created_at;
      INSERT INTO follows (follower_id, following_id) VALUES (v_receiver, v_sender)
      ON DUPLICATE KEY UPDATE created_at = created_at;
    ELSEIF p_action = 'reject' THEN
      UPDATE friend_requests SET status = 'rejected', responded_at = NOW() WHERE id = p_request_id;
    ELSE
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Hành động không hợp lệ (accept/reject)';
    END IF;
  COMMIT;
END$$

CREATE PROCEDURE sp_send_friend_request(IN p_sender_id BIGINT UNSIGNED, IN p_receiver_id BIGINT UNSIGNED)
BEGIN
  DECLARE v_setting VARCHAR(30) DEFAULT NULL;
  DECLARE v_reverse_id BIGINT UNSIGNED DEFAULT NULL;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_reverse_id = NULL;

  IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_receiver_id AND status = 'active') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Người dùng không tồn tại';
  END IF;
  IF fn_are_friends(p_sender_id, p_receiver_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Hai người đã là bạn bè';
  END IF;

  SELECT who_can_send_friend_request INTO v_setting FROM user_privacy_settings WHERE user_id = p_receiver_id;
  IF v_setting = 'nobody' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Người dùng này không nhận lời mời kết bạn';
  END IF;
  IF v_setting = 'friends_of_friends' AND NOT EXISTS (
       SELECT 1 FROM v_user_friends a JOIN v_user_friends b ON a.friend_id = b.friend_id
        WHERE a.user_id = p_sender_id AND b.user_id = p_receiver_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Chỉ bạn của bạn bè mới gửi được lời mời';
  END IF;

  -- Nếu người kia đã gửi lời mời cho mình => tự động chấp nhận
  SELECT id INTO v_reverse_id FROM friend_requests
   WHERE sender_id = p_receiver_id AND receiver_id = p_sender_id AND status = 'pending' LIMIT 1;

  IF v_reverse_id IS NOT NULL THEN
    CALL sp_respond_friend_request(p_sender_id, v_reverse_id, 'accept');
    SELECT v_reverse_id AS request_id, 'accepted' AS status;
  ELSE
    INSERT INTO friend_requests (sender_id, receiver_id, status) VALUES (p_sender_id, p_receiver_id, 'pending')
    ON DUPLICATE KEY UPDATE status = 'pending', created_at = NOW(), responded_at = NULL;
    SELECT id AS request_id, 'pending' AS status FROM friend_requests
     WHERE sender_id = p_sender_id AND receiver_id = p_receiver_id;
  END IF;
END$$

CREATE PROCEDURE sp_cancel_friend_request(IN p_sender_id BIGINT UNSIGNED, IN p_request_id BIGINT UNSIGNED)
BEGIN
  UPDATE friend_requests SET status = 'cancelled', responded_at = NOW()
   WHERE id = p_request_id AND sender_id = p_sender_id AND status = 'pending';
  SELECT ROW_COUNT() AS affected;
END$$

CREATE PROCEDURE sp_unfriend(IN p_user_id BIGINT UNSIGNED, IN p_friend_id BIGINT UNSIGNED)
BEGIN
  DELETE FROM friendships
   WHERE user_low_id = LEAST(p_user_id, p_friend_id) AND user_high_id = GREATEST(p_user_id, p_friend_id);
  DELETE FROM follows
   WHERE (follower_id = p_user_id AND following_id = p_friend_id)
      OR (follower_id = p_friend_id AND following_id = p_user_id);
  SELECT ROW_COUNT() AS affected;
END$$

CREATE PROCEDURE sp_get_pending_requests(IN p_user_id BIGINT UNSIGNED, IN p_direction VARCHAR(10))
COMMENT 'p_direction: received | sent'
BEGIN
  SELECT fr.id AS request_id, fr.created_at,
         u.id AS user_id, u.username, u.full_name, u.avatar_url,
         (SELECT COUNT(*) FROM v_user_friends a JOIN v_user_friends b ON a.friend_id = b.friend_id
           WHERE a.user_id = p_user_id AND b.user_id = u.id) AS mutual_friends
    FROM friend_requests fr
    JOIN users u ON u.id = IF(p_direction = 'sent', fr.receiver_id, fr.sender_id)
   WHERE fr.status = 'pending'
     AND u.status = 'active'
     AND ((p_direction = 'sent' AND fr.sender_id = p_user_id)
       OR (p_direction <> 'sent' AND fr.receiver_id = p_user_id))
   ORDER BY fr.created_at DESC;
END$$

-- ---------------------------------------------------------------------
-- 12.5 Tin nhắn
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_get_or_create_direct_conversation(IN p_user_id BIGINT UNSIGNED, IN p_other_id BIGINT UNSIGNED)
BEGIN
  DECLARE v_conv_id BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_setting VARCHAR(10);
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_conv_id = NULL;

  IF p_user_id = p_other_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Không thể nhắn tin cho chính mình';
  END IF;
  IF fn_is_blocked(p_user_id, p_other_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Không thể nhắn tin cho người dùng này';
  END IF;

  SELECT id INTO v_conv_id FROM conversations
   WHERE user_low_id = LEAST(p_user_id, p_other_id) AND user_high_id = GREATEST(p_user_id, p_other_id);

  IF v_conv_id IS NULL THEN
    SELECT who_can_message INTO v_setting FROM user_privacy_settings WHERE user_id = p_other_id;
    IF v_setting = 'nobody' OR (v_setting = 'friends' AND NOT fn_are_friends(p_user_id, p_other_id)) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Người dùng này không nhận tin nhắn từ bạn';
    END IF;
    INSERT INTO conversations (conversation_type, user_low_id, user_high_id)
    VALUES ('direct', p_user_id, p_other_id)
    ON DUPLICATE KEY UPDATE id = LAST_INSERT_ID(id);
    SET v_conv_id = LAST_INSERT_ID();
    INSERT IGNORE INTO conversation_participants (conversation_id, user_id)
    VALUES (v_conv_id, p_user_id), (v_conv_id, p_other_id);
  END IF;
  SELECT v_conv_id AS conversation_id;
END$$

CREATE PROCEDURE sp_get_conversations(IN p_user_id BIGINT UNSIGNED, IN p_limit INT)
BEGIN
  DECLARE v_limit INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 20), 1), 100);
  SELECT c.id AS conversation_id, c.last_message_at,
         o.id AS other_user_id, o.username, o.full_name, o.avatar_url,
         IF(s.show_online_status, o.last_active_at, NULL) AS other_last_active_at,
         cp.unread_count, cp.is_marked_unread, cp.is_muted,
         IF(m.id > IFNULL(cp.cleared_before_message_id, 0), m.id, NULL) AS last_message_id,
         IF(m.id > IFNULL(cp.cleared_before_message_id, 0),
            IF(m.deleted_at IS NOT NULL, 'Tin nhắn đã bị thu hồi',
               IF(m.message_type = 'image', '[Hình ảnh]', LEFT(m.content, 100))), NULL) AS last_message_preview,
         m.sender_id AS last_message_sender_id
    FROM conversation_participants cp
    JOIN conversations c ON c.id = cp.conversation_id
    JOIN users o ON o.id = IF(c.user_low_id = p_user_id, c.user_high_id, c.user_low_id)
    JOIN user_privacy_settings s ON s.user_id = o.id
    LEFT JOIN messages m ON m.id = c.last_message_id
   WHERE cp.user_id = p_user_id AND cp.hidden_at IS NULL
   ORDER BY c.last_message_at IS NULL, c.last_message_at DESC
   LIMIT v_limit;
END$$

CREATE PROCEDURE sp_get_messages(
  IN p_user_id BIGINT UNSIGNED, IN p_conversation_id BIGINT UNSIGNED, IN p_before_id BIGINT UNSIGNED, IN p_limit INT)
BEGIN
  DECLARE v_limit INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 30), 1), 100);
  DECLARE v_cleared BIGINT UNSIGNED DEFAULT 0;
  DECLARE v_member TINYINT DEFAULT 0;

  SELECT 1, IFNULL(cleared_before_message_id, 0) INTO v_member, v_cleared
    FROM conversation_participants WHERE conversation_id = p_conversation_id AND user_id = p_user_id;
  IF v_member = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bạn không thuộc cuộc trò chuyện này';
  END IF;

  SELECT msg.id, msg.sender_id, msg.message_type,
         IF(msg.deleted_at IS NULL, msg.content, NULL) AS content,
         msg.deleted_at IS NOT NULL AS is_recalled,
         msg.created_at, msg.edited_at, msg.client_message_id,
         IF(msg.deleted_at IS NULL,
            (SELECT JSON_ARRAYAGG(JSON_OBJECT('id', mf.id, 'url', mf.url, 'width', mf.width, 'height', mf.height))
               FROM message_attachments ma JOIN media_files mf ON mf.id = ma.media_id
              WHERE ma.message_id = msg.id), NULL) AS attachments,
         -- Đã xem: người kia đã đọc tới tin này chưa
         EXISTS (SELECT 1 FROM conversation_participants o
                  WHERE o.conversation_id = msg.conversation_id AND o.user_id <> msg.sender_id
                    AND o.last_read_message_id >= msg.id) AS is_seen
    FROM messages msg
   WHERE msg.conversation_id = p_conversation_id
     AND msg.id > v_cleared
     AND (p_before_id IS NULL OR msg.id < p_before_id)
   ORDER BY msg.id DESC
   LIMIT v_limit;
END$$

CREATE PROCEDURE sp_mark_conversation_read(IN p_user_id BIGINT UNSIGNED, IN p_conversation_id BIGINT UNSIGNED)
BEGIN
  UPDATE conversation_participants cp
    JOIN conversations c ON c.id = cp.conversation_id
     SET cp.unread_count = 0, cp.is_marked_unread = 0,
         cp.last_read_message_id = c.last_message_id, cp.last_read_at = NOW()
   WHERE cp.conversation_id = p_conversation_id AND cp.user_id = p_user_id;
END$$

CREATE PROCEDURE sp_mark_conversation_unread(IN p_user_id BIGINT UNSIGNED, IN p_conversation_id BIGINT UNSIGNED)
BEGIN
  UPDATE conversation_participants SET is_marked_unread = 1
   WHERE conversation_id = p_conversation_id AND user_id = p_user_id;
END$$

-- ---------------------------------------------------------------------
-- 12.6 Thông báo
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_create_notification(
  IN p_recipient_id BIGINT UNSIGNED, IN p_actor_id BIGINT UNSIGNED, IN p_type VARCHAR(30),
  IN p_post_id BIGINT UNSIGNED, IN p_comment_id BIGINT UNSIGNED,
  IN p_friend_request_id BIGINT UNSIGNED, IN p_conversation_id BIGINT UNSIGNED, IN p_content VARCHAR(500))
BEGIN
  -- Không tự thông báo cho mình và không thông báo giữa 2 người đã chặn nhau
  IF p_recipient_id <> IFNULL(p_actor_id, 0) AND NOT fn_is_blocked(p_recipient_id, p_actor_id) THEN
    INSERT INTO notifications (recipient_id, actor_id, type, post_id, comment_id, friend_request_id, conversation_id, content)
    VALUES (p_recipient_id, p_actor_id, p_type, p_post_id, p_comment_id, p_friend_request_id, p_conversation_id, p_content);
    SELECT LAST_INSERT_ID() AS notification_id;
  ELSE
    SELECT NULL AS notification_id;
  END IF;
END$$

CREATE PROCEDURE sp_get_notifications(IN p_user_id BIGINT UNSIGNED, IN p_cursor_id BIGINT UNSIGNED, IN p_limit INT)
BEGIN
  DECLARE v_limit INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 20), 1), 50);
  SELECT n.id, n.type, n.is_read, n.created_at, n.content,
         n.post_id, n.comment_id, n.friend_request_id, n.conversation_id,
         a.id AS actor_id, a.username AS actor_username, a.full_name AS actor_name, a.avatar_url AS actor_avatar,
         LEFT(p.content, 100) AS post_preview
    FROM notifications n
    LEFT JOIN users a ON a.id = n.actor_id
    LEFT JOIN posts p ON p.id = n.post_id
   WHERE n.recipient_id = p_user_id
     AND (p_cursor_id IS NULL OR n.id < p_cursor_id)
   ORDER BY n.id DESC
   LIMIT v_limit;
  SELECT COUNT(*) AS unread_total FROM notifications WHERE recipient_id = p_user_id AND is_read = 0;
END$$

CREATE PROCEDURE sp_mark_notification_read(IN p_user_id BIGINT UNSIGNED, IN p_notification_id BIGINT UNSIGNED)
BEGIN
  UPDATE notifications SET is_read = 1, read_at = NOW()
   WHERE id = p_notification_id AND recipient_id = p_user_id AND is_read = 0;
END$$

CREATE PROCEDURE sp_mark_all_notifications_read(IN p_user_id BIGINT UNSIGNED)
BEGIN
  UPDATE notifications SET is_read = 1, read_at = NOW() WHERE recipient_id = p_user_id AND is_read = 0;
  SELECT ROW_COUNT() AS affected;
END$$

-- ---------------------------------------------------------------------
-- 12.7 Tìm kiếm
-- ---------------------------------------------------------------------
-- Lưu ý: ứng dụng nên escape ký tự % và _ trong p_keyword trước khi truyền vào.
CREATE PROCEDURE sp_search_users(IN p_viewer_id BIGINT UNSIGNED, IN p_keyword VARCHAR(100), IN p_limit INT)
BEGIN
  DECLARE v_limit INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 20), 1), 50);
  SELECT u.id, u.username, u.full_name, u.avatar_url, u.follower_count,
         fn_are_friends(p_viewer_id, u.id) AS is_friend,
         (SELECT COUNT(*) FROM v_user_friends a JOIN v_user_friends b ON a.friend_id = b.friend_id
           WHERE a.user_id = p_viewer_id AND b.user_id = u.id) AS mutual_friends
    FROM users u
   WHERE u.status = 'active'
     AND (MATCH(u.full_name, u.username) AGAINST (p_keyword IN NATURAL LANGUAGE MODE)
          OR u.full_name LIKE CONCAT('%', p_keyword, '%')
          OR u.username  LIKE CONCAT(p_keyword, '%'))
     AND NOT fn_is_blocked(p_viewer_id, u.id)
   ORDER BY (u.username = p_keyword) DESC, fn_are_friends(p_viewer_id, u.id) DESC,
            MATCH(u.full_name, u.username) AGAINST (p_keyword IN NATURAL LANGUAGE MODE) DESC,
            u.follower_count DESC
   LIMIT v_limit;
END$$

CREATE PROCEDURE sp_search_posts(IN p_viewer_id BIGINT UNSIGNED, IN p_keyword VARCHAR(255), IN p_limit INT)
BEGIN
  DECLARE v_limit INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 20), 1), 50);
  SELECT v.*, MATCH(p.content) AGAINST (p_keyword IN NATURAL LANGUAGE MODE) AS relevance
    FROM posts p
    JOIN v_post_details v ON v.id = p.id
   WHERE p.status = 'active'
     AND MATCH(p.content) AGAINST (p_keyword IN NATURAL LANGUAGE MODE)
     AND fn_can_view_post(p_viewer_id, p.id)
   ORDER BY relevance DESC, p.reaction_count + p.comment_count DESC, p.id DESC
   LIMIT v_limit;
END$$

CREATE PROCEDURE sp_search_hashtags(IN p_prefix VARCHAR(100), IN p_limit INT)
BEGIN
  DECLARE v_limit INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 10), 1), 50);
  SELECT id, tag, post_count, last_used_at FROM hashtags
   WHERE tag LIKE CONCAT(LOWER(TRIM(LEADING '#' FROM p_prefix)), '%')
   ORDER BY post_count DESC
   LIMIT v_limit;
END$$

CREATE PROCEDURE sp_get_posts_by_hashtag(
  IN p_viewer_id BIGINT UNSIGNED, IN p_tag VARCHAR(100), IN p_cursor_id BIGINT UNSIGNED, IN p_limit INT)
BEGIN
  DECLARE v_limit INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 20), 1), 50);
  SELECT v.*
    FROM hashtags h
    JOIN post_hashtags ph ON ph.hashtag_id = h.id
    JOIN v_post_details v ON v.id = ph.post_id
   WHERE h.tag = LOWER(TRIM(LEADING '#' FROM p_tag))
     AND v.status = 'active'
     AND (p_cursor_id IS NULL OR v.id < p_cursor_id)
     AND fn_can_view_post(p_viewer_id, v.id)
   ORDER BY v.id DESC
   LIMIT v_limit;
END$$

-- Bài đăng phổ biến: điểm tương tác giảm dần theo thời gian
CREATE PROCEDURE sp_get_popular_posts(IN p_viewer_id BIGINT UNSIGNED, IN p_days INT, IN p_limit INT)
BEGIN
  DECLARE v_limit INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 20), 1), 50);
  SELECT v.*,
         (v.reaction_count + 2 * v.comment_count + 3 * v.share_count)
           / POW(TIMESTAMPDIFF(HOUR, v.created_at, NOW()) + 2, 1.5) AS hot_score
    FROM v_post_details v
   WHERE v.status = 'active' AND v.visibility = 'public' AND v.author_status = 'active'
     AND v.created_at >= NOW() - INTERVAL IFNULL(p_days, 7) DAY
     AND NOT fn_is_blocked(p_viewer_id, v.user_id)
   ORDER BY hot_score DESC
   LIMIT v_limit;
END$$

CREATE PROCEDURE sp_get_trending_hashtags(IN p_days INT, IN p_limit INT)
BEGIN
  DECLARE v_limit INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 10), 1), 50);
  SELECT h.id, h.tag, COUNT(*) AS recent_posts
    FROM post_hashtags ph
    JOIN posts p ON p.id = ph.post_id AND p.status = 'active' AND p.visibility = 'public'
    JOIN hashtags h ON h.id = ph.hashtag_id
   WHERE p.created_at >= NOW() - INTERVAL IFNULL(p_days, 7) DAY
   GROUP BY h.id, h.tag
   ORDER BY recent_posts DESC
   LIMIT v_limit;
END$$

-- ---------------------------------------------------------------------
-- 12.8 Quản trị (Admin)
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_admin_set_user_lock(
  IN p_admin_id BIGINT UNSIGNED, IN p_user_id BIGINT UNSIGNED, IN p_lock TINYINT,
  IN p_reason VARCHAR(500), IN p_until DATETIME, IN p_report_id BIGINT UNSIGNED)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  IF NOT fn_is_admin(p_admin_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bạn không có quyền quản trị';
  END IF;
  IF EXISTS (SELECT 1 FROM users WHERE id = p_user_id AND role = 'admin') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Không thể khóa tài khoản quản trị viên';
  END IF;

  START TRANSACTION;
    IF p_lock THEN
      UPDATE users SET status = 'locked', locked_reason = p_reason, locked_until = p_until WHERE id = p_user_id;
      UPDATE user_sessions SET revoked_at = NOW() WHERE user_id = p_user_id AND revoked_at IS NULL;
    ELSE
      UPDATE users SET status = 'active', locked_reason = NULL, locked_until = NULL
       WHERE id = p_user_id AND status = 'locked';
    END IF;
    INSERT INTO moderation_logs (admin_id, report_id, action, target_type, target_id, reason, metadata)
    VALUES (p_admin_id, p_report_id, IF(p_lock, 'lock_user', 'unlock_user'), 'user', p_user_id, p_reason,
            JSON_OBJECT('locked_until', p_until));
    IF p_report_id IS NOT NULL THEN
      UPDATE reports SET status = 'resolved', handled_by = p_admin_id, handled_at = NOW(), resolution_note = p_reason
       WHERE id = p_report_id;
    END IF;
  COMMIT;
END$$

-- p_target_type: post | comment ; p_action: hide | unhide | delete | restore
CREATE PROCEDURE sp_admin_moderate_content(
  IN p_admin_id BIGINT UNSIGNED, IN p_target_type VARCHAR(10), IN p_target_id BIGINT UNSIGNED,
  IN p_action VARCHAR(10), IN p_reason VARCHAR(1000), IN p_report_id BIGINT UNSIGNED)
BEGIN
  DECLARE v_new_status VARCHAR(10);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  IF NOT fn_is_admin(p_admin_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bạn không có quyền quản trị';
  END IF;
  SET v_new_status = CASE p_action WHEN 'hide' THEN 'hidden' WHEN 'delete' THEN 'deleted'
                                   WHEN 'unhide' THEN 'active' WHEN 'restore' THEN 'active' END;
  IF v_new_status IS NULL OR p_target_type NOT IN ('post','comment') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tham số xử lý không hợp lệ';
  END IF;

  START TRANSACTION;
    IF p_target_type = 'post' THEN
      UPDATE posts SET status = v_new_status,
                       hidden_reason = IF(v_new_status = 'active', NULL, p_reason),
                       hidden_by = IF(v_new_status = 'active', NULL, p_admin_id),
                       deleted_at = IF(v_new_status = 'active', NULL, deleted_at)
       WHERE id = p_target_id;
      IF v_new_status <> 'active' THEN
        UPDATE reports SET status = 'resolved', handled_by = p_admin_id, handled_at = NOW(),
                           resolution_note = IFNULL(resolution_note, p_reason)
         WHERE post_id = p_target_id AND target_type = 'post' AND status IN ('pending','reviewing');
      END IF;
    ELSE
      UPDATE comments SET status = v_new_status,
                          deleted_at = IF(v_new_status = 'active', NULL, deleted_at)
       WHERE id = p_target_id;
      IF v_new_status <> 'active' THEN
        UPDATE reports SET status = 'resolved', handled_by = p_admin_id, handled_at = NOW(),
                           resolution_note = IFNULL(resolution_note, p_reason)
         WHERE comment_id = p_target_id AND target_type = 'comment' AND status IN ('pending','reviewing');
      END IF;
    END IF;

    INSERT INTO moderation_logs (admin_id, report_id, action, target_type, target_id, reason)
    VALUES (p_admin_id, p_report_id, CONCAT(p_action, '_', p_target_type), p_target_type, p_target_id, p_reason);
  COMMIT;
END$$

CREATE PROCEDURE sp_admin_reject_report(IN p_admin_id BIGINT UNSIGNED, IN p_report_id BIGINT UNSIGNED, IN p_note VARCHAR(1000))
BEGIN
  IF NOT fn_is_admin(p_admin_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bạn không có quyền quản trị';
  END IF;
  UPDATE reports SET status = 'rejected', handled_by = p_admin_id, handled_at = NOW(), resolution_note = p_note
   WHERE id = p_report_id AND status IN ('pending','reviewing');
  INSERT INTO moderation_logs (admin_id, report_id, action, target_type, target_id, reason)
  VALUES (p_admin_id, p_report_id, 'reject_report', 'report', p_report_id, p_note);
END$$

CREATE PROCEDURE sp_admin_list_users(
  IN p_keyword VARCHAR(100), IN p_status VARCHAR(20), IN p_offset INT, IN p_limit INT)
BEGIN
  DECLARE v_limit INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 20), 1), 100);
  DECLARE v_offset INT DEFAULT GREATEST(IFNULL(p_offset, 0), 0);
  SELECT u.id, u.username, u.email, u.full_name, u.role, u.status, u.locked_reason, u.locked_until,
         u.email_verified_at, u.last_login_at, u.post_count, u.friend_count, u.created_at,
         (SELECT COUNT(*) FROM reports r WHERE r.reported_user_id = u.id) AS times_reported
    FROM users u
   WHERE (p_status IS NULL OR u.status = p_status)
     AND (p_keyword IS NULL OR u.username LIKE CONCAT('%', p_keyword, '%')
          OR u.email LIKE CONCAT('%', p_keyword, '%') OR u.full_name LIKE CONCAT('%', p_keyword, '%'))
   ORDER BY u.id DESC
   LIMIT v_offset, v_limit;
END$$

CREATE PROCEDURE sp_admin_moderation_history(IN p_target_type VARCHAR(10), IN p_target_id BIGINT UNSIGNED, IN p_limit INT)
BEGIN
  DECLARE v_limit INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 50), 1), 200);
  SELECT ml.id, ml.action, ml.target_type, ml.target_id, ml.reason, ml.metadata, ml.created_at,
         ml.report_id, a.username AS admin_username
    FROM moderation_logs ml JOIN users a ON a.id = ml.admin_id
   WHERE (p_target_type IS NULL OR ml.target_type = p_target_type)
     AND (p_target_id IS NULL OR ml.target_id = p_target_id)
   ORDER BY ml.id DESC
   LIMIT v_limit;
END$$

DELIMITER ;

-- =====================================================================
-- 13. SỰ KIỆN DỌN DẸP ĐỊNH KỲ (cần bật: SET GLOBAL event_scheduler = ON;)
-- =====================================================================
DELIMITER $$
CREATE EVENT IF NOT EXISTS ev_daily_cleanup
ON SCHEDULE EVERY 1 DAY STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 3 HOUR)
DO
BEGIN
  DELETE FROM email_verification_tokens WHERE expires_at < NOW() - INTERVAL 7 DAY;
  DELETE FROM password_reset_tokens     WHERE expires_at < NOW() - INTERVAL 7 DAY;
  DELETE FROM user_sessions   WHERE expires_at < NOW() OR revoked_at < NOW() - INTERVAL 30 DAY;
  DELETE FROM login_attempts  WHERE created_at < NOW() - INTERVAL 90 DAY;
  DELETE FROM api_rate_limits WHERE window_start < NOW() - INTERVAL 1 DAY;
  DELETE FROM search_history  WHERE created_at < NOW() - INTERVAL 180 DAY;
  -- Tự mở khóa các tài khoản bị khóa có thời hạn đã hết hạn
  UPDATE users SET status = 'active', locked_reason = NULL, locked_until = NULL
   WHERE status = 'locked' AND locked_until IS NOT NULL AND locked_until < NOW();
END$$
DELIMITER ;

-- =====================================================================
-- 14. DỮ LIỆU KHỞI TẠO
-- =====================================================================
-- Tài khoản admin mặc định. THAY password_hash bằng hash bcrypt thật do ứng dụng sinh ra, ví dụ (Node.js):
--   const hash = await bcrypt.hash('MatKhauManh@123', 12);
--   UPDATE users SET password_hash = '<hash>' WHERE username = 'admin';
INSERT INTO users (username, email, password_hash, full_name, role, status, email_verified_at)
VALUES ('admin', 'admin@example.com', '$2b$12$REPLACE_WITH_REAL_BCRYPT_HASH_GENERATED_BY_APP_______',
        'Quản trị viên', 'admin', 'active', NOW());

-- =====================================================================
-- GỢI Ý CẤU HÌNH my.cnf CHO TÌM KIẾM TIẾNG VIỆT
--   [mysqld]
--   innodb_ft_min_token_size = 2     # mặc định 3 => các âm tiết như "an", "hà" sẽ bị bỏ qua
--   event_scheduler = ON
-- Sau khi đổi cần tạo lại FULLTEXT index (OPTIMIZE TABLE users, posts;)
-- =====================================================================