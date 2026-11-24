# LGU "Add Business" (web) — Design

**Date:** 2026-11-23
**Branch:** feat/web-lgu/lgu-account-creation
**Size:** Project (schema + backend + web)

## Intent & why

Today the web Businesses page only *lists* businesses and toggles accreditation —
there is no way for an LGU to register a business. The intended model is:
**the LGU registers an accredited business first on the web**, and later the
**merchant claims it from the iOS app** (verifying against the LGU-added record
before creating their login). This is the same two-sided pattern already used for
cardholders (LGU registers on web → citizen claims on iOS).

This design covers **only the web/LGU half**: an "Add Business" flow that mirrors
the existing "Add Record" flow and creates an *unclaimed* accreditation record
(no login account). Email/password are attached later, from the app, when the
merchant claims the business.

## Goals

- Add an "Add Business" modal to the web Businesses page that mirrors Add Record
  (button → dialog → inline validation → server action → list refresh + toast).
- Create an **unclaimed** business record from the mockup's four fields:
  **Business Name, Issuing LGU, Business Permit Number, TIN Number**.
- Show newly added, still-unclaimed businesses in the Businesses table.

## Non-goals (deferred to the business-app branch)

- The iOS "Step 1 of 2 · Verify Accreditation" signup screen.
- Reworking merchant signup (`register-business`) into a *claim* of the LGU record.
- Collecting email / password / address on the web (those come from the app later).
- Category / branch inputs on the web form (DB defaults `category = 'OTHER'`,
  `branch_name = NULL`; can be added later).

## Anti-goals

- Do **not** make the web create a login account for the merchant. An LGU admin
  setting a merchant's password is explicitly out of scope.
- Do **not** build a second merchant self-signup on the web (iOS already has
  `BusinessSignupView`).

## Constraints

- **No schema change.** The live DB is read-only to me and the team doesn't want a
  migration. The design must work within the current `business_profiles` schema,
  where `user_id` and `address` are both `NOT NULL`.
- Must match the existing LGU scoping: LGU_ADMIN acts on their own LGU; SUPERADMIN
  must have a specific city selected (same `resolveCityFilter` / "select a city"
  behavior as cardholders).

## Approaches considered

- **(A) No-schema, placeholder-account pattern — CHOSEN.** The LGU-created record
  gets a *locked* `users` row (generated unique email, random un-loginable
  password, `is_active = false`) plus a `business_profiles` row with a placeholder
  address. Satisfies both `NOT NULL` constraints with zero migration. When the
  merchant claims it from the app, that same row is overwritten with the real
  email/password/address and `is_active = true`.
- **(B) Nullable `user_id`/`address` (cardholder-style).** Cleaner NULLs, but needs
  a live-DB migration + a LEFT JOIN change. Rejected — team doesn't want a schema
  change.
- **(C) Full end-to-end now** (rework `register-business` into a claim + build the
  iOS verify screen). Deferred — the iOS work lives in a different app/branch.
- **(Reuse public `register-business`) — rejected.** Requires email+password up
  front, mints a JWT, and isn't LGU-session-scoped.

## The design

### 1. Schema — unchanged

No DDL. We work within `business_profiles` as-is (`user_id`, `address` stay
`NOT NULL`), satisfied by the placeholder account below.

### 2. Backend — create (`backend/src/index.ts`)

New route `POST /api/lgu/businesses`, modeled on `POST /api/lgu/cardholders`
(index.ts:1229), in a single transaction:

- `authenticateToken` + `requireRole(['LGU_ADMIN','SUPERADMIN'])`.
- Resolve LGU via `resolveCityFilter(req)`; if `all` (SUPERADMIN, no city) →
  `400 "Select a city before registering a business"`.
- Validate required: `business_name`, `business_permit_no`, `tin_number`.
- `BEGIN`:
  1. Insert the **locked placeholder user**:
     `INSERT INTO users (email, password_hash, role, is_active)
      VALUES ($genEmail, $randomHash, 'BUSINESS', FALSE) RETURNING id`.
     - `genEmail` — deterministic + unique from the permit, e.g.
       `unclaimed-<slug(business_permit_no)>@unclaimed.kilala`.
     - `randomHash` — `bcrypt.hash(randomBytes)`; never matches a real password.
       (Must NOT be the test sentinel `$2b$10$MockHashForTestingOnly...`.)
       Combined with `is_active = FALSE`, login is impossible (index.ts:128,136).
  2. Insert the profile:
     `INSERT INTO business_profiles (user_id, lgu_id, business_name,
      business_permit_no, tin_number, address)` with the new `user_id` and a
     placeholder `address` (e.g. `''` or `'Pending — set on claim'`);
     `category`/`branch_name`/`is_accredited` take DB defaults
     (`OTHER` / `NULL` / `TRUE`).
  3. `RETURNING *, (SELECT municipality_name FROM lgus WHERE id = lgu_id) AS lgu_name`.
- `COMMIT`. On error `ROLLBACK`. Duplicate permit/email (`error.code === '23505'`)
  → `409 "Business Permit No. already exists"`. `LguIdError` → its status.

### 3. Backend — list (`backend/src/index.ts`, GET `/api/lgu/businesses` @ ~1394)

The existing `JOIN users u` **still works** (every business has a user row now), so
no join change. Add `u.is_active` to the SELECT so the web can tell *unclaimed*
(`is_active = false`, placeholder email) from *claimed* (`is_active = true`).

### 4. Web — Businesses page

Mirror the Records page structure:

- **`app/dashboard/businesses/page.tsx`** — also fetch `getLgus()` (as
  `records/page.tsx:26` does) and pass `lgus` into the table component.
- **`app/dashboard/businesses/actions.ts`** — new server action
  `createBusiness(input)` modeled on `createCardholder` (records/actions.ts:19):
  same SUPERADMIN selected-city guard, POST to `/api/lgu/businesses`
  (`?lgu_id=` for SUPERADMIN), `revalidatePath("/dashboard/businesses")`.
- **`AddBusinessDialog.tsx`** (new) — modeled on `records/AddRecordDialog.tsx`.
  Reuse the shared `Field` component (exported from AddRecordDialog) and the
  `Select` LGU dropdown pattern (AddRecordDialog.tsx:343–369). Fields + validation:
  - Business Name* — required.
  - Issuing LGU* — required; `Select` over `lgus` (same as Issuing LGU in records).
  - Business Permit Number* — required; client-side dedupe against existing permits
    (like `cardNumber` dedupe at AddRecordDialog.tsx:151–154); placeholder
    `MKT-BP-2026-00001`.
  - TIN Number* — required; placeholder `000-123-456-000`.
  - Submit button labeled **"Add Business"** (mockup's "Verify Business" is the
    *app* step, not this web create step).
- **`businesses-table.tsx`** — add the "Add Business" button in the card header
  (passing `lgus` + existing permits + an `onAdd` that calls `createBusiness` then
  `router.refresh()` + toast, mirroring `RecordsView.handleAdd`). Add `is_active`
  to the `Business` type; for unclaimed rows (`is_active === false`) render the
  contact cell as a small **"No account yet"** / "Unclaimed" indicator instead of
  the placeholder email.

## Blast radius — why this won't break the app, CI, or existing flows

**Schema is unchanged**, so the QA CI pipeline (seed + existing backend/Playwright
specs) runs exactly as before — the whole reason for choosing this approach. The
only additions are a new route and new web UI; nothing existing is altered except
adding `u.is_active` to one SELECT (additive).

I traced every `business_profiles` reader in `backend/src/index.ts`. The locked
placeholder user (`is_active = false`, random hash) can never log in
(index.ts:128 rejects inactive, index.ts:136 needs a real bcrypt match), so no JWT
is ever minted for it until claimed. Every app-facing business query is reached
only through such a login, so an unclaimed record never surfaces to the app:

- **Get business profile** (iOS), index.ts:622 — only reachable with the merchant's
  own JWT; a placeholder account has none until claimed. The row always has a real
  `address` + `user_id`, so the strict iOS decoder
  (`BusinessProfile.address: String`, `userId: UUID`) is safe. **No decode crash.**
- **QR scan verification**, index.ts:762 — `WHERE user_id = $1`: needs the merchant
  logged in; placeholder can't scan.
- **Transactions**, index.ts:1579/1591 — placeholder makes no transactions.
- **Verification-log joins**, index.ts:602/878/1502/1520 — only claimed merchants
  produce scan logs.
- **`register-business`** (iOS self-signup) is untouched by this slice and keeps
  working. (Reworking it into a *claim* of the LGU record is the deferred follow-up;
  until then, a self-signup for an already-added permit simply hits the existing
  `UNIQUE` 409, same as today.)
- **GET `/api/lgu/businesses`** is **LGU-admin-only**
  (`requireRole(['LGU_ADMIN','SUPERADMIN'])`); the app never calls it.

### The one real behavioral effect — LGU dashboard count

`GET /api/lgu/dashboard` counts businesses as
`COUNT(*) ... WHERE is_accredited = TRUE` (index.ts:1132/1135). LGU-added records
default to `is_accredited = TRUE`, so they **will be included** in the dashboard's
"accredited businesses" number before any merchant claims them.

Recommendation: **keep the default `TRUE`** — the LGU has accredited them, so
counting them is correct, and the existing accreditation toggle already lets an
admin revoke one. (If you'd rather they not count until claimed, we'd instead
default new web-created records to `is_accredited = FALSE`; say the word.)

## What's left to the builder

- Exact copy for the dialog header/description and the unclaimed indicator.
- Whether to show a toast action (not required).
- TIN/permit format: keep **required + placeholder hint only**, no strict regex
  (backend enforces permit uniqueness).

## Verification

1. **Build:** `cd backend && npm run build` (tsc) after adding the route.
2. **CI unchanged:** confirm the existing backend + Playwright specs still pass with
   no seed/schema edits (the point of the no-schema approach).
3. **Backend unit/contract:** add a case that `POST /api/lgu/businesses` creates a
   `business_profiles` row linked to a locked (`is_active = false`) placeholder
   user, that the placeholder **cannot** log in, and that a duplicate permit → 409.
4. **Web type/build:** `cd kilala-web && npx tsc --noEmit` and `npm run build`
   (App-Router server/client boundaries aren't caught by tsc alone — build it).
5. **E2E (Playwright, `kilala-web/qa-tests`):** as an LGU admin, open Businesses →
   "Add Business" → fill the four fields → submit → the new business appears in the
   table marked "No account yet". Add this spec alongside the existing specs.
