# LGU "Add Business" (web) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an LGU admin register an accredited business from the web Businesses page, creating an unclaimed record the merchant later claims from the app — mirroring the existing Add Record flow.

**Architecture:** A new authed `POST /api/lgu/businesses` creates, in one transaction, a *locked* placeholder `users` row (`is_active = false`, random hash) plus the `business_profiles` row, satisfying the current `NOT NULL` columns with **no schema change**. The web Businesses page gains an "Add Business" dialog modeled on `AddRecordDialog`, wired through a `createBusiness` server action.

**Tech Stack:** Express + `pg` (backend, TypeScript), Next.js App Router server actions + React client components + shadcn/ui (web), Playwright (`kilala-web/qa-tests`) for backend-contract and web E2E tests.

**Spec:** `docs/superpowers/specs/2026-11-23-lgu-add-business-design.md`

## Global Constraints

- **No schema change** — work within `business_profiles` as-is (`user_id`, `address` are `NOT NULL`). This keeps the QA CI seed/pipeline untouched.
- Placeholder user is **`role = 'BUSINESS'`, `is_active = false`, `password_hash = bcrypt(random)`** — never the test sentinel `$2b$10$MockHashForTestingOnly123456789012`.
- New web businesses keep **`is_accredited = TRUE`** (DB default) — they count on the LGU dashboard immediately.
- LGU scoping mirrors `POST /api/lgu/cardholders`: use `resolveCityFilter(req)`; SUPERADMIN with no city (`all === true`) → `400 "Select a city before registering a business"`.
- Web form collects **only** Business Name, Issuing LGU, Business Permit Number, TIN Number (no email/password/address).
- Mirror existing patterns: backend route after the cardholder routes in `backend/src/index.ts`; web dialog/action after `app/dashboard/records/`.

## Review Focus

- **Duplicate `business_permit_no`** (UNIQUE) → `409`, no row created — covered in Task 1.
- **SUPERADMIN with no city selected** → `400`, no row created — covered in Task 1.
- **Placeholder account must be un-loginable** (`is_active = false`) → login attempt with the generated email fails — covered in Task 1.
- **Unclaimed business renders in the web table** without the raw placeholder email leaking (shows "No account yet") — covered in Task 2.
- **Missing required fields** (`business_name`/`business_permit_no`/`tin_number`) → `400` — covered in Task 1.

---

## File Structure

- `backend/src/index.ts` — **new** `POST /api/lgu/businesses` route (place next to the cardholder routes, ~after line 1336); **modify** GET `/api/lgu/businesses` (~1394) to add `u.is_active` to both SELECT branches.
- `kilala-web/app/dashboard/businesses/actions.ts` — **add** `createBusiness` server action next to `toggleAccreditation`.
- `kilala-web/app/dashboard/businesses/AddBusinessDialog.tsx` — **new** client dialog modeled on `records/AddRecordDialog.tsx`.
- `kilala-web/app/dashboard/businesses/businesses-table.tsx` — **modify** to accept `lgus`, render the Add Business button + unclaimed indicator, widen the `Business` type.
- `kilala-web/app/dashboard/businesses/page.tsx` — **modify** to fetch `getLgus()` and pass `lgus`.
- `kilala-web/qa-tests/businesses-api.spec.ts` — **new** Playwright backend-contract spec.
- `kilala-web/qa-tests/businesses.spec.ts` — **new** Playwright web E2E spec.

---

## Task 1: Backend — `POST /api/lgu/businesses` + list `is_active`

**Files:**
- Modify: `backend/src/index.ts` (new route after cardholder routes; GET `/api/lgu/businesses` SELECT ~1394)
- Test: `kilala-web/qa-tests/businesses-api.spec.ts`

**Interfaces:**
- Consumes (existing helpers in `index.ts`): `authenticateToken`, `requireRole(['LGU_ADMIN','SUPERADMIN'])`, `resolveCityFilter(req): Promise<{all: boolean; lguId: string|null}>`, `LguIdError`, `bcrypt`, `crypto`, `pool`.
- Produces: `POST /api/lgu/businesses` accepting `{ business_name, business_permit_no, tin_number }` → `201` with the created `business_profiles` row plus `lgu_name` and `is_active`. GET `/api/lgu/businesses` rows now include `is_active: boolean`.

- [ ] **Step 1: Write the failing contract tests**

In `kilala-web/qa-tests/businesses-api.spec.ts` (model auth on `api-contracts.spec.ts` / `records.spec.ts`: POST `/api/auth/login` as `admin@makati.gov.ph` / `MockHashForTestingOnly123456789012` → real `token`). Use a per-run unique permit, e.g. `const permit = \`QA-BP-\${Date.now()}\``.

```ts
// creates an unclaimed accredited business (201) with a locked placeholder account
test('POST /api/lgu/businesses creates an unclaimed accredited business', async ({ request }) => {
  // login -> token; POST { business_name:'QA Mart', business_permit_no:permit, tin_number:'000-1-2-3' }
  // expect 201; body.business_name==='QA Mart'; body.is_accredited===true;
  // typeof body.lgu_name==='string'; body.is_active===false
});

test('rejects missing required fields with 400', async () => { /* POST {} -> 400 */ });

test('rejects a SUPERADMIN with no city selected with 400', async () => {
  // login as the seeded SUPERADMIN (reuse creds/helper from superadmin-rbac.spec.ts);
  // POST /api/lgu/businesses with no ?lgu_id -> 400 { error: 'Select a city before registering a business' }
});

test('rejects a duplicate business permit with 409', async () => {
  // POST permit twice -> second is 409
});

test('the placeholder account cannot log in', async () => {
  // after create, POST /api/auth/login with the generated email + any password -> not 200 (403/401)
  // generated email format: unclaimed-<slug(permit)>@unclaimed.kilala
});

test('GET /api/lgu/businesses includes is_active for each row', async () => {
  // login -> GET -> every row has typeof row.is_active === 'boolean'
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd kilala-web && npx playwright test qa-tests/businesses-api.spec.ts --project=chromium`
Expected: FAIL (route 404 / missing `is_active`). Requires backend on `:5001` + seeded DB (playwright `webServer`).

- [ ] **Step 3: Implement the route and the list field in `backend/src/index.ts`**

Add `app.post('/api/lgu/businesses', authenticateToken, requireRole(['LGU_ADMIN','SUPERADMIN']), async (req, res) => {...})`, modeled on the cardholder POST (index.ts:1229):
- Destructure `business_name, business_permit_no, tin_number`; if any missing → `400 { error: 'Missing required business fields' }`.
- `const { all, lguId } = await resolveCityFilter(req); if (all) return 400 { error: 'Select a city before registering a business' }`.
- Build the placeholder email `unclaimed-<slug>@unclaimed.kilala` where `slug` lowercases `business_permit_no` and replaces non-alphanumerics with `-`; `const randomHash = await bcrypt.hash(crypto.randomBytes(16).toString('hex'), 10)`.
- Transaction: `INSERT INTO users (email, password_hash, role, is_active) VALUES ($email,$randomHash,'BUSINESS',FALSE) RETURNING id`, then `INSERT INTO business_profiles (user_id, lgu_id, business_name, business_permit_no, tin_number, address) VALUES (..., '')` (category/branch/is_accredited use defaults). `RETURNING *, FALSE AS is_active, (SELECT municipality_name FROM lgus WHERE id = $lguId) AS lgu_name`.
- On `error.code === '23505'` → `409 { error: 'Business Permit No. already exists' }`; `LguIdError` → `error.statusCode`; else `500`. `ROLLBACK` on error, `COMMIT` on success; `client.release()` in `finally`.

Then in GET `/api/lgu/businesses` (index.ts:~1402/1409), add `u.is_active` to both SELECT lists (keep the existing `JOIN users u`).

- [ ] **Step 4: Build and run the tests to verify they pass**

Run: `cd backend && npm run build` then `cd ../kilala-web && npx playwright test qa-tests/businesses-api.spec.ts --project=chromium`
Expected: tsc succeeds; all Task 1 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/src/index.ts kilala-web/qa-tests/businesses-api.spec.ts
git commit -m "feat(api): LGU creates unclaimed businesses via POST /api/lgu/businesses"
```

---

## Task 2: Web — Add Business dialog, action, and table wiring

**Files:**
- Create: `kilala-web/app/dashboard/businesses/AddBusinessDialog.tsx`
- Modify: `kilala-web/app/dashboard/businesses/actions.ts`, `businesses-table.tsx`, `page.tsx`
- Test: `kilala-web/qa-tests/businesses.spec.ts`

**Interfaces:**
- Consumes: Task 1's `POST /api/lgu/businesses`; `getLgus()` and `Lgu` from `@/lib/lgus`; `getCurrentUser`, `getSelectedCity`, `getLguIdParam`, `ALL_CITIES` from `@/lib/*` (as `records/actions.ts` uses); the exported `Field` component from `records/AddRecordDialog.tsx`; shadcn `Dialog`/`Select`/`Input`/`Button`.
- Produces: `createBusiness(input: { businessName: string; issuingLgu: string; permitNo: string; tin: string }): Promise<{ error?: string }>`; `AddBusinessDialog` (props `{ lgus: Lgu[]; existingPermits: string[]; onAdd: (input) => void }`); `Business` type extended with `is_active: boolean` and `email: string | null`.

- [ ] **Step 1: Write the failing web E2E tests**

In `kilala-web/qa-tests/businesses.spec.ts`, model login/cookie on `records.spec.ts` (real backend login → set `kilala_token` cookie → `page.goto('/dashboard/businesses')`). Mirror the Add Record dialog tests (`records.spec.ts:213,235`) — validate the UI without creating a row:

```ts
test('+ Add Business opens a dialog whose Issuing LGU field lists Metro Manila cities', async ({ page }) => {
  // click button '+ Add Business'; open 'Issuing LGU' select; expect a known city option (e.g. /Makati/)
});

test('validates duplicate business permits against live rows without creating one', async ({ page, request }) => {
  // read an existing permit via GET /api/lgu/businesses; enter it in the dialog; submit;
  // expect an inline error and no new row
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd kilala-web && npx playwright test qa-tests/businesses.spec.ts --project=chromium`
Expected: FAIL (no `+ Add Business` button).

- [ ] **Step 3: Implement the action**

In `app/dashboard/businesses/actions.ts` add `createBusiness`, modeled on `createCardholder` (`records/actions.ts:19`): SUPERADMIN selected-city guard (reuse `getSelectedCity`/`ALL_CITIES` → return `{ error: 'Select a city from the top bar before adding a business.' }` when unset/ALL); POST to `/api/lgu/businesses` with `?lgu_id=` for SUPERADMIN (via `getLguIdParam`), body `{ business_name, business_permit_no, tin_number }`; map `ApiError` → `{ error }`; `revalidatePath('/dashboard/businesses')`.

- [ ] **Step 4: Implement the dialog and table wiring**

- `AddBusinessDialog.tsx`: mirror `AddRecordDialog` structure — `+ Add Business` trigger button, `Dialog`, four `Field`s (Business Name\*, Issuing LGU\* via `Select` over `lgus`, Business Permit Number\* placeholder `MKT-BP-2026-00001`, TIN Number\* placeholder `000-123-456-000`). Validation: required trims; permit dedupe against `existingPermits` (case-insensitive, like `AddRecordDialog.tsx:151–154`). Submit button label **"Add Business"**; on success call `onAdd` and close.
- `businesses-table.tsx`: extend `Business` with `is_active: boolean` and `email: string | null`; add `lgus: Lgu[]` to props; render `<AddBusinessDialog lgus={lgus} existingPermits={...} onAdd={handleAdd} />` in the `CardHeader`; `handleAdd` calls `createBusiness` in a transition, then on success `router.refresh()` + a toast, on error a toast (mirror `RecordsView.handleAdd`/toast). In the Contact cell, when `!b.is_active` show a muted **"No account yet"** instead of the email. (Add `useRouter` import.)
- `page.tsx`: fetch `getLgus()` alongside the businesses fetch and pass `lgus` into `BusinessesTable`; `Business` rows now include `is_active`.

- [ ] **Step 5: Type-check, build, and run the tests to verify they pass**

Run: `cd kilala-web && npx tsc --noEmit && npm run build && npx playwright test qa-tests/businesses.spec.ts --project=chromium`
Expected: tsc + build succeed (build catches App-Router server/client boundary issues); Task 2 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add kilala-web/app/dashboard/businesses kilala-web/qa-tests/businesses.spec.ts
git commit -m "feat(web): Add Business dialog on the Businesses page"
```

---

## Notes for the executor

- Both tasks' tests need the Playwright `webServer` (backend `:5001` + web `:3000` + seeded DB) — the same setup the existing `qa-tests` rely on.
- The positive create test (Task 1) writes a row + placeholder user to the seeded CI DB using a unique permit per run; CI re-seeds per run, so no cleanup is required. Do **not** reuse a fixed permit.
- iOS "Verify Accreditation" signup + reworking `register-business` into a claim are **out of scope** (deferred follow-up, per the spec's non-goals).
