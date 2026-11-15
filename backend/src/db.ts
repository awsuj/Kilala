import { Pool } from 'pg';
import dotenv from 'dotenv';

dotenv.config();

const isLocalDatabase =
  !process.env.DATABASE_URL ||
  process.env.DATABASE_URL.includes('localhost') ||
  process.env.DATABASE_URL.includes('127.0.0.1');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  // Use SSL for cloud databases (Supabase), disable for local/CI test containers
  ssl: isLocalDatabase ? false : { rejectUnauthorized: false }
});

export default pool;
