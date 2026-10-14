import mysql from 'mysql2/promise';
import 'dotenv/config';

export const pool = mysql.createPool({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    port: Number(process.env.DB_PORT) || 3306,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
});

pool.getConnection()
    .then((connection) => {
        console.log("Kết nối cơ sở dữ liệu thành công!");
        connection.release();
    })
    .catch((err) => {
        console.error("Lỗi kết nối cơ sở dữ liệu:", err);
    });

export default pool;