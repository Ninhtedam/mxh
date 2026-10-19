import { useNavigate } from "react-router-dom";
import Logo from "../components/Logo";

export default function Home() {
  const navigate = useNavigate();

  function logout() {
    localStorage.removeItem("token");
    navigate("/dangnhap", { replace: true });
  }

  return (
    <>
      <header className="topbar">
        <Logo size={32} />
        <button className="btn btn--outline" onClick={logout}>
          Đăng xuất
        </button>
      </header>
      <div className="page">Trang chủ</div>
    </>
  );
}
