-- Seed 17 NCR (Metro Manila) Local Government Units
-- Idempotent: ON CONFLICT (lgu_code) DO NOTHING ensures Makati City (MKT) is not duplicated
INSERT INTO lgus (lgu_code, municipality_name, province, region)
VALUES
  ('CAL', 'Caloocan', NULL, 'NCR'),
  ('LPN', 'Las Piñas', NULL, 'NCR'),
  ('MKT', 'Makati City', NULL, 'NCR'),
  ('MAL', 'Malabon', NULL, 'NCR'),
  ('MND', 'Mandaluyong', NULL, 'NCR'),
  ('MNL', 'Manila', NULL, 'NCR'),
  ('MRK', 'Marikina', NULL, 'NCR'),
  ('MUN', 'Muntinlupa', NULL, 'NCR'),
  ('NAV', 'Navotas', NULL, 'NCR'),
  ('PAR', 'Parañaque', NULL, 'NCR'),
  ('PSY', 'Pasay', NULL, 'NCR'),
  ('PSG', 'Pasig', NULL, 'NCR'),
  ('PAT', 'Pateros', NULL, 'NCR'),
  ('QC', 'Quezon City', NULL, 'NCR'),
  ('SJN', 'San Juan', NULL, 'NCR'),
  ('TAG', 'Taguig', NULL, 'NCR'),
  ('VAL', 'Valenzuela', NULL, 'NCR')
ON CONFLICT (lgu_code) DO NOTHING;
