// ===== Trang chủ (bảng tin) =====
// Người dùng thật lấy từ GET /api/users/me. Token hết hạn -> apiGet nhận 401 -> common.js tự đăng xuất.
// Backend chưa có API bài viết / bạn bè nên 3 hàm dưới trả danh sách rỗng -> trang hiện trạng thái trống.
// Khi có API chỉ cần sửa 3 hàm này, phần hiển thị đã sẵn sàng.

// Một trang bài viết: { posts: [...], hasMore: boolean }
// Mỗi bài: { id, author, code, minutesAgo, privacy, likes, comments, liked, text }
// Khi có API: return apiGet(`/posts?page=${page}&tab=${tab}`)
const loadPostsPage = (page, tab) => Promise.resolve({ posts: [], hasMore: false });
// Mỗi người: { name, code, mutual }. Khi có API: apiGet("/friends/requests"), apiGet("/friends/suggestions")
const loadRequests = () => Promise.resolve([]);
const loadSuggestions = () => Promise.resolve([]);

// ---------- Tiện ích ----------
function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
}

const icon = (name) => `<svg class="icon" aria-hidden="true"><use href="#i-${name}" /></svg>`;

// Màu nền ảnh đại diện cố định theo tên
const AVATAR_COLORS = ["#1d4ed8", "#0f766e", "#7c3aed", "#be185d", "#b45309", "#15803d", "#0369a1", "#9333ea"];
function avatarColor(seed) {
  let h = 0;
  for (const ch of seed) h = (h * 31 + ch.codePointAt(0)) >>> 0;
  return AVATAR_COLORS[h % AVATAR_COLORS.length];
}
function initials(name) {
  const words = name.trim().split(/\s+/).filter(Boolean);
  if (!words.length) return "?";
  const last = words[words.length - 1][0];
  return (words.length > 1 ? words[0][0] + last : last).toUpperCase();
}
function avatarHtml(name, size = "", url = "") {
  const inner = url ? `<img src="${escapeHtml(url)}" alt="" loading="lazy" />` : escapeHtml(initials(name));
  return `<span class="avatar ${size}" style="--av:${avatarColor(name)}" aria-hidden="true">${inner}</span>`;
}

function timeAgo(minutes) {
  if (minutes < 1) return "Vừa xong";
  if (minutes < 60) return `${minutes} phút`;
  if (minutes < 60 * 24) return `${Math.floor(minutes / 60)} giờ`;
  if (minutes < 60 * 24 * 7) return `${Math.floor(minutes / 1440)} ngày`;
  return `${Math.floor(minutes / 10080)} tuần`;
}

const formatCount = (n) => (n >= 1000 ? `${(n / 1000).toFixed(1).replace(".0", "")}K` : String(n));

// Thông báo nhỏ ở cuối màn hình
let toastTimer;
function toast(msg) {
  const el = $("toast");
  el.textContent = msg;
  el.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => (el.hidden = true), 2600);
}

// ---------- Người dùng hiện tại ----------
let me = { username: "Người dùng", user_code: "" };

function renderMe() {
  const color = avatarColor(me.username);
  document.querySelectorAll("[data-me-avatar]").forEach((el) => {
    el.style.setProperty("--av", color);
    if (me.avatar_url) el.innerHTML = `<img src="${escapeHtml(me.avatar_url)}" alt="" />`;
    else el.textContent = initials(me.username);
  });
  document.querySelectorAll("[data-me-name]").forEach((el) => (el.textContent = me.username));
  document.querySelectorAll("[data-me-code]").forEach((el) => (el.textContent = me.user_code ? `@${me.user_code}` : ""));
  // Gọi theo tên (từ cuối); tên mặc định "Người dùng" thì không gọi tên
  const named = me.username && me.username !== "Người dùng";
  $("composer-text").placeholder = named ? `${me.username.split(" ").pop()} ơi, bạn đang nghĩ gì?` : "Bạn đang nghĩ gì?";
}

async function loadMe() {
  renderMe();
  try {
    me = { ...me, ...(await apiGet("/users/me")) };
    renderMe();
  } catch {
    // Lỗi mạng / máy chủ: giữ tên mặc định, không đăng xuất
  }
}

// ---------- Bài viết ----------
const PRIVACY = {
  public: { icon: "globe", label: "Công khai" },
  friends: { icon: "users", label: "Bạn bè" },
  private: { icon: "lock", label: "Chỉ mình tôi" },
};

function postHtml(p) {
  const privacy = PRIVACY[p.privacy] || PRIVACY.public;
  const text = escapeHtml(p.text).replace(/#[\p{L}\d_]+/gu, (tag) => `<span class="tag">${tag}</span>`);
  const media = p.media
    ? `<div class="post__media" style="--media:${p.media.bg}" role="img" aria-label="${escapeHtml(p.media.label)}">${escapeHtml(p.media.label)}</div>`
    : "";
  return `
    <article class="card post" data-id="${p.id}" aria-label="Bài viết của ${escapeHtml(p.author)}">
      <header class="post__head">
        ${avatarHtml(p.author)}
        <div class="post__meta">
          <a href="#" class="post__author" data-soon>${escapeHtml(p.author)}</a>
          <span class="post__sub">
            <span>@${escapeHtml(p.code)}</span><span aria-hidden="true">·</span>
            <time>${timeAgo(p.minutesAgo)}</time><span aria-hidden="true">·</span>
            <span title="${privacy.label}">${icon(privacy.icon)}<span class="sr-only">${privacy.label}</span></span>
          </span>
        </div>
        <button class="icon-btn post__more" aria-label="Tuỳ chọn bài viết" data-soon>${icon("more")}</button>
      </header>
      <p class="post__body">${text}</p>
      ${media}
      <div class="post__stats">
        <span class="post__stats-likes"><span class="like-dot" aria-hidden="true">${icon("heart")}</span><span data-likes>${formatCount(p.likes)}</span></span>
        <span>${p.comments} bình luận</span>
      </div>
      <div class="post__actions">
        <button class="action-btn${p.liked ? " is-liked" : ""}" data-action="like" aria-pressed="${p.liked}">${icon("heart")}Thích</button>
        <button class="action-btn" data-soon>${icon("comment")}Bình luận</button>
        <button class="action-btn" data-action="share">${icon("share")}Chia sẻ</button>
      </div>
    </article>`;
}

const postsEl = $("posts");
const posts = new Map(); // id -> dữ liệu bài, để cập nhật lượt thích

function appendPosts(list, { prepend = false } = {}) {
  list.forEach((p) => posts.set(p.id, p));
  postsEl.insertAdjacentHTML(prepend ? "afterbegin" : "beforeend", list.map(postHtml).join(""));
}

// Thích / bỏ thích (giao diện cập nhật ngay; khi có API thì gọi apiPost rồi hoàn tác nếu lỗi)
postsEl.addEventListener("click", (e) => {
  const btn = e.target.closest("[data-action]");
  if (!btn) return;
  const article = btn.closest(".post");
  const post = posts.get(article.dataset.id);
  if (btn.dataset.action === "like") {
    post.liked = !post.liked;
    post.likes += post.liked ? 1 : -1;
    btn.classList.toggle("is-liked", post.liked);
    btn.setAttribute("aria-pressed", post.liked);
    article.querySelector("[data-likes]").textContent = formatCount(post.likes);
  } else if (btn.dataset.action === "share") {
    navigator.clipboard?.writeText(`${location.origin}/post/${post.id}`).catch(() => {});
    toast("Đã sao chép liên kết bài viết");
  }
});

// ---------- Cuộn vô hạn ----------
const sentinel = $("feed-sentinel");
const feedEnd = $("feed-end");
let feed = { tab: "all", page: 0, loading: false, hasMore: true, version: 0 };

async function loadMore() {
  if (feed.loading || !feed.hasMore) return;
  feed.loading = true;
  const version = feed.version;
  try {
    const { posts: list, hasMore } = await loadPostsPage(feed.page, feed.tab);
    if (version !== feed.version) return; // đã đổi tab trong lúc tải
    appendPosts(list);
    feed.page++;
    feed.hasMore = hasMore;
    if (!hasMore) {
      sentinel.hidden = true;
      // Có bài thì báo "đã xem hết"; chưa có bài nào thì hiện thẻ trạng thái trống
      feedEnd.hidden = !posts.size;
      if (!posts.size) {
        postsEl.innerHTML =
          feed.tab === "friends"
            ? `<div class="card empty"><strong>Bạn bè chưa đăng gì</strong>Bài viết của bạn bè sẽ hiện ở đây.</div>`
            : `<div class="card empty"><strong>Chưa có bài viết nào</strong>Kết bạn bằng mã người dùng để xem bài viết của mọi người.</div>`;
      }
    }
  } catch {
    toast("Không tải được bài viết, thử lại sau");
  } finally {
    if (version === feed.version) feed.loading = false;
  }
  // Observer chỉ báo khi trạng thái thay đổi: nếu sentinel vẫn trong vùng tải (màn hình cao, cuộn nhanh)
  // thì sẽ không có sự kiện mới -> theo dõi lại để observer kiểm tra lại ngay.
  if (feed.hasMore) {
    feedObserver.unobserve(sentinel);
    feedObserver.observe(sentinel);
  }
}

const feedObserver = new IntersectionObserver((entries) => entries[0].isIntersecting && loadMore(), {
  rootMargin: "400px 0px",
});
feedObserver.observe(sentinel);

function switchTab(tab) {
  if (tab === feed.tab) return;
  document.querySelectorAll(".tabs__item").forEach((b) => {
    const active = b.dataset.tab === tab;
    b.classList.toggle("is-active", active);
    b.setAttribute("aria-selected", active);
  });
  feed = { tab, page: 0, loading: false, hasMore: true, version: feed.version + 1 };
  posts.clear();
  postsEl.innerHTML = "";
  sentinel.hidden = false;
  feedEnd.hidden = true;
  loadMore();
}
document.querySelectorAll(".tabs__item").forEach((b) => b.addEventListener("click", () => switchTab(b.dataset.tab)));

// ---------- Ô đăng bài ----------
const composer = $("composer");
const composerText = $("composer-text");
const composerBtn = $("composer-submit");

function autoGrow() {
  composerText.style.height = "auto";
  composerText.style.height = composerText.scrollHeight + 2 + "px";
}
composerText.addEventListener("input", () => {
  autoGrow();
  composerBtn.disabled = !composerText.value.trim();
});
// Ctrl/Cmd + Enter để đăng
composerText.addEventListener("keydown", (e) => {
  if (e.key === "Enter" && (e.ctrlKey || e.metaKey)) composer.requestSubmit();
});

composer.addEventListener("submit", (e) => {
  e.preventDefault();
  if (!composerText.value.trim()) return;
  // Chưa có API đăng bài: giữ nguyên nội dung, không tạo bài giả.
  // Khi có API: const post = await apiPost("/posts", { content, privacy }); appendPosts([post], { prepend: true });
  //             rồi xoá ô nhập (composerText.value = ""; autoGrow(); composerBtn.disabled = true;)
  toast("Chức năng đăng bài đang được phát triển");
});

$("mobile-create").addEventListener("click", () => {
  composer.scrollIntoView({ behavior: "smooth", block: "center" });
  composerText.focus({ preventScroll: true });
});

// ---------- Lời mời & gợi ý kết bạn ----------
function personHtml(p, actions) {
  return `
    <li class="person" data-code="${escapeHtml(p.code)}">
      ${avatarHtml(p.name)}
      <div class="person__info">
        <span class="person__name">${escapeHtml(p.name)}</span>
        <span class="person__sub">${p.mutual} bạn chung</span>
      </div>
      <div class="person__actions">${actions}</div>
    </li>`;
}

async function renderPeople() {
  const requests = await loadRequests();
  $("request-count").textContent = requests.length || "";
  $("requests").innerHTML = requests.length
    ? requests
        .map((p) =>
          personHtml(p, `
            <button class="mini-btn mini-btn--primary" data-act="accept" aria-label="Chấp nhận ${escapeHtml(p.name)}">${icon("check")}</button>
            <button class="mini-btn" data-act="decline" aria-label="Từ chối ${escapeHtml(p.name)}">${icon("x")}</button>`)
        )
        .join("")
    : `<li class="person__sub">Chưa có lời mời kết bạn.</li>`;

  const suggestions = await loadSuggestions();
  $("suggestions").innerHTML = suggestions.length
    ? suggestions
        .map((p) => personHtml(p, `<button class="mini-btn" data-act="add" aria-label="Kết bạn với ${escapeHtml(p.name)}">${icon("user-plus")}</button>`))
        .join("")
    : `<li class="person__sub">Chưa có gợi ý. Tìm bạn bằng mã người dùng ở ô tìm kiếm phía trên.</li>`;
}

// Khi có API: gọi apiPost tương ứng trước khi đổi giao diện
document.querySelector(".sidebar--right").addEventListener("click", (e) => {
  const btn = e.target.closest("[data-act]");
  if (!btn) return;
  const text = { accept: "Đã là bạn bè", decline: "Đã từ chối", add: "Đã gửi lời mời" }[btn.dataset.act];
  btn.parentElement.outerHTML = `<span class="person__done">${text}</span>`;
  if (btn.dataset.act !== "add") {
    const left = document.querySelectorAll("#requests [data-act]").length / 2;
    $("request-count").textContent = left || "";
  }
});

// ---------- Menu tài khoản ----------
const menuBtn = $("menu-btn");
const menuPanel = $("user-menu");

function setMenu(open) {
  menuPanel.hidden = !open;
  menuBtn.setAttribute("aria-expanded", open);
  if (open) menuPanel.querySelector(".menu__item").focus();
}
menuBtn.addEventListener("click", () => setMenu(menuPanel.hidden));
document.addEventListener("click", (e) => {
  if (!menuPanel.hidden && !e.target.closest(".menu")) setMenu(false);
});
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape" && !menuPanel.hidden) {
    setMenu(false);
    menuBtn.focus();
  }
});
$("logout-btn").addEventListener("click", logout);

// ---------- Tính năng chưa làm / tìm kiếm ----------
document.addEventListener("click", (e) => {
  const soon = e.target.closest("[data-soon]");
  if (!soon) return;
  e.preventDefault();
  toast("Tính năng này đang được phát triển");
});

$("search-form").addEventListener("submit", (e) => {
  e.preventDefault();
  const q = $("search-input").value.trim();
  if (q) toast(`Tìm "${q}": chức năng tìm kiếm đang được phát triển`);
});

// ---------- Khởi động ----------
document.querySelector("[data-logo]").innerHTML = logoSvg(30);
$("year").textContent = new Date().getFullYear();
loadMe();
renderPeople();
loadMore();
