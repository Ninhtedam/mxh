import pool from "../config/db";
import { RowDataPacket, ResultSetHeader} from "mysql2/promise";


class UserModel {
    async findByEmail(email: string){
        const [rows] = await pool.query<RowDataPacket[]>(
            "SELECT id FROM users WHERE email = ?", [email]
        );
        return rows.length > 0 ? rows[0] : null;
    }

    async findUser_code (user_code: string){
        const [rows] = await pool.query<RowDataPacket[]>(
            "SELECT id FROM users WHERE user_code = ?", [user_code]
        );
        return rows.length > 0 ? rows[0] : null;
    }

    async createUser (email: string, username: string, user_code:string, sex: string, birthday: string, phone: string, address: string, passwordHash:string){
        const [result] = await pool.query<ResultSetHeader>(
            "INSERT INTO users (email, username, user_code, sex, birthday, phone,address, password_hash) VALUES (?,?,?,?,?,?,?,?)", [email, username,user_code, sex, birthday, phone, address, passwordHash]
        )
        return result.insertId;
    }

    async loginInformation (email:string){
        const [rows] = await pool.query<RowDataPacket[]>(
            `SELECT id, password_hash ,
            failed_login_count, locked_until,  TIMESTAMPDIFF(Minute, locked_until, now()) as lu ,
            TIMESTAMPDIFF(Minute, last_failed_login_at, now()) as lfla, last_login_at FROM users WHERE email = ?`, [email]
        );
        return rows.length > 0 ? rows[0] : null;
    }

    async loginFailed(email:string){
        const [result] = await pool.query<ResultSetHeader>(
            "UPDATE users SET failed_login_count = failed_login_count + 1, last_failed_login_at = now() WHERE email = ?", [email]
        );
        return result.affectedRows > 0;
    }

    async loginFailed5(email:string){
        const [result] = await pool.query<ResultSetHeader>(
            "UPDATE users SET locked_until = now() + interval 30 minute, failed_login_count = 0 WHERE email = ?", [email]
        );
        return result.affectedRows > 0;
    }

    async loginLater (email:string){
        const [result] = await pool.query<ResultSetHeader>(
            "UPDATE users SET failed_login_count = 0 WHERE email = ?", [email]
        );
        return result.affectedRows > 0;
    }

    async loginTrue (email:string){
        const [result] = await pool.query<ResultSetHeader>(
            "UPDATE users SET last_login_at = now(), failed_login_count = 0 WHERE email = ?", [email]
        );
        return result.affectedRows > 0;
    }

    async updatePassword (email: string, passwordHash: string){
        const [result] = await pool.query<ResultSetHeader>(
            "UPDATE users SET password_hash = ? WHERE email = ?", [passwordHash, email]
        );
        return result.affectedRows > 0;
    }
}
export default new UserModel();