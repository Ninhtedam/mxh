import { Router } from "express";
import DangkyController from "../controllers/auth.controller";

const router = Router();
router.post("/dangky",DangkyController.createUser);

export default router;