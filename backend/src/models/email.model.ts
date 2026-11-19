import pool from '../config/db';
import {RowDataPacket, ResultSetHeader} from 'mysql2/promise'

class EmailModel{
    async findByEmail(email: string){
        const [rows] = await pool.execute<RowDataPacket[]>(
            `select otp_hash, otp_expires_at, last_sent_at, attempt_count, last_attempt_at,
                TIMESTAMPDIFF(SECOND, otp_expires_at, now()) as oea,
                TIMESTAMPDIFF(SECOND, last_sent_at, now()) as lsa,
                TIMESTAMPDIFF(Minute, last_attempt_at, now()) as laa
            from pending_registrations
            Where email = ?`,[email]
        );
        return rows.length > 0 ? rows[0] : null;
    }

    async createOtp (email: string, otpHash: string){
        const [result] = await pool.execute<ResultSetHeader>(
            `insert into pending_registrations (email, otp_hash, otp_expires_at, last_sent_at, attempt_count)
            values (?, ?, now() + interval 10 minute, now(), 0)`,
            [email, otpHash]
        );
        return result.affectedRows
    }

    async updateOtpLater (email: string, otpHash: string){
        const [result] = await pool.execute<ResultSetHeader>(
            `update pending_registrations
            set otp_hash = ?, otp_expires_at = now() + interval 10 minute, last_sent_at = now(), attempt_count = 0
            where email = ?`, [otpHash, email]
        );
        return result.affectedRows
    }

    async updateOtp (email: string, otpHash: string){
        const [result] = await pool.execute<ResultSetHeader>(
            `update pending_registrations
            set otp_hash = ?, otp_expires_at = now() + interval 10 minute, last_sent_at = now()
            where email = ?`, [otpHash, email]
        );
        return result.affectedRows
    }

    async prFailed (email:string){
        const [result] = await pool.execute<ResultSetHeader>(
            `update pending_registrations
            set attempt_count = attempt_count + 1, last_attempt_at = now()
            where email = ?`, [email]
        );
        return result.affectedRows
    }

    async prFailed5 (email:string){
        const [result] = await pool.execute<ResultSetHeader>(
            `update pending_registrations
            set last_sent_at = now() + interval 30 minute
            where email = ?`, [email]
        );
        return result.affectedRows
    }

    async prDrop (email:string){
        const [result] = await pool.execute<ResultSetHeader>(
            `delete from pending_registrations
            where email = ?`, [email]
        );
        return result.affectedRows
    }
}
export default new EmailModel();