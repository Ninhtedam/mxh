import type { ReactNode } from "react";
import Logo from "./Logo";

export default function AuthLayout({ children }: { children: ReactNode }) {
  return (
    <div className="auth">
      <aside className="auth__brand">
        <Logo inverse size={60} />
        <div>
          <h1>Kết bạn, theo dõi và chia sẻ khoảnh khắc mỗi ngày.</h1>
          <p>Tìm bạn bè bằng mã người dùng, cập nhật bài viết và trò chuyện với những người bạn quan tâm.</p>
        </div>
        <span className="auth__brand-foot">© {new Date().getFullYear()} mxh</span>
      </aside>

      <main className="auth__main">
        <div className="auth__card">
          <div className="auth__mobile-logo">
            <Logo size={48} />
          </div>
          {children}
        </div>
      </main>
    </div>
  );
}
