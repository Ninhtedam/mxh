import jwt from "jsonwebtoken";

const SECRET = process.env.JWT_SECRET as string;

export interface JwtPayload {
  userId: number;
}

//token đăng nhập
export const signToken = (payload: JwtPayload) =>
  jwt.sign(payload, SECRET, { expiresIn: "7d" });

export const verifyToken = (token: string) => {
  const payload = jwt.verify(token, SECRET) as JwtPayload & { purpose?: string };
  // Chặn việc lấy "giấy xác nhận email" đem đi đăng nhập
  if (payload.purpose) throw new Error("Sai loại token");
  return payload as JwtPayload;
};

//token đăng ký
export const signRegisterToken = (email: string) =>
  jwt.sign({ email, purpose: "register" }, SECRET, { expiresIn: "15m" });

export const verifyRegisterToken = (token: string) => {
  const payload = jwt.verify(token, SECRET) as { email: string; purpose?: string };
  if (payload.purpose !== "register") throw new Error("Sai loại token");
  return payload.email;
};