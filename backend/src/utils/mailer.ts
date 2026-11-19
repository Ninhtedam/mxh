import nodemailer from "nodemailer";
import 'dotenv/config';

const transporter = nodemailer.createTransport({
    service: `gmail`,
    auth: {
        user: process.env.MAIL_USER,
        pass: process.env.MAIL_PASS
    }
});

transporter.verify()
.then(()=>console.log("Kết nối mail server thành công"))
.catch((err)=>console.error("Lỗi kết nối mail server: ",err));

export const sendOtpMail = async (to: string, otp: string) => {
    await transporter.sendMail({
        from: `"MXH" <${process.env.MAIL_USER}>`,
        to,
        subject: `Mã xác thực của bạn: ${otp}`,
        text: `Mã OTP của bạn là ${otp}. Mã có hiệu lực trong 10 phút. Không chia sẻ mã này cho bất kỳ ai.`,
        html: `
            <div style="font-family:Arial,sans-serif;max-width:420px">
                <p>Mã xác thực đăng ký tài khoản của bạn là:</p>
                <p style="font-size:28px;font-weight:bold;letter-spacing:6px">${otp}</p>
                <p>Mã có hiệu lực trong <b>10 phút</b>. Không chia sẻ mã này cho bất kỳ ai.</p>
                <p style="color:#888;font-size:12px">Nếu bạn không yêu cầu mã này, hãy bỏ qua email.</p>
            </div>`,
    });
};