import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import pool from './db';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 5001;
const JWT_SECRET = process.env.JWT_SECRET || 'supersecretkilalakey';

app.use(cors());
app.use(express.json());

// TYPES & AUTH MIDDLEWARE
interface JwtPayload {
  id: string;
  email: string;
  role: 'LGU_ADMIN' | 'CARDHOLDER' | 'BUSINESS';
}

interface AuthRequest extends Request {
  user?: JwtPayload;
}

const authenticateToken = (req: AuthRequest, res: Response, next: NextFunction) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  jwt.verify(token, JWT_SECRET, (err, decoded) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid or expired token' });
    }
    req.user = decoded as JwtPayload;
    next();
  });
};

const requireRole = (allowedRoles: Array<'LGU_ADMIN' | 'CARDHOLDER' | 'BUSINESS'>) => {
  return (req: AuthRequest, res: Response, next: NextFunction) => {
    if (!req.user || !allowedRoles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Forbidden: Insufficient permissions' });
    }
    next();
  };
};

// Helper to generate a unique QR token
const generateQrToken = (lguIdNumber: string): string => {
  const randomSuffix = crypto.randomBytes(8).toString('hex').toUpperCase();
  return `KILALA-QR-${lguIdNumber}-${randomSuffix}`;
};

// ============================================================================
// 1. HEALTH & PUBLIC UTILITY ROUTES
// ============================================================================

app.get('/api/health', (_req: Request, res: Response) => {
  res.status(200).json({ status: 'healthy', system: 'Kilala Backend API' });
});

// Get all LGUs (useful for registration dropdowns on Web & iOS)
app.get('/api/lgus', async (_req: Request, res: Response) => {
  try {
    const result = await pool.query(
      'SELECT id, lgu_code, municipality_name, province, region FROM lgus ORDER BY municipality_name ASC'
    );
    res.status(200).json(result.rows);
  } catch (error) {
    console.error('Error fetching LGUs:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ============================================================================
// 2. AUTHENTICATION & ONBOARDING ROUTES
// ============================================================================

// 2.1 Unified Login (Web & iOS)
app.post('/api/auth/login', async (req: Request, res: Response) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password are required' });
  }

  try {
    const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const user = result.rows[0];
    if (!user.is_active) {
      return res.status(403).json({ error: 'Account is deactivated' });
    }

    let isValidPassword = false;
    if (user.password_hash === '$2b$10$MockHashForTestingOnly123456789012') {
      isValidPassword = password === 'MockHashForTestingOnly123456789012';
    } else {
      isValidPassword = await bcrypt.compare(password, user.password_hash);
    }

    if (!isValidPassword) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    await pool.query('UPDATE users SET last_login_at = CURRENT_TIMESTAMP WHERE id = $1', [user.id]);

    const token = jwt.sign(
      { id: user.id, email: user.email, role: user.role },
      JWT_SECRET,
      { expiresIn: '24h' }
    );

    res.status(200).json({
      message: 'Login successful',
      token,
      user: {
        id: user.id,
        email: user.email,
        role: user.role
      }
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// 2.1.1 Verify LGU Record
app.post('/api/auth/verify-record', async (req: Request, res: Response) => {
    const {
        privilege_type,
        card_id_number,
        first_name,
        middle_name,
        last_name,
        date_of_birth
    } = req.body;
    
    if (!privilege_type || !card_id_number || !first_name || !last_name || !date_of_birth) {
        return res.status(400).json({ error: 'All fields are required for verification' });
    }
    
    try {
        // Check if a record matches the provided details
        const profileRes = await pool.query(
            `SELECT id, user_id, first_name, last_name, status 
            FROM cardholder_profiles 
            WHERE lgu_id_number = $1 
                AND privilege_type = $2 
                AND date_of_birth = $3 
                AND first_name ILIKE $4 
                AND last_name ILIKE $5
                AND COALESCE(middle_name, '') ILIKE $6`,
            [card_id_number, privilege_type, date_of_birth, first_name, last_name, middle_name || '' ]
        );
        
        if (profileRes.rows.length === 0) {
            return res.status(404).json({ error: 'No matching LGU record found. Please check your details.' });
        }
        
        const profile = profileRes.rows[0];
        
        // Check if card is still active
        if (profile.status !== 'ACTIVE') {
            return res.status(403).json({ error: `Cannot claim account. Card status is ${profile.status}.` });
        }
        
        // Check if card is not yet claimed by another user
        if (profile.user_id) {
            return res.status(409).json({ error: 'This ID has already been claimed by an existing account.' });
        }
        
        // Success
        res.status(200).json({
            message: 'Record verified successfully',
            profile_id: profile.id,
            first_name: profile.first_name,
            middle_name: profile.middle_name,
            last_name: profile.last_name
        });
    } catch (error) {
        console.error('Verify record error: ', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// 2.2 Claim Pre-Registered Cardholder Account on iOS
// When an LGU registers a Senior/PWD without an account, the citizen can claim it on iOS
app.post('/api/auth/claim-cardholder', async (req: Request, res: Response) => {
  const { lgu_id_number, date_of_birth, email, password } = req.body;

  if (!lgu_id_number || !date_of_birth || !email || !password) {
    return res.status(400).json({ error: 'All fields are required to claim your ID' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Find unclaimed cardholder matching ID number and birth date
    const profileRes = await client.query(
      `SELECT * FROM cardholder_profiles 
       WHERE lgu_id_number = $1 AND date_of_birth = $2`,
      [lgu_id_number, date_of_birth]
    );

    if (profileRes.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'No matching LGU record found' });
    }

    const profile = profileRes.rows[0];
    if (profile.user_id) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'This ID has already been claimed by an account' });
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const userRes = await client.query(
      `INSERT INTO users (email, password_hash, role)
       VALUES ($1, $2, 'CARDHOLDER')
       RETURNING id, email, role`,
      [email, passwordHash]
    );

    const newUser = userRes.rows[0];

    await client.query(
      'UPDATE cardholder_profiles SET user_id = $1 WHERE id = $2',
      [newUser.id, profile.id]
    );

    await client.query('COMMIT');

    const token = jwt.sign(
      { id: newUser.id, email: newUser.email, role: newUser.role },
      JWT_SECRET,
      { expiresIn: '24h' }
    );

    res.status(201).json({
      message: 'Cardholder account claimed successfully',
      token,
      user: newUser
    });
  } catch (error: any) {
    await client.query('ROLLBACK');
    if (error.code === '23505') {
      return res.status(409).json({ error: 'Email is already in use' });
    }
    console.error('Claim cardholder error:', error);
    res.status(500).json({ error: 'Internal server error' });
  } finally {
    client.release();
  }
});

// 2.3 Register Business Account
app.post('/api/auth/register-business', async (req: Request, res: Response) => {
  const {
    email,
    password,
    lgu_id,
    business_name,
    branch_name,
    category,
    business_permit_no,
    tin_number,
    address
  } = req.body;

  if (!email || !password || !lgu_id || !business_name || !business_permit_no || !tin_number || !address) {
    return res.status(400).json({ error: 'Missing required business registration fields' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const passwordHash = await bcrypt.hash(password, 10);
    const userRes = await client.query(
      `INSERT INTO users (email, password_hash, role)
       VALUES ($1, $2, 'BUSINESS')
       RETURNING id, email, role`,
      [email, passwordHash]
    );

    const newUser = userRes.rows[0];

    const bizRes = await client.query(
      `INSERT INTO business_profiles (
         user_id, lgu_id, business_name, branch_name, category,
         business_permit_no, tin_number, address
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING *`,
      [
        newUser.id,
        lgu_id,
        business_name,
        branch_name || null,
        category || 'OTHER',
        business_permit_no,
        tin_number,
        address
      ]
    );

    await client.query('COMMIT');

    const token = jwt.sign(
      { id: newUser.id, email: newUser.email, role: newUser.role },
      JWT_SECRET,
      { expiresIn: '24h' }
    );

    res.status(201).json({
      message: 'Business registered successfully',
      token,
      user: newUser,
      businessProfile: bizRes.rows[0]
    });
  } catch (error: any) {
    await client.query('ROLLBACK');
    if (error.code === '23505') {
      return res.status(409).json({ error: 'Email or Business Permit No. already exists' });
    }
    console.error('Business registration error:', error);
    res.status(500).json({ error: 'Internal server error' });
  } finally {
    client.release();
  }
});

// ============================================================================
// 3. CARDHOLDER ROUTES (iOS - PWD & Senior Citizens)
// ============================================================================

// 3.1 Get Logged-in Cardholder Profile & QR Token
app.get(
  '/api/cardholder/me',
  authenticateToken,
  requireRole(['CARDHOLDER']),
  async (req: AuthRequest, res: Response) => {
    try {
      const result = await pool.query(
        `SELECT cp.*, l.municipality_name AS lgu_name, l.lgu_code
         FROM cardholder_profiles cp
         JOIN lgus l ON l.id = cp.lgu_id
         WHERE cp.user_id = $1`,
        [req.user!.id]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Cardholder profile not found' });
      }

      res.status(200).json(result.rows[0]);
    } catch (error) {
      console.error('Error fetching cardholder profile:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// 3.2 Rotate / Refresh QR Secret Token
app.post(
  '/api/cardholder/refresh-qr',
  authenticateToken,
  requireRole(['CARDHOLDER']),
  async (req: AuthRequest, res: Response) => {
    try {
      const profileRes = await pool.query(
        'SELECT id, lgu_id_number FROM cardholder_profiles WHERE user_id = $1',
        [req.user!.id]
      );

      if (profileRes.rows.length === 0) {
        return res.status(404).json({ error: 'Cardholder profile not found' });
      }

      const { id, lgu_id_number } = profileRes.rows[0];
      const newToken = generateQrToken(lgu_id_number);

      const updated = await pool.query(
        `UPDATE cardholder_profiles
         SET qr_secret_token = $1
         WHERE id = $2
         RETURNING qr_secret_token, updated_at`,
        [newToken, id]
      );

      res.status(200).json(updated.rows[0]);
    } catch (error) {
      console.error('Error refreshing QR token:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// 3.3 Get Cardholder Scan History
app.get(
  '/api/cardholder/history',
  authenticateToken,
  requireRole(['CARDHOLDER']),
  async (req: AuthRequest, res: Response) => {
    try {
      const result = await pool.query(
        `SELECT vl.id,
                vl.status_at_scan,
                vl.is_valid,
                vl.failure_reason,
                vl.scanned_at,
                bp.business_name,
                bp.branch_name,
                bp.category AS business_category
         FROM verification_logs vl
         JOIN cardholder_profiles cp ON cp.id = vl.cardholder_id
         JOIN business_profiles bp ON bp.id = vl.business_id
         WHERE cp.user_id = $1
         ORDER BY vl.scanned_at DESC
         LIMIT 50`,
        [req.user!.id]
      );

      res.status(200).json(result.rows);
    } catch (error) {
      console.error('Error fetching cardholder history:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// ============================================================================
// 4. BUSINESS & QR VERIFICATION ROUTES (iOS - Merchants)
// ============================================================================

// 4.1 Get Logged-in Business Profile
app.get(
  '/api/business/me',
  authenticateToken,
  requireRole(['BUSINESS']),
  async (req: AuthRequest, res: Response) => {
    try {
      const result = await pool.query(
        `SELECT bp.*, l.municipality_name AS lgu_name
         FROM business_profiles bp
         JOIN lgus l ON l.id = bp.lgu_id
         WHERE bp.user_id = $1`,
        [req.user!.id]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Business profile not found' });
      }

      res.status(200).json(result.rows[0]);
    } catch (error) {
      console.error('Error fetching business profile:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// 4.2 Scan & Verify Cardholder QR Code
app.post(
  '/api/verify/scan',
  authenticateToken,
  requireRole(['BUSINESS']),
  async (req: AuthRequest, res: Response) => {
    const { qr_token } = req.body;

    if (!qr_token) {
      return res.status(400).json({ error: 'qr_token is required' });
    }

    try {
      // 1. Verify the scanning business is accredited
      const bizRes = await pool.query(
        'SELECT id, is_accredited FROM business_profiles WHERE user_id = $1',
        [req.user!.id]
      );

      if (bizRes.rows.length === 0) {
        return res.status(404).json({ error: 'Business profile not found' });
      }

      const business = bizRes.rows[0];
      if (!business.is_accredited) {
        return res.status(403).json({ error: 'Business accreditation is currently inactive' });
      }

      // 2. Look up cardholder by QR token
      const cardRes = await pool.query(
        `SELECT cp.*, l.municipality_name AS lgu_name
         FROM cardholder_profiles cp
         JOIN lgus l ON l.id = cp.lgu_id
         WHERE cp.qr_secret_token = $1`,
        [qr_token]
      );

      if (cardRes.rows.length === 0) {
        return res.status(404).json({
          isValid: false,
          scanTimestamp: new Date().toISOString(),
          message: 'Unrecognized or counterfeit QR code',
          cardholderSummary: null
        });
      }

      const cardholder = cardRes.rows[0];
      let currentStatus = cardholder.status;
      let isValid = currentStatus === 'ACTIVE';
      let failureReason: string | null = null;

      // 3. Check if card has passed its expiry_date
      if (cardholder.expiry_date && new Date(cardholder.expiry_date) < new Date()) {
        currentStatus = 'EXPIRED';
        isValid = false;
        failureReason = 'Privilege card has expired';

        // Persist expired status in DB if not updated yet
        if (cardholder.status !== 'EXPIRED') {
          await pool.query('UPDATE cardholder_profiles SET status = $1 WHERE id = $2', [
            'EXPIRED',
            cardholder.id
          ]);
        }
      } else if (!isValid) {
        failureReason = `Card status is ${currentStatus}`;
      }

      // 4. Record audit log in verification_logs
      const logRes = await pool.query(
        `INSERT INTO verification_logs (
           cardholder_id, business_id, status_at_scan, is_valid, failure_reason
         ) VALUES ($1, $2, $3, $4, $5)
         RETURNING id, scanned_at`,
        [cardholder.id, business.id, currentStatus, isValid, failureReason]
      );

      const fullName = [cardholder.first_name, cardholder.middle_name, cardholder.last_name]
        .filter(Boolean)
        .join(' ');

      res.status(200).json({
        logId: logRes.rows[0].id,
        isValid,
        scanTimestamp: logRes.rows[0].scanned_at,
        message: isValid ? 'Valid Privilege Card' : failureReason,
        cardholderSummary: {
          id: cardholder.id,
          fullName,
          dateOfBirth: cardholder.date_of_birth,
          sex: cardholder.sex,
          privilegeType: cardholder.privilege_type,
          disabilityType: cardholder.disability_type,
          lguIdNumber: cardholder.lgu_id_number,
          lguName: cardholder.lgu_name,
          status: currentStatus,
          expiryDate: cardholder.expiry_date,
          photoUrl: cardholder.photo_url
        }
      });
    } catch (error) {
      console.error('QR scan verification error:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// 4.3 Get Business Scan History
app.get(
  '/api/business/history',
  authenticateToken,
  requireRole(['BUSINESS']),
  async (req: AuthRequest, res: Response) => {
    try {
      const result = await pool.query(
        `SELECT vl.id,
                vl.status_at_scan,
                vl.is_valid,
                vl.failure_reason,
                vl.scanned_at,
                cp.first_name,
                cp.last_name,
                cp.lgu_id_number,
                cp.privilege_type
         FROM verification_logs vl
         JOIN business_profiles bp ON bp.id = vl.business_id
         LEFT JOIN cardholder_profiles cp ON cp.id = vl.cardholder_id
         WHERE bp.user_id = $1
         ORDER BY vl.scanned_at DESC
         LIMIT 50`,
        [req.user!.id]
      );

      res.status(200).json(result.rows);
    } catch (error) {
      console.error('Error fetching business history:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// ============================================================================
// 5. LGU ADMIN PORTAL ROUTES (Web Application)
// ============================================================================

// Helper to get the logged-in LGU Admin's profile and lgu_id
const getAdminContext = async (userId: string) => {
  const res = await pool.query(
    `SELECT la.*, l.municipality_name AS lgu_name, l.lgu_code
     FROM lgu_admins la
     JOIN lgus l ON l.id = la.lgu_id
     WHERE la.user_id = $1`,
    [userId]
  );
  return res.rows[0] || null;
};

// 5.1 Get LGU Admin Profile & Dashboard Summary Analytics
app.get(
  '/api/lgu/dashboard',
  authenticateToken,
  requireRole(['LGU_ADMIN']),
  async (req: AuthRequest, res: Response) => {
    try {
      const admin = await getAdminContext(req.user!.id);
      if (!admin) {
        return res.status(404).json({ error: 'LGU Admin profile not found' });
      }

      const statsQuery = await pool.query(
        `SELECT
           COUNT(*) AS total_cardholders,
           COUNT(*) FILTER (WHERE status = 'ACTIVE' AND privilege_type = 'PWD') AS active_pwd,
           COUNT(*) FILTER (WHERE status = 'ACTIVE' AND privilege_type = 'SENIOR_CITIZEN') AS active_senior,
           COUNT(*) FILTER (WHERE status != 'ACTIVE') AS inactive_cards
         FROM cardholder_profiles
         WHERE lgu_id = $1`,
        [admin.lgu_id]
      );

      const bizCountQuery = await pool.query(
        'SELECT COUNT(*) AS total_businesses FROM business_profiles WHERE lgu_id = $1 AND is_accredited = TRUE',
        [admin.lgu_id]
      );

      const scanStatsQuery = await pool.query(
        `SELECT
           COUNT(*) AS total_scans,
           COUNT(*) FILTER (WHERE vl.is_valid = TRUE) AS valid_scans,
           COUNT(*) FILTER (WHERE vl.is_valid = FALSE) AS invalid_scans,
           COUNT(*) FILTER (WHERE vl.scanned_at >= CURRENT_DATE) AS scans_today
         FROM verification_logs vl
         JOIN cardholder_profiles cp ON cp.id = vl.cardholder_id
         WHERE cp.lgu_id = $1`,
        [admin.lgu_id]
      );

      res.status(200).json({
        admin,
        cardholderStats: statsQuery.rows[0],
        totalAccreditedBusinesses: Number(bizCountQuery.rows[0].total_businesses),
        scanStats: scanStatsQuery.rows[0]
      });
    } catch (error) {
      console.error('Error fetching LGU dashboard:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// 5.2 List & Filter Cardholders in LGU
app.get(
  '/api/lgu/cardholders',
  authenticateToken,
  requireRole(['LGU_ADMIN']),
  async (req: AuthRequest, res: Response) => {
    try {
      const admin = await getAdminContext(req.user!.id);
      if (!admin) return res.status(404).json({ error: 'LGU Admin not found' });

      const { status, privilege_type, search } = req.query;
      const params: any[] = [admin.lgu_id];
      let query = `
        SELECT cp.*, u.email
        FROM cardholder_profiles cp
        LEFT JOIN users u ON u.id = cp.user_id
        WHERE cp.lgu_id = $1
      `;

      if (status) {
        params.push(status);
        query += ` AND cp.status = $${params.length}`;
      }
      if (privilege_type) {
        params.push(privilege_type);
        query += ` AND cp.privilege_type = $${params.length}`;
      }
      if (search) {
        params.push(`%${search}%`);
        query += ` AND (cp.first_name ILIKE $${params.length} OR cp.last_name ILIKE $${params.length} OR cp.lgu_id_number ILIKE $${params.length})`;
      }

      query += ' ORDER BY cp.created_at DESC';

      const result = await pool.query(query, params);
      res.status(200).json(result.rows);
    } catch (error) {
      console.error('Error listing cardholders:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// 5.3 Register a New Cardholder (LGU Web Portal)
app.post(
  '/api/lgu/cardholders',
  authenticateToken,
  requireRole(['LGU_ADMIN']),
  async (req: AuthRequest, res: Response) => {
    const {
      email,
      password,
      lgu_id_number,
      first_name,
      middle_name,
      last_name,
      date_of_birth,
      sex,
      address,
      contact_number,
      emergency_contact_name,
      emergency_contact_phone,
      privilege_type,
      disability_type,
      expiry_date,
      photo_url
    } = req.body;

    if (!lgu_id_number || !first_name || !last_name || !date_of_birth || !sex || !address || !privilege_type) {
      return res.status(400).json({ error: 'Missing required constituent fields' });
    }

    if (privilege_type === 'PWD' && !disability_type) {
      return res.status(400).json({ error: 'disability_type is required for PWD cardholders' });
    }

    const client = await pool.connect();
    try {
      const admin = await getAdminContext(req.user!.id);
      if (!admin) return res.status(404).json({ error: 'LGU Admin not found' });

      await client.query('BEGIN');

      let newUserId: string | null = null;
      if (email && password) {
        const passwordHash = await bcrypt.hash(password, 10);
        const userRes = await client.query(
          `INSERT INTO users (email, password_hash, role)
           VALUES ($1, $2, 'CARDHOLDER')
           RETURNING id`,
          [email, passwordHash]
        );
        newUserId = userRes.rows[0].id;
      }

      const qrToken = generateQrToken(lgu_id_number);

      const profileRes = await client.query(
        `INSERT INTO cardholder_profiles (
           user_id, lgu_id, issued_by_admin_id, lgu_id_number,
           first_name, middle_name, last_name, date_of_birth, sex, address,
           contact_number, emergency_contact_name, emergency_contact_phone,
           privilege_type, disability_type, qr_secret_token, photo_url, expiry_date
         ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18)
         RETURNING *`,
        [
          newUserId,
          admin.lgu_id,
          admin.id,
          lgu_id_number,
          first_name,
          middle_name || null,
          last_name,
          date_of_birth,
          sex,
          address,
          contact_number || null,
          emergency_contact_name || null,
          emergency_contact_phone || null,
          privilege_type,
          privilege_type === 'PWD' ? disability_type : null,
          qrToken,
          photo_url || null,
          expiry_date || null
        ]
      );

      await client.query('COMMIT');
      res.status(201).json(profileRes.rows[0]);
    } catch (error: any) {
      await client.query('ROLLBACK');
      if (error.code === '23505') {
        return res.status(409).json({ error: 'LGU ID Number or Email already exists' });
      }
      console.error('Error creating cardholder:', error);
      res.status(500).json({ error: 'Internal server error' });
    } finally {
      client.release();
    }
  }
);

// 5.4 Update Cardholder Details or Status (e.g., Activate, Revoke, Suspend, Renew)
app.patch(
  '/api/lgu/cardholders/:id',
  authenticateToken,
  requireRole(['LGU_ADMIN']),
  async (req: AuthRequest, res: Response) => {
    const { id } = req.params;
    const { status, address, contact_number, expiry_date, photo_url } = req.body;

    try {
      const admin = await getAdminContext(req.user!.id);
      if (!admin) return res.status(404).json({ error: 'LGU Admin not found' });

      const result = await pool.query(
        `UPDATE cardholder_profiles
         SET status = COALESCE($1, status),
             address = COALESCE($2, address),
             contact_number = COALESCE($3, contact_number),
             expiry_date = COALESCE($4, expiry_date),
             photo_url = COALESCE($5, photo_url)
         WHERE id = $6 AND lgu_id = $7
         RETURNING *`,
        [status, address, contact_number, expiry_date, photo_url, id, admin.lgu_id]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Cardholder not found in your LGU' });
      }

      res.status(200).json(result.rows[0]);
    } catch (error) {
      console.error('Error updating cardholder:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// 5.5 List Accredited Businesses in LGU
app.get(
  '/api/lgu/businesses',
  authenticateToken,
  requireRole(['LGU_ADMIN']),
  async (req: AuthRequest, res: Response) => {
    try {
      const admin = await getAdminContext(req.user!.id);
      if (!admin) return res.status(404).json({ error: 'LGU Admin not found' });

      const result = await pool.query(
        `SELECT bp.*, u.email
         FROM business_profiles bp
         JOIN users u ON u.id = bp.user_id
         WHERE bp.lgu_id = $1
         ORDER BY bp.created_at DESC`,
        [admin.lgu_id]
      );

      res.status(200).json(result.rows);
    } catch (error) {
      console.error('Error fetching LGU businesses:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// 5.6 Toggle Business Accreditation Status
app.patch(
  '/api/lgu/businesses/:id/accreditation',
  authenticateToken,
  requireRole(['LGU_ADMIN']),
  async (req: AuthRequest, res: Response) => {
    const { id } = req.params;
    const { is_accredited } = req.body;

    if (typeof is_accredited !== 'boolean') {
      return res.status(400).json({ error: 'is_accredited boolean is required' });
    }

    try {
      const admin = await getAdminContext(req.user!.id);
      if (!admin) return res.status(404).json({ error: 'LGU Admin not found' });

      const result = await pool.query(
        `UPDATE business_profiles
         SET is_accredited = $1
         WHERE id = $2 AND lgu_id = $3
         RETURNING *`,
        [is_accredited, id, admin.lgu_id]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Business not found in your LGU' });
      }

      res.status(200).json(result.rows[0]);
    } catch (error) {
      console.error('Error updating business accreditation:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// 5.7 Get Global LGU Verification Audit Logs
app.get(
  '/api/lgu/logs',
  authenticateToken,
  requireRole(['LGU_ADMIN']),
  async (req: AuthRequest, res: Response) => {
    try {
      const admin = await getAdminContext(req.user!.id);
      if (!admin) return res.status(404).json({ error: 'LGU Admin not found' });

      const result = await pool.query(
        `SELECT vl.id,
                vl.status_at_scan,
                vl.is_valid,
                vl.failure_reason,
                vl.scanned_at,
                cp.first_name,
                cp.last_name,
                cp.lgu_id_number,
                cp.privilege_type,
                bp.business_name,
                bp.branch_name
         FROM verification_logs vl
         JOIN cardholder_profiles cp ON cp.id = vl.cardholder_id
         JOIN business_profiles bp ON bp.id = vl.business_id
         WHERE cp.lgu_id = $1
         ORDER BY vl.scanned_at DESC
         LIMIT 100`,
        [admin.lgu_id]
      );

      res.status(200).json(result.rows);
    } catch (error) {
      console.error('Error fetching LGU audit logs:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// ============================================================================
// SERVER INITIALIZATION
// ============================================================================

app.listen(PORT, async () => {
  console.log(`[server]: Kilala backend running on port ${PORT}`);
  try {
    const client = await pool.connect();
    console.log('[server]: Connected to Supabase PostgreSQL successfully!');
    client.release();
  } catch (err) {
    console.error('[server]: Failed to connect to the database', err);
  }
});
