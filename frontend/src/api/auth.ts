import axios from "axios";
import api from "./axios";

// Đường dẫn API xác thực – sửa ở đây nếu backend đặt tên khác
export const AUTH_ENDPOINTS = {
  login: "/auth/dangnhap",
  sendOtp: "/auth/gui-otp",
  verifyOtp: "/auth/xac-thuc-otp",
  register: "/auth/dangky",
};

export type AuthUser = { id: number; email: string; username?: string; user_code?: string };
export type AuthResponse = { message: string; token: string; user: AuthUser };

export type RegisterPayload = {
  email: string;
  password: string;
  username?: string;
  sex?: "Nam" | "Nữ";
  birthday?: string;
  phone?: string;
  address?: string;
};

export const authApi = {
  login: (email: string, password: string) =>
    api.post<AuthResponse>(AUTH_ENDPOINTS.login, { email, password }).then((r) => r.data),
  sendOtp: (email: string) =>
    api.post<{ message: string }>(AUTH_ENDPOINTS.sendOtp, { email }).then((r) => r.data),
  verifyOtp: (email: string, otp: string) =>
    api.post<{ message: string }>(AUTH_ENDPOINTS.verifyOtp, { email, otp }).then((r) => r.data),
  register: (payload: RegisterPayload) =>
    api.post<AuthResponse>(AUTH_ENDPOINTS.register, payload).then((r) => r.data),
};

export function getErrorMessage(err: unknown, fallback = "Có lỗi xảy ra, vui lòng thử lại") {
  if (axios.isAxiosError(err)) {
    if (!err.response) return "Không kết nối được máy chủ";
    return (err.response.data as { message?: string })?.message ?? fallback;
  }
  return fallback;
}

export const EMAIL_REGEX = /^\S+@\S+\.\S+$/;

// Lưu email đã xác thực OTP để dùng ở bước 2
export const VERIFIED_EMAIL_KEY = "register_email";
