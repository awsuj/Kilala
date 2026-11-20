# Kilala iOS – QA Test Suite (Sprint 1 and MCO4 Automation Test Plan)

| | |
|---|---|
| **Scope** | Sprint 1 – Foundation, Contracts & Auth, plus the iOS test cases of the MCO4 Automation Test Plan (CH – iOS Cardholder App, BUS – iOS Business App) |
| **Author** | Edson John Willie (QA / iOS Developer) |
| **Branch** | `test/app/automation-plan` (Sprint 1 suite: `test/app/sprint-1`, merged in PR #38) |
| **Targets** | `KilalaTests` (Swift Testing) · `KilalaUITests` (XCTest / XCUIAutomation) |
| **Last run** | 20 Nov 2026 · Xcode 27.2 · iPhone 17 simulator (iOS 27.2) · see [§7](#7-latest-results) |

Related QA work: web Playwright tests ([PR #31](https://github.com/awsuj/Kilala/pull/31)) and backend Postman collection ([PR #32](https://github.com/awsuj/Kilala/pull/32)). This suite is the iOS counterpart and uses the same seeded accounts and error messages.

---

## Contents

1. [What is covered](#1-what-is-covered)
2. [Test files](#2-test-files)
3. [Test case catalogue](#3-test-case-catalogue)
4. [Before you run the tests](#4-before-you-run-the-tests)
5. [Running the tests](#5-running-the-tests)
6. [Manual test procedures](#6-manual-test-procedures)
7. [Latest results](#7-latest-results)
8. [Findings for the team](#8-findings-for-the-team)
9. [Limitations and out of scope](#9-limitations-and-out-of-scope)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. What is covered

Each Sprint 1 goal from the masterfile is mapped to what the iOS app can actually verify.

| Sprint 1 goal | What the iOS tests check | Test IDs |
|---|---|---|
| **Database Schema** | The app's user roles and sign-up ID types match the enums in `backend/src/schema/schema.sql`. Business categories and card statuses are checked against a copy of the agreed list kept in the test, because the app's own category list is private (see the note under SCH-03). | SCH-01 – SCH-04 |
| **PostgreSQL deployment** | The backend serves real rows from the database (seeded Makati LGU, seeded accounts). DB-01 only confirms the API process is up; it doesn't query the database. | DB-02, LIVE-01 (DB-01 supporting) |
| **CI/CD Schema** | Not testable from the app itself. The whole suite runs automatically in GitHub Actions on every PR to `dev` that changes the iOS app or the backend (§5.3). | – |
| **JWT Auth API** | The token is stored after login, sent as `Bearer`, has the agreed claims and 24-hour expiry, and is refused when missing, forged or used by the wrong role. | AUTH-01 – AUTH-06, JWT-01 – JWT-05, CH-04 |
| **Login/Signup UI** | Login, button states, error message, role-based landing screens, logout and relaunch, cardholder and business sign-up and their validation. | CH-01 – CH-07, BUS-01 – BUS-03, launch screenshots |
| *Digital ID, QR verification, discounts and transactions (Sprint 2–4 features in the MCO4 plan)* | The Digital ID shows the card's details and status; businesses verify active, unknown, revoked and expired cards; inactive accreditation is refused; the 20% discount is calculated; transactions are recorded and listed. | CH-08, BUS-04 – BUS-11 |
| **Finalize API agreements** | The app's models decode the backend's JSON, requests use the agreed paths, fields and headers, and error statuses map to the right app errors. | MOD-01 – MOD-10, AUTH-*, SIGN-01 – SIGN-08, LIVE-01 – LIVE-09 |
| *App foundation (supporting)* | The app's Info.plist allows HTTP to the local backend and declares camera access. | APP-01 – APP-03 |

### Test types

| Type | Needs backend? | Creates data? | Behaviour when backend is down |
|---|---|---|---|
| **Unit – offline** (models, schema, stubbed API) | No | No | Runs normally |
| **Unit – live** (`S1-LIVE`) | Yes | No* | Whole suite is **skipped** |
| **UI – offline** | No | No | Runs normally |
| **UI – live** | Yes | No* | Test is **skipped** |
| **Write tests** (LIVE-09, CH-08, BUS-03, BUS-04, BUS-06 – BUS-11) | Yes | **Yes** | Skipped unless `KILALA_ALLOW_WRITE_TESTS=1` |

\* Logging in updates `users.last_login_at`, and the `trg_users_updated_at` trigger also updates `users.updated_at`. Nothing else is written.

---

## 2. Test files

```
kilala-ios/
├── TESTING.md                              ← this document
└── Kilala/
    ├── KilalaTests/                         Swift Testing, runs inside the app host
    │   ├── KilalaTests.swift                S1-APP   app foundation (Info.plist)
    │   ├── ModelContractTests.swift         S1-MOD   JSON ↔ Codable models
    │   ├── SchemaContractTests.swift        S1-SCH   app enums ↔ schema.sql
    │   ├── APIServiceAuthTests.swift        S1-JWT   APIService vs stubbed backend
    │   ├── LiveBackendContractTests.swift   S1-LIVE  APIService vs real backend
    │   └── Support/
    │       ├── MockURLProtocol.swift        intercepts URLSession.shared
    │       ├── Fixtures.swift               agreed JSON payloads + seeded accounts
    │       └── LiveBackend.swift            localhost:5001 helpers, JWT decoder
    └── KilalaUITests/                       XCTest, drives the app in the simulator
        ├── CardholderAppUITests.swift       CH-01 – CH-08  (MCO4 plan, iOS Cardholder App)
        ├── BusinessAppUITests.swift         BUS-01 – BUS-11 (MCO4 plan, iOS Business App)
        ├── KilalaUITests.swift              supporting: launch smoke, LGU admin notice, launch performance
        ├── KilalaUITestsLaunchTests.swift   screenshots in light/dark, portrait/landscape
        └── Support/
            └── KilalaUITestSupport.swift    accounts, on-screen text, helpers, LGU admin setup API
```

**No production code was changed.** `APIService` uses a fixed URL and `URLSession.shared`, so the unit tests intercept `URLSession.shared` with `MockURLProtocol` instead of adding test hooks to the app. New files are picked up automatically (the project uses synchronized folders), so nothing needs to be added to the Xcode project.

Unit tests that touch the network sit under one parent suite, `NetworkTests`. Both that parent and each of its two child suites are marked `.serialized`, so these tests run one at a time. That way a stub installed by one test can never answer a request from another, and tests that share the app's stored token never overlap.

---

## 3. Test case catalogue

### 3.1 Unit tests – `KilalaTests` (Swift Testing)

#### S1-APP · App foundation – `KilalaTests.swift` (offline)

| ID | Test | Expected result |
|---|---|---|
| APP-01 | Tests run inside the Kilala app host | Host executable is `Kilala` |
| APP-02 | App Transport Security allows plain HTTP to the local backend | `NSAllowsArbitraryLoads` or `NSAllowsLocalNetworking` is true |
| APP-03 | Camera usage description is present | `NSCameraUsageDescription` exists and is not blank |

#### S1-MOD · Model contracts – `ModelContractTests.swift` (offline)

These were called API-01 – API-10 in Sprint 1. They were renamed MOD-xx because the MCO4 plan uses API-xx for the backend Postman tests.

| ID | Test | Expected result |
|---|---|---|
| MOD-01 | Login response decodes for `CARDHOLDER`, `BUSINESS`, `LGU_ADMIN` | Message, token, user id and role decoded |
| MOD-02 | `UserRole` raw values | `CARDHOLDER`, `BUSINESS`, `LGU_ADMIN` |
| MOD-03 | Unknown role (`SUPER_ADMIN`) | Decoding fails |
| MOD-04 | Login response without `token` | Decoding fails |
| MOD-05 | Non-UUID user id | Decoding fails |
| MOD-06 | LGU list with `province: null` | Decodes, province is nil |
| MOD-07 | Verify-record response without `middle_name` | Decodes, middle name is nil |
| MOD-08 | Business registration response | User, token and snake_case `businessProfile` decoded |
| MOD-09 | Cardholder profile with extra columns | Decodes and ignores unknown keys |
| MOD-10 | Full name with missing / blank / present middle name | `Maria Bautista` or `Maria Clara Bautista` |

#### S1-SCH · Database schema contracts – `SchemaContractTests.swift` (offline)

Reads `backend/src/schema/schema.sql` from the repo. Skipped if the file is not found.

| ID | Test | Expected result |
|---|---|---|
| SCH-01 | `UserRole` vs `user_role` enum | Identical sets |
| SCH-02 | Sign-up ID types vs `privilege_type` enum | `PWD`, `SENIOR_CITIZEN` |
| SCH-03 | `business_category` enum vs the sign-up category list (copy in the test) | Identical sets (see note) |
| SCH-04 | `card_status` enum contains the agreed statuses | Contains `ACTIVE`, `EXPIRED`, `REVOKED`, `SUSPENDED` |

> **Limitation of SCH-03 and SCH-04.** These tests check the **schema side** only. The `categories` list in `BusinessSignupView.swift` is `private`, so SCH-03 compares the schema with a copy of that list kept in the test. If a developer changes the list in the view, SCH-03 won't notice, and the copy must be updated by hand. Making the list readable from tests would need a small production change (see finding F-05). SCH-04 uses the agreed list of statuses; the app itself currently only checks for `ACTIVE`.

#### S1-JWT · APIService with a stubbed backend – `APIServiceAuthTests.swift` (offline)

Every error-path test also checks that the stub answered exactly one request (`assertAnsweredByStub()`). Without that check, a broken stub could let a test pass against a running real backend, because the real backend returns the same errors.

| ID | Test | Expected result |
|---|---|---|
| AUTH-01 | Login request shape | `POST http://localhost:5001/api/auth/login`, JSON body with exactly `email` and `password`, no `Authorization` header |
| AUTH-02 | Successful login | Returns the session and stores the JWT in `authToken` |
| AUTH-03 | Login gets 400 / 401 / 403 / 500 | Throws `URLError(.badServerResponse)`, no token stored |
| AUTH-04 | Login gets 200 with a body missing fields | Throws `DecodingError`, no token stored |
| AUTH-05 | Profile request | `GET /api/cardholder/me` with `Authorization: Bearer <jwt>` |
| AUTH-06 | Profile request gets 401 / 403 | Throws `URLError(.badServerResponse)` |
| SIGN-01 | Verify-record request shape | `POST /api/auth/verify-record` with the six agreed snake_case keys |
| SIGN-02 | Verify-record 400 / 404 | `APIError.badRequest` carrying the backend message |
| SIGN-03 | Verify-record 403 / 409 | `APIError.conflict` carrying the backend message |
| SIGN-04 | LGU list | `GET /api/lgus` with no `Authorization` header |
| SIGN-05 | Business registration 201 | Payload posted, response decoded, JWT stored |
| SIGN-06 | Business registration 400 | `APIError.badRequest("Missing required business registration fields")`, no token |
| SIGN-07 | Business registration 409 | `APIError.conflict("Email or Business Permit No. already exists")` |
| SIGN-08 | Business registration 500 | `APIError.serverError("Internal server error")` |

#### S1-LIVE · Real backend on localhost:5001 – `LiveBackendContractTests.swift`

The whole suite is skipped if `GET /api/health` doesn't answer.

| ID | Test | Expected result |
|---|---|---|
| DB-01 | Health endpoint | `200 {"status":"healthy","system":"Kilala Backend API"}` |
| DB-02 | LGU list from the database | Contains Makati City (`MKT`, id `1111…1111`) |
| LIVE-01 | Seeded accounts log in through `APIService` | Correct role for Juan, Maria, cashier, admin; token stored |
| LIVE-02 | Wrong password through `APIService` | Throws, no token stored |
| LIVE-03 | Login error contract | `{}` → 400, email only → 400 (`Email and password are required`); unknown user → 401 (`Invalid email or password`) |
| JWT-01 | Token structure and claims | 3 parts; `id`, `email`, `role` match the user; `exp − iat` = 86 400 s |
| JWT-02 | Cardholder token opens the profile | Juan's profile, card `MKT-PWD-2026-00481` |
| JWT-03 | Missing / malformed / forged token on `/cardholder/me` | 401 `Access token required` or 403 `Invalid or expired token` |
| JWT-04 | Valid token, wrong role | 403 `Forbidden: Insufficient permissions` (business → cardholder route, admin → cardholder route, cardholder → business route, cardholder → LGU route) |
| JWT-05 | `APIService` with a forged token | Throws |
| LIVE-04 | Verify-record with no fields | 400 `All fields are required for verification` |
| LIVE-05 | Verify-record with unknown details | `APIError.badRequest` with the no-match message |
| LIVE-06 | Verify-record for Juan's (already claimed) card | `APIError.conflict` with the already-claimed message |
| LIVE-07 | Verify-record for the unclaimed seed record | Succeeds. **Runs only once PR #32's seed (Ana Santos) is in the database.** |
| LIVE-08 | Business registration with missing fields | `APIError.badRequest`, no token |
| LIVE-09 | Register a new business, log in, then register again | Registration succeeds with a `BUSINESS` JWT, login works, duplicate → `APIError.conflict`. **Write test.** |

### 3.2 UI tests – `KilalaUITests` (XCTest)

These implement the iOS test cases of the **MCO4 Automation Test Plan** one-to-one: test method `testCH01_…` is plan case CH-01, and so on. Each test follows the plan's steps and expected results. The tests start in portrait from a cold launch on the login screen and close the app afterwards. The screenshot tests (`KilalaUITestsLaunchTests`) set no orientation, because Xcode runs them in each configuration.

**Known issues.** Some expected results in the plan describe behaviour the app on `dev` doesn't have yet (it was proposed in closed PR #41). Those checks are wrapped in `knownIssue("F-0x", …)`, which uses `XCTExpectFailure`: the failure is reported as *expected* and linked to its finding in §8, so the suite stays green while the gap stays visible. When the app is fixed, XCTest reports "expected failure but none occurred" – the signal to remove the wrapper.

**Locating elements.** The app has no accessibility identifiers yet (F-05), so the tests find elements by the text the user sees (`UIText` in `KilalaUITestSupport.swift`) and the four sign-up text fields by position. The plan's automation steps name identifiers such as `login.email`; those apply once F-05 is fixed.

#### iOS Cardholder App – `CardholderAppUITests.swift`

| ID | Test | Type | Backend | Expected result | Known issue |
|---|---|---|---|---|---|
| CH-01 | Cardholder logs in and sees their Digital ID (PWD and senior citizen) | Positive | Live | **My Kilala ID** with MAKATI CITY, full name, privilege type and card number, Status: ACTIVE and the QR image, for Juan and Maria | – |
| CH-02 | Wrong password is rejected | Negative | Live | An error is shown and the app stays on login. Plan: the message is "Invalid email or password" | F-03 (message) |
| CH-03 | Login stays disabled until email and password are entered | Negative | – | Disabled (empty) → disabled (password only) → enabled | – |
| CH-04 | Logging out or reopening the app requires signing in again | Positive | Live | Logout returns to login; after relaunch the login screen shows (the JWT is kept in memory only) | – |
| CH-05 | Sign-up requires names, card number and a past date of birth | Negative | – | Empty form → "Please fill in your first name, last name, and physical card number." Plan: date left on today → "Please select your date of birth."; future months disabled | F-06 (date checks) |
| CH-06 | Sign-up details that match no LGU record are rejected | Negative | Live | Juan's record with a blank middle name → "No matching LGU record found…"; no create-login step. Plan: plus the middle-name hint | F-02 (hint) |
| CH-07 | Cardholder verifies their LGU record and creates a login | Positive | Live | "Verified: Ana Santos!". Plan: then a create-login step, password mismatch check and the new Digital ID | F-01 (create-login step) |
| CH-08 | Revoked card shows its status on the Digital ID | Negative | Live, **write** | The LGU admin revokes Maria's card (restored afterwards); her Digital ID shows "Status: REVOKED" | – |

CH-07 stops after the known-issue check: its steps 2–3 are automated once the create-login step exists. PR #43 is building that step with an email-code (OTP) screen, so the final UI isn't settled.

#### iOS Business App – `BusinessAppUITests.swift`

QR codes are entered in the scanner's **Simulator Debug Input**, because the simulator has no camera; it runs the same verification as a camera scan.

| ID | Test | Type | Backend | Expected result | Known issue |
|---|---|---|---|---|---|
| BUS-01 | Business user logs in to the Merchant Scanner and logs out | Positive | Live | **Merchant Scanner**, then Logout returns to login | – |
| BUS-02 | Registration requires all fields, a valid email and an 8-character password | Negative | Live | Register Business disabled on an empty form and enabled once valid (not submitted). Plan: also disabled, with hints, for `not-an-email` / `short` | F-06 (email and password rules) |
| BUS-03 | Register a new business and land on the Merchant Scanner | Positive | Live, **write** | A unique `qa.ios.<random>@example.test` business is created and signed in | – |
| BUS-04 | Verify an active cardholder's QR code | Positive | Live, **write** | VERIFIED, "Valid Privilege Card", Juan Santos Dela Cruz, MKT-PWD-2026-00481 and the discount section | – |
| BUS-05 | Unrecognized QR code is flagged as invalid | Negative | Live | INVALID / REVOKED, "No Matching Cardholder Record", no Record Transaction; Dismiss returns to the scanner | – |
| BUS-06 | Revoked card is not accepted | Negative | Live, **write** | The LGU admin creates a throwaway QA card and revokes it: "Card status is REVOKED", status REVOKED, no discount | – |
| BUS-07 | Expired card is not accepted | Negative | Live, **write** | The LGU admin creates a throwaway QA card that expired yesterday: "Privilege card has expired", status EXPIRED, no discount | – |
| BUS-08 | Business with inactive accreditation cannot verify cards | Negative | Live, **write** | Mercury Drug's accreditation is turned off (restored afterwards): "Unable to verify QR code…", no result sheet | – |
| BUS-09 | 20% discount is calculated from the bill amount | Positive | Live, **write** | ₱1234.50 → -₱246.90 → ₱987.60; Record Transaction enabled (not tapped) | – |
| BUS-10 | Transaction can't be recorded without a valid bill amount | Negative | Live, **write** | Record Transaction disabled for empty, `0` and `.` | – |
| BUS-11 | Recorded transaction appears in the transaction history | Positive | Live, **write** | "Transaction Recorded" alert with the amounts; newest history row shows Juan Santos Dela Cruz, ₱987.60, Orig: ₱1234.50 | – |

Every recognised scan adds a verification log, which is why BUS-04 and BUS-09 – BUS-11 are write tests. BUS-06 and BUS-07 use throwaway cards (`MKT-PWD-QA-…`) rather than a shared record, because Xcode can run the Cardholder and Business test classes in parallel on simulator clones, and a shared card changed by one would break the other (this happened in the first run: CH-07 was skipped).

#### Supporting tests – `KilalaUITests.swift` (not in the MCO4 plan)

| Test | Backend | Expected result |
|---|---|---|
| `testAppLaunchesToLoginScreen` | – | Foreground, title and Login button visible |
| `testLGUAdminIsDirectedToWebPortal` | Live | "Please use the Kilala Web Portal for LGU Admin access."; Logout works |
| `testLaunchPerformance` | – | Records launch time (Xcode template; no pass/fail baseline set) |

#### Screenshots – `KilalaUITestsLaunchTests.swift`

Each test runs in four UI configurations: light and dark appearance, each in portrait and landscape. A screenshot is attached for each. The result summary counts each test once, not once per configuration.

| Test | Backend | Screenshot |
|---|---|---|
| `testLaunch` | – | Launch Screen (login) |
| `testLaunchCardholderSignup` | – | Cardholder Signup |
| `testLaunchCardholderDigitalID` | Live | Cardholder Digital ID (after Juan's details load) |
| `testLaunchMerchantScanner` | Live | Merchant Scanner |

---

## 4. Before you run the tests

### 4.1 Tools

| Tool | Version used | Notes |
|---|---|---|
| Xcode | **27.2** | The project targets iOS 26.4, so Xcode 26 or later is required. On this Mac, Xcode 27.2 is in `/Applications`. An older Xcode 16 is in `~/Downloads`; don't use it. |
| Simulator | iPhone 17, iOS 27.2 | Any iOS 26.4+ iPhone simulator works. Xcode 27 shows simulators in **DeviceHub**. |
| Node.js | 20.x | For the backend |
| PostgreSQL | 13+ (14 used here) | Local database for the backend; `schema.sql` requires 13+ |

### 4.2 Start the backend (needed for live tests)

The offline tests work without this step. The live tests are **skipped** (not failed) if the backend isn't running.

1. Create a local database and load the schema and seed data (one time):
   ```sh
   createdb kilala_dev
   psql -d kilala_dev -f backend/src/schema/schema.sql
   psql -d kilala_dev -f backend/src/schema/seed.sql
   ```
2. Create `backend/.env` (git ignores it) pointing at the **local** database:
   ```env
   PORT=5001
   DATABASE_URL="postgresql://<your-mac-username>@localhost:5432/kilala_dev?sslmode=disable"
   JWT_SECRET="<any long random string>"
   ```
   `sslmode=disable` is needed because `backend/src/db.ts` always requests SSL, which a local PostgreSQL doesn't offer.
3. Start the API and check it:
   ```sh
   cd backend && npm install && npm run dev
   curl http://localhost:5001/api/health   # → {"status":"healthy","system":"Kilala Backend API"}
   ```

> ⚠️ **Use a local database for testing.** The app always calls `localhost:5001`, so tests hit whatever database your backend's `.env` points to. If that's the shared Supabase database, login tests update `last_login_at` there. With the write flag on, the write tests also create businesses, QA cards, scans and transactions there, and briefly change Maria's card status and Mercury Drug's accreditation.

### 4.3 Test data

These seeded accounts are local test data only. They are the same accounts used in the masterfile and the web and Postman tests.

| Role | Email | Password |
|---|---|---|
| PWD cardholder | `juan.pwd@email.com` (card `MKT-PWD-2026-00481`, born 1998-05-14) | `MockHashForTestingOnly123456789012` |
| Senior citizen | `maria.senior@email.com` (card `MKT-OSCA-2026-08912`) | same |
| Business | `cashier@mercury-mkt.com` | same |
| LGU admin | `admin@makati.gov.ph` (used by test setup only) | same |

| Record | Details |
|---|---|
| Juan's QR token | `KILALA-QR-MKT-PWD-00481-SECRET` |
| Unclaimed QA record (in `seed.sql` on `dev`) | Ana Marie Santos, PWD, card `MKT-PWD-2026-TEST-001`, born 1999-03-17, QR token `KILALA-QR-MKT-PWD-TEST-001-SECRET` |
| Business | Mercury Drug (accredited) |

CH-08 (Maria's card status) and BUS-08 (Mercury Drug's accreditation) restore what they change in a teardown block, even when they fail. Write tests also leave behind test businesses (`qa.ios.<random>@example.test`), throwaway QA cards (`MKT-PWD-QA-…`, from BUS-06/07), verification logs and transactions. To remove them from a **local** database:
```sql
DELETE FROM verification_logs WHERE cardholder_id IN (SELECT id FROM cardholder_profiles WHERE lgu_id_number LIKE 'MKT-PWD-QA-%');
DELETE FROM cardholder_profiles WHERE lgu_id_number LIKE 'MKT-PWD-QA-%';
DELETE FROM users WHERE email LIKE 'qa.ios.%@example.test';   -- cascades to business_profiles
```
If a run was interrupted before its teardown, reset the shared QA data with:
```sql
UPDATE cardholder_profiles SET status = 'ACTIVE' WHERE lgu_id_number = 'MKT-OSCA-2026-08912';
UPDATE business_profiles SET is_accredited = TRUE WHERE business_name = 'Mercury Drug';
```

---

## 5. Running the tests

### 5.1 In Xcode

1. Open `kilala-ios/Kilala/Kilala.xcodeproj` in **Xcode 27.2**.
2. Choose the **Kilala** scheme and an **iPhone 17** simulator in the toolbar.
3. Run tests:
   - **Everything:** press **⌘U**.
   - **One suite or test:** open the Test navigator (**⌘6**) and click the ◇ diamond next to it. The same diamonds appear in the editor gutter beside each `@Test` / `func test…`.
   - **Re-run the last test:** **⌃⌥⌘G**.
4. Read the results in the Report navigator (**⌘9**) → latest **Test** run. Skipped tests show the reason, for example *"Backend not reachable on localhost:5001"*. Screenshots are under each UI test's **Attachments**.

To enable the **write tests** in Xcode: **Product → Scheme → Edit Scheme… → Test → Arguments → Environment Variables**, add `KILALA_ALLOW_WRITE_TESTS` = `1`, and uncheck **Shared** so it stays on your machine only.

### 5.2 Command line

Run these from the repository root. On this Mac, first point the command-line tools at Xcode 27.2 (once per terminal session):

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

**Everything (unit + UI):**
```sh
xcodebuild test \
  -project kilala-ios/Kilala/Kilala.xcodeproj -scheme Kilala \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO
```

**Unit tests only (fastest, no UI automation):**
```sh
xcodebuild test -project kilala-ios/Kilala/Kilala.xcodeproj -scheme Kilala \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:KilalaTests
```

**The MCO4 plan's iOS test cases only (CH and BUS):**
```sh
xcodebuild test -project kilala-ios/Kilala/Kilala.xcodeproj -scheme Kilala \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:KilalaUITests/CardholderAppUITests -only-testing:KilalaUITests/BusinessAppUITests
```

**A single test:**
```sh
# XCTest (UI):        Target/Class/method
-only-testing:KilalaUITests/BusinessAppUITests/testBUS04_VerifyActiveCardholderQRCode
# Swift Testing (unit): Target/Suite/function() – nested suites use their parent path
-only-testing:"KilalaTests/NetworkTests/LiveBackendContractTests/jwtClaims()"
```

**Including write tests:** `xcodebuild` passes variables that start with `TEST_RUNNER_` to the tests, with the prefix removed:
```sh
TEST_RUNNER_KILALA_ALLOW_WRITE_TESTS=1 xcodebuild test -project kilala-ios/Kilala/Kilala.xcodeproj \
  -scheme Kilala -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO
```

**Saving and reading a result bundle:**
```sh
xcodebuild test … -resultBundlePath build/sprint1.xcresult
xcrun xcresulttool get test-results summary --path build/sprint1.xcresult   # pass/fail/skip counts
open build/sprint1.xcresult                                                  # full report in Xcode
```

### 5.3 In CI (GitHub Actions)

`.github/workflows/ios-tests.yml` runs the **whole suite automatically** – unit and UI tests, write tests on – on every pull request to `dev` (and every push to `dev`) that changes `kilala-ios/**`, `backend/**` or the workflow itself. It can also be started by hand from the repository's **Actions** tab (*iOS Tests → Run workflow*). It is separate from `ci.yml`, so web and iOS results don't block each other.

| Step | What it does |
|---|---|
| Runner | `xcode-27` – macOS 27 with Xcode 27.2 and the iOS 27.2 iPhone 17 simulator, the same setup as §7 |
| Database | Installs PostgreSQL 16 with Homebrew, creates a throwaway `kilala_test` database and loads `schema.sql` + `seed.sql` |
| Backend | `npm ci`, `npm run build`, starts `node dist/index.js` on port 5001 and waits for `/api/health` |
| Tests | Boots the simulator, then runs `xcodebuild test` with the shared **Kilala** scheme (`Kilala.xcodeproj/xcshareddata/xcschemes/Kilala.xcscheme`), serially (`-parallel-testing-enabled NO`) for stable timing on CI machines |
| Report | Writes a pass / fail / skip / known-issue table to the run's summary page; on failure, uploads the `.xcresult` (with screenshots), the `xcodebuild` log and the backend and Postgres logs as the **ios-test-results** artifact (kept 7 days) |

A failing iOS test fails the **iOS Unit and UI Tests** check on the PR. Known issues (§3.2) are expected failures and don't fail the check. To make the check required before merging, add it to a branch protection rule for `dev` (repository Settings → Branches).

---

## 6. Manual test procedures

Use these to check by hand what the automated tests cover, for example during Sprint Review or UAT. Start the backend (§4.2) and run the app on the simulator (**⌘R**). Record the device, iOS version and a screenshot for anything that fails, following the bug report format in the masterfile.

| # | Steps | Expected result | Automated by |
|---|---|---|---|
| M-01 | Launch the app. | Login screen shows "Kilala", Email, Password (dots), Login, Create new account, Register your Business. | `testAppLaunchesToLoginScreen` |
| M-02 | Leave both fields empty. Type an email only. Then add a password. | Login is greyed out until both fields have text. | CH-03 |
| M-03 | Log in as `juan.pwd@email.com` with password `wrong`. | Red text "Invalid credentials or server offline."; stays on login. | CH-02 |
| M-04 | Log in as `juan.pwd@email.com` with the test password. | "My Kilala ID" with Juan's card `MKT-PWD-2026-00481`. Tap **Logout** → back to login. | CH-01, CH-04 |
| M-05 | Log in as `maria.senior@email.com`. | "My Kilala ID" with Maria's senior citizen card. | CH-01 |
| M-06 | Log in as `cashier@mercury-mkt.com`. | "Merchant Scanner". Tap **Logout** → back to login. | BUS-01 |
| M-07 | Log in as `admin@makati.gov.ph`. | Message to use the Kilala Web Portal, and a Logout button. | `testLGUAdminIsDirectedToWebPortal` |
| M-08 | Log in as Juan, then quit the app from the app switcher and reopen it. | Login screen; you must sign in again. | CH-04 |
| M-09 | Stop the backend (Ctrl-C in its terminal) and log in as Juan. Restart the backend afterwards. | "Invalid credentials or server offline." | Manual only |
| M-10 | Tap **Create new account**. | "Register Account" with PWD / Senior Citizen choices, name fields, card number, date of birth, Verify Record. | CH-05 |
| M-11 | Tap **Verify Record** with an empty form, then with only a first name. | "Please fill in your first name, last name, and physical card number." both times. | CH-05 |
| M-12 | Fill in Juan, Santos, Dela Cruz, `MKT-PWD-2026-00481`, born 14 May 1998, and tap **Verify Record**. | "This ID has already been claimed by an existing account." | LIVE-06 (API level) |
| M-13 | Same as M-12 but leave **Middle Name** empty. | Currently "No matching LGU record found…". See finding F-02. | CH-06 |
| M-14 | Fill in made-up details and tap **Verify Record**. | "No matching LGU record found. Please check your details." | LIVE-05 (API level) |
| M-15 | Tap **Register your Business**. | Form with Issuing LGU (Makati City (MKT) preselected), business fields, email and password. Register Business is greyed out. | BUS-02 |
| M-16 | Fill in all fields marked * with new values and tap **Register Business**. *(Creates data – local database only.)* | Signed in on "Merchant Scanner". | BUS-03, LIVE-09 |
| M-17 | Repeat M-16 with the same email or permit number. | Alert "Duplicate Registration – Email or Business Permit No. already exists". | LIVE-09 (API level) |

To check the API directly, without the app:
```sh
# Login → copy the token from the response
curl -s -X POST localhost:5001/api/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"juan.pwd@email.com","password":"MockHashForTestingOnly123456789012"}'
# Use it on a protected route (200), then try a business-only route (403)
curl -s localhost:5001/api/cardholder/me -H "Authorization: Bearer <token>"
curl -s localhost:5001/api/business/me   -H "Authorization: Bearer <token>"
```

---

## 7. Latest results

All runs used Xcode 27.2, the iPhone 17 simulator (iOS 27.2) and a local backend on a local PostgreSQL database loaded with `schema.sql` + `seed.sql`. For runs A and B, PR #32's unclaimed record (Ana Santos) was also added to the **local** database so that LIVE-07 could run.

> **How results are counted:** the result summary counts each test **function** once. Cases of a parameterized test (for example AUTH-03's four status codes) and the four configurations of each screenshot test are not counted separately. That gives 47 unit tests and 22 UI tests, 69 in total.

**Run D – MCO4 plan tests (branch `test/app/automation-plan`), everything, write tests on: all 73 tests ran as expected.** 20 Nov 2026, Xcode's default parallel testing (simulator clones).
```sh
TEST_RUNNER_KILALA_ALLOW_WRITE_TESTS=1 xcodebuild test -project kilala-ios/Kilala/Kilala.xcodeproj \
  -scheme Kilala -destination 'platform=iOS Simulator,name=iPhone 17'
```

| Group | Passed | Known issue (expected failure) | Failed |
|---|---|---|---|
| `KilalaTests` (unit) | 47 | – | 0 |
| CH-01 – CH-08 | 4 (CH-01, CH-03, CH-04, CH-08) | 4 (CH-02 F-03, CH-05 F-06, CH-06 F-02, CH-07 F-01) | 0 |
| BUS-01 – BUS-11 | 10 | 1 (BUS-02 F-06) | 0 |
| Supporting UI tests and launch screenshots | 7 | – | 0 |
| **Total** | **68** | **5** | **0** |

Xcode also reported one extra error: a spare UI test runner clone crashed "while preparing to run tests" (`XCTWaiter … handleStalledWait`). It ran no tests, and every test above has its own result; it's a simulator-load problem, so re-run if you see it. Earlier runs on this branch found two test-side problems that are now fixed in the helpers: CH-07 was skipped because BUS-06/07 changed the shared QA card in parallel (they now use throwaway cards), and taps on fields right after launch or on Form rows not yet laid out were lost (`focus` and `scrollIntoView`). The test data was cleaned afterwards with the SQL in §4.3.

Runs A – C below are the Sprint 1 runs and use that suite's test IDs (UI-xx for UI tests, API-xx for what are now MOD-xx).

**Run A – everything, write tests on: passed, 69 / 69, nothing skipped.**
```sh
TEST_RUNNER_KILALA_ALLOW_WRITE_TESTS=1 xcodebuild test -project kilala-ios/Kilala/Kilala.xcodeproj \
  -scheme Kilala -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO
```

| Target | Passed | Failed | Skipped |
|---|---|---|---|
| KilalaTests (unit) | 47 | 0 | 0 |
| KilalaUITests (UI) | 22 | 0 | 0 |
| **Total** | **69** | **0** | **0** |

Took about 7½ minutes, including the launch performance test (average **2.58 s** over 5 launches; no baseline). The two test businesses created by LIVE-09 and UI-15 were deleted afterwards with the cleanup SQL in §4.3.

**Run C – recheck after the final fixes: passed, 53 / 53.** The final fixes made the unit-test serialization explicit and added a check that the keyboard closes. This run covered all of `KilalaTests` plus `SignupUITests`, with write tests on. The log confirms the software keyboard was on screen and closed when Return was typed. The test businesses were deleted afterwards. Run A's other UI tests weren't affected by these fixes and weren't rerun.

**Run B – default settings (no write flag): passed, 46 passed, 2 skipped.** Covered all of `KilalaTests` plus UI-15. As designed, LIVE-09 and UI-15 were skipped with the message *"Set … KILALA_ALLOW_WRITE_TESTS=1 to run tests that create data"*. No accounts or businesses were created. The only database writes were login timestamps (`users.last_login_at` and, through the trigger, `users.updated_at`).

**Earlier run, before the review fixes and before PR #32's record was added: 66 passed, 3 skipped.** LIVE-07 also skipped, with *"Unclaimed seed record (PR #32) not present in this database"*. On a fresh database built from the current `seed.sql`, expect this result.

---

## 8. Findings for the team

These issues came up while designing the tests. **None are fixed in this branch**, because the branch only adds tests. F-01, F-02, F-03 and F-06 are tracked by known-issue checks in the MCO4 tests (CH-07, CH-06, CH-02, CH-05 and BUS-02; see §3.2), which will report when the app is fixed. Priorities use the masterfile definitions: **High** breaks a core feature or exposes user data, **Medium** works but not correctly, **Low** is minor.

| ID | Area | Finding | Suggested priority |
|---|---|---|---|
| F-01 | Cardholder sign-up | Sign-up stops after **Verify Record**. The app shows "Verified: …" but never asks for an email or password, and never calls `POST /api/auth/claim-cardholder`. A PWD or senior citizen therefore can't create an account in the app, even though "Login/Signup UI" is ticked in the masterfile. | High – confirm with the PO whether the claim step is planned for a later sprint |
| F-02 | Cardholder sign-up | Leaving **Middle Name** empty fails with "No matching LGU record found" whenever the LGU record has a middle name. The backend compares `COALESCE(middle_name,'') ILIKE ''`. Confirmed with Juan's record. The field isn't marked as required. | Medium |
| F-03 | Login | All failures (wrong password, server down, 500) show the same message, "Invalid credentials or server offline.", because `APIService.login` turns every non-2xx response into the same `URLError`. Users can't tell a typo from an outage. | Low |
| F-04 | Security | `Info.plist` sets `NSAllowsArbitraryLoads = true`, which allows plain HTTP to **every** server, not just the local backend. `NSAllowsLocalNetworking` is enough for development, and release builds should use HTTPS. APP-02 accepts either setting, so tightening it won't break the test. | Low (hardening) |
| F-05 | Testability | The views have no `accessibilityIdentifier`s. The UI tests find elements by visible text (collected in `UIText` in `KilalaUITestSupport.swift`), and find the cardholder sign-up fields by position because they have empty placeholders. Adding identifiers would make the tests resistant to copy changes. Likewise, the category list in `BusinessSignupView` is `private`, so SCH-03 has to compare against a copy; making it `internal` (or moving it to a shared model) would let the test read the real list. | Low |
| F-06 | Sign-up UX | The date of birth picker defaults to today and accepts future dates. Business sign-up has no password rules and no client-side email format check. | Low |
| F-07 | CI/CD | **Addressed in branch `chore/ci/ios-tests`:** a shared scheme and `.github/workflows/ios-tests.yml` (§5.3). Original finding: `.github/workflows/ci.yml` has no iOS job, and the project has no **shared** Xcode scheme (`xcshareddata`). `xcodebuild` currently relies on an auto-generated scheme. Ops would need a macOS runner and a shared scheme for iOS tests to run in CI. | Ops backlog |
| F-08 | Backend (for Ops) | If `JWT_SECRET` is missing, the backend falls back to a hard-coded secret, and the masterfile contains the live database password and JWT secret in plain text. Change both and keep them out of shared documents. | High (security, backend/Ops) |
| F-09 | API agreement | The `POST /api/auth/verify-record` handler tries to include `middle_name` in its response, but the SQL query doesn't select that column, so the key is always absent from the JSON. The app handles this (API-07), but the response doesn't contain what the code intends. | Low |
| F-10 | Repository | The `.gitignore` rule `*.xcodeproj/*` contains a slash, so git applies it only at the repo root, never to `kilala-ios/Kilala/Kilala.xcodeproj`. Personal Xcode files (`xcuserdata/`) aren't ignored; one developer's are already committed. A rule such as `**/*.xcodeproj/xcuserdata/` would fix it. This branch doesn't commit any `xcuserdata`. | Low |
| F-11 | Backend (for Ops) | `POST /api/auth/login` skips the bcrypt check when a user's stored hash equals the seed placeholder, and accepts the placeholder text itself as the password. All four seeded accounts use it, **including the LGU admin**, and that password is published in `seed.sql`, the masterfile and this document. On any database where `seed.sql` was loaded, such as the shared Supabase database per the masterfile, anyone who reads the repo can sign in as the LGU admin and read cardholder records through `/api/lgu/cardholders`. This is acceptable for throwaway test data only. Remove the shortcut, or limit it to test environments, before any real data is stored. | High (security, backend/Ops) |
| F-12 | Backend (privacy) | `POST /api/auth/verify-record` passes the name fields to `ILIKE` without escaping. Anyone who knows a card number and date of birth can send `%` as the names and receive the cardholder's first and last name (confirmed on the local database with the PR #32 seed record). The different 404 / 403 / 409 responses also reveal whether a record exists and whether it's claimed or inactive. | Medium (privacy, backend) |

---

## 9. Limitations and out of scope

- **CI/CD Schema** and **PostgreSQL deployment** are infrastructure goals. The iOS suite only checks them indirectly, by talking to a running backend and database.
- **QR verification, card status, discounts and transaction history** are covered by BUS-04 – BUS-11 and CH-08. The QR code is entered through the scanner's Simulator Debug Input, not scanned.
- The **camera** isn't available in the simulator, so the scanner's camera path can't be UI-tested there.
- **LIVE-07** and **CH-07** need the unclaimed QA record (in `seed.sql` on `dev`). They are skipped if it is missing or already claimed.
- **Token expiry** after 24 hours isn't simulated in the app. JWT-01 checks the expiry claim, and JWT-03 checks that the backend rejects invalid tokens.
- `testLaunchPerformance` is the Xcode template's measurement. It has no baseline, so it never fails. Each launch takes about 2.6 s (§7), but the test launches and closes the app several times, so it adds about 40 seconds to a full run.
- CH-06 and CH-07 set the date of birth through the picker's month and year wheels (`setDateOfBirth`). This relies on the system picker's accessibility labels ("DatePicker.Show", "March 17"), so an iOS update could require changing the helper.
- iOS's "Save Password?" prompt can appear a few seconds after login and swallow the next tap. `logOut` and `verifyQR` dismiss it and retry; if a UI test fails on a tap right after login, check the failure screenshot for this prompt first.
- **Known issues** (CH-02, CH-05, CH-06, CH-07, BUS-02) are reported as expected failures until the app is fixed; see §3.2.

---

## 10. Troubleshooting

| Problem | Fix |
|---|---|
| Live tests show as **skipped** | The backend isn't running or isn't healthy. Start it (§4.2) and check `curl localhost:5001/api/health`. |
| `xcodebuild` says the deployment target 26.4 is unsupported | You're using Xcode 16. Run `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, or in Xcode use **Settings → Locations → Command Line Tools**. |
| The Simulator window doesn't appear or crashes | Xcode 27 shows simulators in **DeviceHub** (`/Applications/Xcode.app/Contents/Applications/DeviceHub.app`). Don't open the Simulator app from the Xcode 16 copy in `~/Downloads`; it crashes on this macOS. |
| UI tests can't type into fields | In the simulator, turn off **I/O → Keyboard → Connect Hardware Keyboard** so the software keyboard appears. |
| A "Save Password?" sheet blocks a test | The tests dismiss it automatically (`dismissSavePasswordPromptIfShown`). If it persists, turn off AutoFill Passwords in the simulator's Settings → Passwords → Password Options. |
| A UI test fails after a text change in the app | Update the matching string in `UIText` (`KilalaUITests/Support/KilalaUITestSupport.swift`). |
| Contract tests fail after a backend change | The API agreement changed. Update `Fixtures.swift` only if the team agreed to the change; otherwise report it as a bug. |
| `SchemaContractTests` are skipped | The test couldn't find `backend/src/schema/schema.sql`. Run from a full clone of the monorepo. |
| Login tests fail with 500 errors | Check the backend terminal. `sslmode=disable` is usually missing from `DATABASE_URL` for a local database. |
