import dotenv from 'dotenv';

dotenv.config();

export const config = {
  port: Number(process.env.PORT) || 3000,
  apiBaseUrl: process.env.API_BASE_URL || 'http://localhost:5000',
  authCookie: process.env.AUTH_COOKIE || 'kilala_token',
  // The LGU portal is for government administrators only.
  allowedRole: 'LGU_ADMIN',
  isProd: process.env.NODE_ENV === 'production',
};
