import { Pool } from 'pg';
import bcrypt from 'bcrypt';
import dotenv from 'dotenv';

dotenv.config();

// --- guard: password must be supplied via env ---
const SUPERADMIN_PASSWORD_RAW = process.env.SUPERADMIN_PASSWORD;
if (!SUPERADMIN_PASSWORD_RAW) {
  console.error(
    'ERROR: SUPERADMIN_PASSWORD environment variable is not set.\n' +
      'Usage: SUPERADMIN_PASSWORD=<secret> npx ts-node src/scripts/seed-superadmin.ts'
  );
  process.exit(1);
}
// After the guard above, we know this is a non-empty string.
const SUPERADMIN_PASSWORD: string = SUPERADMIN_PASSWORD_RAW;

const SUPERADMIN_EMAIL =
  process.env.SUPERADMIN_EMAIL ?? 'superadmin@kilala.gov.ph';

// --- config (mirrors backend/src/db.ts) ---
const isLocalDatabase =
  !process.env.DATABASE_URL ||
  process.env.DATABASE_URL.includes('localhost') ||
  process.env.DATABASE_URL.includes('127.0.0.1');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: isLocalDatabase ? false : { rejectUnauthorized: false },
});

async function main(): Promise<void> {
  // 1. Ensure the enum value exists (idempotent — ignore "already exists" errors)
  try {
    await pool.query(`ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'SUPERADMIN';`);
    console.log("user_role enum: 'SUPERADMIN' value ensured.");
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    if (message.includes('already exists')) {
      console.log("user_role enum: 'SUPERADMIN' already present, continuing.");
    } else {
      throw err;
    }
  }

  // 2. Hash password and insert the super-admin row
  const passwordHash = await bcrypt.hash(SUPERADMIN_PASSWORD, 10);

  const result = await pool.query(
    `INSERT INTO users (email, password_hash, role)
     VALUES ($1, $2, 'SUPERADMIN')
     ON CONFLICT (email) DO NOTHING;`,
    [SUPERADMIN_EMAIL, passwordHash]
  );

  if (result.rowCount && result.rowCount > 0) {
    console.log(`Super-admin inserted: ${SUPERADMIN_EMAIL}`);
  } else {
    console.log(`Super-admin already exists, skipped: ${SUPERADMIN_EMAIL}`);
  }
}

main()
  .then(() => {
    console.log('Done.');
    return pool.end();
  })
  .then(() => process.exit(0))
  .catch((err: unknown) => {
    console.error('Seed script failed:', err);
    pool.end().finally(() => process.exit(1));
  });
