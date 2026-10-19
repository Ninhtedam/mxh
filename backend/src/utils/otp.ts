import crypto from 'crypto';

export const generateOtp = () =>
    crypto.randomInt(0, 1_000_000).toString().padStart(6,'0');

export const hashOtp = (otp:string) =>
    crypto.createHash('sha256').update(otp).digest('hex');
//sử dụng thuật toán sh256, đổi tượng băm là otp, kết quả băm là chuỗi hex
