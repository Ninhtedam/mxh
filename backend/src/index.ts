import "dotenv/config";
import express from "express";
import { pool } from "./config/db";
import cors from "cors";
import authRoutes from "./routers/auth.routers";
import userRoutes from "./routers/user.routers";

const app = express();
app.use(cors({ origin: "http://localhost:5173" }));
app.use(express.json());

app.use("/api/auth", authRoutes);
app.use("/api/users", userRoutes);

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`Server chạy tại http://localhost:${port}`));