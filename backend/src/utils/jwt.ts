import jwt from "jsonwebtoken";

export interface JwtPayload {
  userId: number;
}

export const signToken = (payload: JwtPayload) =>
  jwt.sign(payload, process.env.JWT_SECRET as string, { expiresIn: "7d" });

export const verifyToken = (token: string) =>
  jwt.verify(token, process.env.JWT_SECRET as string) as JwtPayload