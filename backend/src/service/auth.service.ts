import EmailModel from "../models/email.model";
import UserModel from "../models/user.model";
import crypto from 'crypto';
import { signRegisterToken } from "../utils/jwt";

async function otp (email:string){
    
}

class EmailService {
    async btnOtp(email: string, otpHash: string){
        const findByEmailUsers = await UserModel.findByEmail(email);
        if (findByEmailUsers)
            throw {status: 400, message: "Email đã được đăng ký"};

        const findByEmailPr = await EmailModel.findByEmail(email);
        if (!findByEmailPr){
            const createOtp = await EmailModel.createOtp(email, otpHash);
            if (!createOtp)
                throw {status: 500, message: "Lỗi máy chủ"};
        }
        else{
            const lsa = findByEmailPr.lsa;
            if (lsa>=0 && lsa<10){
                throw {status: 429, message: "Vui lòng đợi ${10 - lsa}s để gửi lại OTP"};
            }
            else if (lsa<0){
                throw {status: 429, message: "Nhập sai quá nhiều. Vui lòng chờ 30 phút"};
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
    }

    async btnPr (email:string, otp:string){
        const findByEmailPr = await EmailModel.findByEmail(email)
        if (!findByEmailPr){
            throw {status: 404, message: "Không có dữ liệu. Vui lòng nhấn gửi OTP"}
        }
        else {
            const attempt_count = findByEmailPr.attempt_count;
            if (attempt_count >= 5)
                throw {status: 429, message: "Nhập sai quá nhiều. Vui lòng chờ 30 phút"}
            else{
                const oea = findByEmailPr.oea;
                if (oea>0)
                    throw {status: 410, message: "OTP quá hạn, vui lòng nhấn gửi OTP để nhận mã mới"}
                else{
                    const otpHash = crypto.createHash('sha256').update(otp).digest('hex');

                    if (otpHash===findByEmailPr.otp_hash){
                        const prDrop = await EmailModel.prDrop(email);
                        if (!prDrop){
                            throw {status: 500, message: "Lỗi máy chủ"};
                        }
                        const token = signRegisterToken(email);
                        return { success: true, token: token };
                    }
                    else {
                        const prFailed = await EmailModel.prFailed(email);
                        if (!prFailed){
                            throw {status: 500, message: "Lỗi máy chủ"};
                        }
                        const numbeOfTime = findByEmailPr.attempt_count + 1;
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
}

export default new EmailService();