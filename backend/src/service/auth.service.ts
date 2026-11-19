import EmailModel from "../models/email.model";
import UserModel from "../models/user.model";
import { sendOtpMail } from "../utils/mailer";
import {generateOtp, hashOtp} from '../utils/otp'
import { signEmailToken,verifyEmailToken, signLoginToken} from "../utils/jwt";
import bcrypt from "bcryptjs";
import crypto from 'crypto';

class EmailService {

    async checkEmail(email:string) {
        return await UserModel.findByEmail(email);
    }

    async sendOTP(email:string){
        const otp = generateOtp();
        const otpHash = hashOtp(otp);
        
        const findByEmailPr = await EmailModel.findByEmail(email);
        if (!findByEmailPr){
            const createOtp = await EmailModel.createOtp(email, otpHash);
            if (!createOtp)
                throw {status: 500, message: "Lỗi máy chủ"};
        }
        else{
            const lsa = findByEmailPr.lsa;
            if (lsa>=0 && lsa<10){
                throw {status: 429, message: `Vui lòng đợi ${10 - lsa}s để gửi lại OTP`};
            }
            else if (lsa<0){
                throw {status: 429, message: `Nhập sai quá nhiều. Vui lòng chờ ${Math.abs(lsa)} phút`};
            }
            else{
                const laa = findByEmailPr.laa;
                if (laa>=20){
                    const updateOtpLater = await EmailModel.updateOtpLater(email,otpHash);
                    if (!updateOtpLater)
                        throw {status: 500, message: "Lỗi máy chủ"};
                }
                else{
                    const updateOtp = await EmailModel.updateOtp(email,otpHash);
                    if (!updateOtp)
                        throw {status: 500, message: "Lỗi máy chủ"};
                }
            }
        }
        try {
            await sendOtpMail(email, otp);
        } catch (err) {
            console.error("Gửi mail thất bại:", err);
            throw {status: 502, message: "Không gửi được email, vui lòng thử lại"};
        }
    }

    async btnOtp(email: string){
        const checkEmail = await this.checkEmail(email);
        if (checkEmail)
            throw {status: 400, message: "Email đã được đăng ký"};
        await this.sendOTP(email);
    }

    // Kiểm tra OTP, dùng chung cho đăng ký và quên mật khẩu. Sai thì throw, đúng thì xóa OTP.
    async checkOtp (email:string, otp:string){
        const findByEmailPr = await EmailModel.findByEmail(email)
        if (!findByEmailPr){
            throw {status: 404, message: "Không có dữ liệu. Vui lòng nhấn gửi OTP"}
        }
        else {
            const attempt_count = findByEmailPr.attempt_count;
            if (attempt_count >= 5)
                throw {status: 429, message: `Nhập sai quá nhiều. Vui lòng chờ ${Math.abs(findByEmailPr.lsa)} phút`}
            else{
                const oea = findByEmailPr.oea;
                if (oea>0)
                    throw {status: 410, message: "OTP quá hạn, vui lòng nhấn gửi OTP để nhận mã mới"}
                else{

                    if (hashOtp(otp)===findByEmailPr.otp_hash){
                        const prDrop = await EmailModel.prDrop(email);
                        if (!prDrop){
                            throw {status: 500, message: "Lỗi máy chủ"};
                        }
                        return;
                    }
                    else {
                        const prFailed = await EmailModel.prFailed(email);
                        if (!prFailed){
                            throw {status: 500, message: "Lỗi máy chủ"};
                        }
                        const numbeOfTime = attempt_count + 1;
                        if (numbeOfTime >=5){
                            const prFailed5 = await EmailModel.prFailed5(email);
                            if (!prFailed5)
                                throw {status: 500, message: "Lỗi máy chủ"};
                            else
                                throw {status: 429, message: "Nhập sai quá nhiều. Vui lòng chờ 30 phút"};
                        }
                        else
                            throw {status: 400, message: `Mã OTP không đúng, còn ${5 - numbeOfTime} lần`};
                    }
                }
            }
        }
    }

    
    // Đăng ký: OTP đúng -> trả giấy xác nhận email để sang bước nhập thông tin
    async takeEmailToken (email:string, otp:string){
        await this.checkOtp(email, otp);
        return { token: signEmailToken(email) };
    }
    
    async createUser(registerToken: string, password:string, data: {username?: string; sex?: string; birthday?: string; phone?: string; address?: string }) {
        if (!data.username)
            data.username = "Người dùng"
        let email: string;
        try {
            email = verifyEmailToken(registerToken);
        } catch {
            throw { status: 401, message: "Phiên xác thực email đã hết hạn, vui lòng xác thực lại" };
        }
        if (!password || password.length < 6)
            throw { status: 400, message: "Mật khẩu phải từ 6 ký tự" };
        if (await UserModel.findByEmail(email))
            throw { status: 409, message: "Email đã được đăng ký" };

        let user_code;
        do {
            user_code = crypto.randomBytes(5).toString('hex').toUpperCase();
        } while (await UserModel.findUser_code(user_code));

        const passwordHash = await bcrypt.hash(password, 10);
        const userId = await UserModel.createUser(email, data.username!, user_code, data.sex!, data.birthday!, data.phone!, data.address!, passwordHash);
        return { token: signLoginToken({ userId }), user: { id: userId, email } };
    }

    async forgotPassword (email:string){
        const checkEmail = await this.checkEmail(email);
        if (!checkEmail)
            throw {status: 400, message: "Email chưa được đăng ký"};
        await this.sendOTP(email);
    }

    async resetPassword (resetToken:string, password:string){
        let email: string;
        try {
            email = verifyEmailToken(resetToken);
        } catch {
            throw {status: 401, message: "Phiên đặt lại mật khẩu đã hết hạn, vui lòng xác thực lại"};
        }
        if (!password || password.length < 6)
            throw {status: 400, message: "Mật khẩu phải từ 6 ký tự"};

        const passwordHash = await bcrypt.hash(password, 10);
        const updated = await UserModel.updatePassword(email, passwordHash);
        if (!updated)
            throw {status: 404, message: "Email chưa được đăng ký"};
    }

    async checkLogin (email:string, password:string) {
        const loginInformation = await UserModel.loginInformation(email);
        if (!loginInformation)
            throw {status: 401, message: "Email hoặc mật khẩu không đúng"};
        else {
            let failed_login_count = loginInformation.failed_login_count;
            if (loginInformation.lu < 0){
                throw {status: 429, message: `Nhập quá nhiều! Tài khoản bị khóa trong ${Math.abs(loginInformation.lu)} phút`};
            }
            if (loginInformation.lfla >= 20){
                const loginLater = await UserModel.loginLater(email);
                if (!loginLater)
                    throw {status: 500, message: "Lỗi máy chủ"};
                failed_login_count = 0;
            }

            const isMatch = await bcrypt.compare(password, loginInformation.password_hash);
            if (isMatch){
                return loginInformation
            }
            else{
                const loginFailed = await UserModel.loginFailed(email);
                if (!loginFailed){
                    throw {status: 500, message: "Lỗi máy chủ"};
                }
                failed_login_count = failed_login_count + 1;
                if (failed_login_count >=5){
                    const loginFailed5 = await UserModel.loginFailed5(email);
                    if (!loginFailed5){
                        throw {status: 500, message: "Lỗi máy chủ"};
                    }
                    // Báo khóa ngay ở lần sai thứ 5, không đợi tới lần thử sau
                    throw {status: 429, message: "Nhập sai quá nhiều. Tài khoản bị khóa trong 30 phút"};
                }
                throw {status: 401, message: "Email hoặc mật khẩu không đúng"};
            }
        }
    }

    async login (email:string, password:string){
        const loginInformation = await this.checkLogin(email, password);
        const loginTrue = await UserModel.loginTrue(email);
        if (!loginTrue)
            throw {status: 500, message: "Lỗi máy chủ"};
        return { token: signLoginToken({ userId: loginInformation.id }), user: { id: loginInformation.id, email } };
    }
}

export default new EmailService();