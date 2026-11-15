import axios from "axios";
import api from "./axios";

// Đường dẫn API xác thực – sửa ở đây nếu backend đặt tên khác
export const AUTH_ENDPOINTS = {
  login: "/auth/login",
  sendOtp: "/auth/send-otp",
  verifyOtp: "/auth/verify-otp",
  register: "/auth/register",
  // Quên mật khẩu: gửi OTP -> xác thực OTP (nhận resetToken) -> đặt mật khẩu mới
  forgotSendOtp: "/auth/forgot-password/send-otp",
  forgotVerifyOtp: "/auth/forgot-password/verify-otp",
  resetPassword: "/auth/forgot-password/reset",
};

export type AuthUser = { id: number; email: string; username?: string; user_code?: string };
export type AuthResponse = { message: string; token: string; user: AuthUser };
export type VerifyOtpResponse = { message: string; registerToken: string };
export type ForgotVerifyResponse = { message: string; resetToken: string };

export type RegisterPayload = {
  // Giấy xác nhận email nhận được sau bước OTP – backend lấy email từ đây
  registerToken: string;
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
    api.post<VerifyOtpResponse>(AUTH_ENDPOINTS.verifyOtp, { email, otp }).then((r) => r.data),
  register: (payload: RegisterPayload) =>
    api.post<AuthResponse>(AUTH_ENDPOINTS.register, payload).then((r) => r.data),
  forgotSendOtp: (email: string) =>
    api.post<{ message: string }>(AUTH_ENDPOINTS.forgotSendOtp, { email }).then((r) => r.data),
  forgotVerifyOtp: (email: string, otp: string) =>
    api.post<ForgotVerifyResponse>(AUTH_ENDPOINTS.forgotVerifyOtp, { email, otp }).then((r) => r.data),
  resetPassword: (resetToken: string, password: string) =>
    api.post<{ message: string }>(AUTH_ENDPOINTS.resetPassword, { resetToken, password }).then((r) => r.data),
};

export function getErrorMessage(err: unknown, fallback = "Có lỗi xảy ra, vui lòng thử lại") {
  if (axios.isAxiosError(err)) {
    if (!err.response) return "Không kết nối được máy chủ";
    return (err.response.data as { message?: string })?.message ?? fallback;
  }
  return fallback;
}

export const EMAIL_REGEX = /^\S+@\S+\.\S+$/;

// Lưu email đã xác thực OTP để hiển thị ở bước 2
export const VERIFIED_EMAIL_KEY = "register_email";
// Lưu giấy xác nhận email (JWT 15 phút) để gửi kèm khi đăng ký
export const REGISTER_TOKEN_KEY = "register_token";
