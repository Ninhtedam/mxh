import pool from "../config/db";
import { RowDataPacket, ResultSetHeader} from "mysql2/promise";


class UserModel {
    //đăng ký
    async findByEmail(email: string){
        const [rows] = await pool.query<RowDataPacket[]>(
            "SELECT id FROM users WHERE email = ?", [email]
        );
        return rows.length > 0 ? rows[0] : null;
    }

    async findMnd (mnd: string){
        const [rows] = await pool.query<RowDataPacket[]>(
            "SELECT id FROM users WHERE mnd = ?", [mnd]
        );
        return rows.length > 0 ? rows[0] : null;
    }

    async createUser (email: string, username: string, mnd:string, sex: string, birthday: Date, phone: number, address: string, passwordHash:string){
        const [result] = await pool.query<ResultSetHeader>(
            "INSERT INTO users (email, username, mnd, sex, birthday, phone,address, password_hash) VALUES (?,?,?,?,?,?,?,?)", [email, username,mnd, sex, birthday, phone, address, passwordHash]
        )
        return result.insertId;
    }

}
export default new UserModel();