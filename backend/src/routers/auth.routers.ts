import { Router } from "express";
import AuthController from "../controllers/auth.controller";

const router = Router();

router.post("/send-otp", AuthController.btnOtp);
router.post("/verify-otp", AuthController.takeEmailToken);
router.post("/register", AuthController.createUser);

router.post("/login", AuthController.login);

router.post("/forgot-password/send-otp", AuthController.forgotPassword);
router.post("/forgot-password/reset", AuthController.resetPassword);

export default router;
