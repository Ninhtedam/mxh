import UserModel from "../models/user.model"
import { Request, Response } from "express";
import bcrypt from "bcryptjs";
import { signToken } from "../utils/jwt";
import crypto from 'crypto';

class DangkyController {
    async createUser (req: Request, res: Response){
        const {email, username, sex, birthday, phone, address, password} = req.body;

        if (!email || !password){
            return res.status(400).json({ message: "Vui lòng nhập đủ email và password" });
        }
        if (! / ^ \S+ @ \S+ \. \S+ $ /.test(email)){
            return res.status(400).json({ message: "Email không hợp lệ" });
        }
        if (password.length < 6) {
            return res.status(400).json({ message: "Mật khẩu phải từ 6 ký tự" });
        }

        if (await UserModel.findByEmail(email)) {
            return res.status(409).json({ message: "Email đã được sử dụng" });
        }

        let mnd;
        do{
            mnd = crypto.randomBytes(5).toString('hex').toUpperCase();
        }while(await UserModel.findMnd(mnd))

        const passwordHash = await bcrypt.hash(password, 10);
        const userId = await UserModel.createUser(email, username, mnd, sex, birthday, phone,address, passwordHash);

        const token = signToken({ userId});
        res.status(201).json({
            message: "Đăng ký thành công",
            token,
            user: {id:userId,email},
        });
    }
}
export default new DangkyController();