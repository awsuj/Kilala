import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';

const router = Router();

// Root → send people to the right place.
router.get('/', (req: Request, res: Response) => {
  res.redirect(res.locals.currentUser ? '/dashboard' : '/login');
});

// GET /dashboard — placeholder for the next milestone (feat/web-lgu/dashboard).
// For now it just confirms a successful, role-gated login so the flow is
// verifiable end-to-end.
router.get('/dashboard', requireAuth, (req: Request, res: Response) => {
  res.render('dashboard-placeholder', { user: res.locals.currentUser });
});

export default router;
