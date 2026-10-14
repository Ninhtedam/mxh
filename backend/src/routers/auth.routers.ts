import { Router } from "express";
import bcrypt from "bcryptjs";
import { signToken } from "../utils/jwt";

const router = Router();
const users: { id: number; email: string; password: string }[] = [];

router.post("/register", async (req, res) => {
  const { email, password } = req.body;
  if (users.find((u) => u.email === email)) {
    res.status(400).json({ message: "Email đã tồn tại" });
    return;
  }
  const user = { id: users.length + 1, email, password: await bcrypt.hash(password, 10) };
  users.push(user);
  res.status(201).json({ token: signToken({ userId: user.id }) });
});

router.post("/login", async (req, res) => {
  const { email, password } = req.body;
  const user = users.find((u) => u.email === email);
  if (!user || !(await bcrypt.compare(password, user.password))) {
    res.status(401).json({ message: "Sai email hoặc mật khẩu" });
    return;
  }
  res.json({ token: signToken({ userId: user.id }) });
});

export default router;