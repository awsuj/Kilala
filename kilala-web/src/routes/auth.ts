import { Router, Request, Response } from 'express';
import { config } from '../config';
import { login } from '../lib/api';

const router = Router();

// GET /login — show the sign-in page. If already signed in, go to the dashboard.
router.get('/login', (req: Request, res: Response) => {
  if (res.locals.currentUser?.role === config.allowedRole) {
    return res.redirect('/dashboard');
  }
  res.render('login', { error: null, email: '' });
});

// POST /login — authenticate against the backend and set the auth cookie.
router.post('/login', async (req: Request, res: Response) => {
  const email = String(req.body.email || '').trim();
  const password = String(req.body.password || '');

  const rerender = (error: string, status = 400) =>
    res.status(status).render('login', { error, email });

  if (!email || !password) {
    return rerender('Please enter your email and password.');
  }

  const result = await login(email, password);

  if (!result.ok) {
    return rerender(result.error, result.status === 503 ? 503 : 401);
  }

  // The LGU portal is administrators only — cardholders/businesses are rejected
  // even though their credentials are valid against the backend.
  if (result.user.role !== config.allowedRole) {
    return rerender('This portal is for LGU administrators only.', 403);
  }

  res.cookie(config.authCookie, result.token, {
    httpOnly: true,
    sameSite: 'lax',
    secure: config.isProd,
    maxAge: 24 * 60 * 60 * 1000, // 24h, matches the backend token lifetime
  });

  res.redirect('/dashboard');
});

// POST /logout — clear the cookie and return to the login page.
router.post('/logout', (req: Request, res: Response) => {
  res.clearCookie(config.authCookie);
  res.redirect('/login');
});

export default router;
