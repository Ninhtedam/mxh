import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import ProtectedRoute from "./router/ProtectedRoute";
import Login from "./pages/Login";
import Register from "./pages/Register";
import RegisterInfo from "./pages/RegisterInfo";
import Home from "./pages/Home";

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/dangnhap" element={<Login />} />
        <Route path="/dangky" element={<Register />} />
        <Route path="/dangky/thong-tin" element={<RegisterInfo />} />
        <Route element={<ProtectedRoute />}>
          <Route path="/" element={<Home />} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
