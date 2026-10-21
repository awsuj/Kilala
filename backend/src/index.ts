import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import pool from './db';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 5000;
const JWT_SECRET = process.env.JWT_SECRET;

app.use(cors());
app.use(express.json());

// Test route to query users from Supabase
app.get('/api/users', async (req: Request, res: Response) => {
  try {
    const result = await pool.query('SELECT id, email, role FROM users');
    res.status(200).json(result.rows);
  } catch (error) {
    console.error('Database query failed:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

app.listen(PORT, async () => {
  console.log(`[server]: Kilala backend running on port ${PORT}`);
  
  // Verify database connection on startup
  try {
    const client = await pool.connect();
    console.log('[server]: Connected to Supabase PostgreSQL successfully!');
    client.release();
  } catch (err) {
    console.error('[server]: Failed to connect to the database', err);
  }
});

app.post('/api/auth/login', async (req: Request, res: Response) => {
  const { email, password } = req.body;

  try {
    // 1. Find the user in Supabase
    const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const user = result.rows[0];

    // 2. Verify the password
    // Note: Since our seed.sql uses a dummy hash, this is how you'd check it. 

    /* ORIGINAL BLOCK
    const isValidPassword = await bcrypt.compare(password, user.password_hash);
    if (!isValidPassword) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }
      */

    /* TEMPORARY BLOCK TO MAKE WAY FOR DUMMY SEEDING */

    // Note: Since our seed.sql uses a dummy hash, this is how you'd check it. 
    let isValidPassword = false;
    
    // Temporary bypass for the mock seed data
    if (user.password_hash === '$2b$10$MockHashForTestingOnly123456789012') {
      isValidPassword = (password === 'MockHashForTestingOnly123456789012');
    } else {
      // The real check for actual users created in the app
      isValidPassword = await bcrypt.compare(password, user.password_hash);
    }

    // 3. Generate a JWT Token
    const JWT_SECRET = process.env.JWT_SECRET!;
    const token = jwt.sign({ id: user.id, role: user.role }, JWT_SECRET, { expiresIn: '24h' });

    // 4. Send the token and user data back to iOS/Web
    res.status(200).json({
      message: 'Login successful',
      token,
      user: { id: user.id, email: user.email, role: user.role }
    });

  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Middleware to protect routes
const authenticateToken = (req: Request, res: Response, next: NextFunction) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  
  if (!token) return res.sendStatus(401);
  
  const JWT_SECRET = process.env.JWT_SECRET!;
  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) return res.sendStatus(403);
    (req as any).user = user;
    next();
  });
};

// Fetch Cardholder Profile
app.get('/api/cardholder/me', authenticateToken, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user.id;
    const result = await pool.query(
      'SELECT * FROM cardholder_profiles WHERE user_id = $1',
      [userId]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Profile not found' });
    }
    
    res.status(200).json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: 'Server error' });
  }
});
