import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import ProtectedRoute from "./router/ProtectedRoute";
import Login from "./pages/Login";
import Register from "./pages/Register";
import RegisterInfo from "./pages/RegisterInfo";
import ForgotPassword from "./pages/ForgotPassword";
import Home from "./pages/Home";

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/register" element={<Register />} />
        <Route path="/register/info" element={<RegisterInfo />} />
        <Route path="/forgot-password" element={<ForgotPassword />} />
        {/* Đường dẫn cũ (tiếng Việt) -> đường dẫn mới */}
        <Route path="/dangnhap" element={<Navigate to="/login" replace />} />
        <Route path="/dangky" element={<Navigate to="/register" replace />} />
        <Route path="/dangky/thong-tin" element={<Navigate to="/register/info" replace />} />
        <Route path="/quen-mat-khau" element={<Navigate to="/forgot-password" replace />} />
        <Route element={<ProtectedRoute />}>
          <Route path="/" element={<Home />} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
