import "dotenv/config";
import express from "express";
import path from "path";
import { pool } from "./config/db";
import authRoutes from "./routers/auth.routers";
import userRoutes from "./routers/user.routers";

const app = express();
app.use(express.json());

app.use("/api/auth", authRoutes);
app.use("/api/users", userRoutes);

// Giao diện HTML/CSS/JS thuần (thư mục frontend): /login -> login.html, ...
const webDir = path.join(__dirname, "../../frontend");
app.get("/register/info", (_req, res) => res.sendFile(path.join(webDir, "register-info.html")));
app.use(express.static(webDir, { extensions: ["html"] }));
// Đường dẫn không tồn tại (ngoài /api) -> về trang chủ
app.use((req, res, next) => {
  if (req.method === "GET" && !req.path.startsWith("/api")) return res.redirect("/");
  next();
});

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`Server chạy tại http://localhost:${port}`));