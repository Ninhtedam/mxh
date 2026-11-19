import EmailService from "../service/auth.service"
import { Request, Response } from "express";

const normalizeEmail = (email: unknown) => String(email ?? "").trim().toLowerCase();
const normalizePassword = (password: unknown) => String(password ?? "").trim();
const handleError = (res: Response, err: any) => {
    if (err?.status)
        return res.status(err.status).json({ message: err.message });
    if (err?.code === "ER_DUP_ENTRY")
        return res.status(409).json({ message: "Email đã được đăng ký" });
    console.error(err);
    return res.status(500).json({ message: "Lỗi máy chủ" });
};


class AuthController {
    
    async btnOtp(req: Request, res: Response) {
        try {
            await EmailService.btnOtp(normalizeEmail(req.body.email));
            res.json({ message: "Mã OTP đã được gửi tới email của bạn" });
        } catch (err) { handleError(res, err); }
    }

    async takeEmailToken(req: Request, res: Response) {
        try {
            const { token } = await EmailService.takeEmailToken(normalizeEmail(req.body.email), String(req.body.otp ?? ""));
            res.json({ message: "Xác thực email thành công", registerToken: token });
        } catch (err) { handleError(res, err); }
    }

    async createUser(req: Request, res: Response) {
        try {
            const { registerToken, password,...data } = req.body;
            const pw = normalizePassword(password);
            const result = await EmailService.createUser(registerToken,pw,data);
            res.status(201).json({ message: "Đăng ký thành công", ...result });
        } catch (err) { handleError(res, err); }
    }

    async forgotPassword(req: Request, res: Response){
        try {
            await EmailService.forgotPassword(normalizeEmail(req.body.email));
            res.json({ message: "Mã OTP đã được gửi tới email của bạn" });
        } catch (err) { handleError(res, err); }
    }

    async resetPassword(req: Request, res: Response){
        try {
            await EmailService.resetPassword(String(req.body.resetToken ?? ""), normalizePassword(req.body.password));
            res.json({ message: "Đổi mật khẩu thành công" });
        } catch (err) { handleError(res, err); }
    }

    async login(req: Request, res: Response){
        try {
            const result = await EmailService.login(normalizeEmail(req.body.email),normalizePassword(req.body.password));
            res.json({ message: "Đăng nhập thành công", ...result  });
        } catch (err) { handleError(res, err); }
    }
}
export default new AuthController();