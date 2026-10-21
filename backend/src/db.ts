import { Pool } from 'pg';
import dotenv from 'dotenv';

dotenv.config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  // Required for connecting to Supabase/cloud databases securely:
  ssl: {
    rejectUnauthorized: false
  }
});

export default pool;
