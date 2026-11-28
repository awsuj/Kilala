# Kilala iOS – QA Test Suite (Sprint 1 and MCO4 Automation Test Plan)

| | |
|---|---|
| **Scope** | Sprint 1 – Foundation, Contracts & Auth, plus the iOS test cases of the MCO4 Automation Test Plan (CH – iOS Cardholder App, BUS – iOS Business App) |
| **Author** | Edson John Willie (QA / iOS Developer) |
| **Branch** | `test/app/automation-plan` (Sprint 1 suite: `test/app/sprint-1`, merged in PR #38) |
| **Targets** | `KilalaTests` (Swift Testing) · `KilalaUITests` (XCTest / XCUIAutomation) |
| **Last run** | 26 Nov 2026 · Xcode 27.2 · iPhone 17 simulator (iOS 27.2) · see [§7](#7-latest-results) |

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
| **Write tests** (LIVE-09, CH-08, BUS-02 – BUS-04, BUS-06 – BUS-11) | Yes | **Yes** | Skipped unless `KILALA_ALLOW_WRITE_TESTS=1` |

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
        ├── CardholderDashboardUITests.swift supporting: cardholder dashboard tabs and QR privacy cover (PR #53)
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

**Locating elements.** The app has no accessibility identifiers yet (F-05), so the tests find elements by the text the user sees (`UIText` in `KilalaUITestSupport.swift`): buttons and labels by their text, and text fields by their placeholder (for example `name@example.com` on the login screen, or `e.g., Juan` on cardholder sign-up). The plan's automation steps name identifiers such as `login.email`; those apply once F-05 is fixed. Because of this, **renaming a button or placeholder breaks the tests** even when the app works – the PR #58 and PR #67 redesigns broke most UI tests that way (§7, Run G).

#### iOS Cardholder App – `CardholderAppUITests.swift`

| ID | Test | Type | Backend | Expected result | Known issue |
|---|---|---|---|---|---|
| CH-01 | Cardholder logs in and sees their Digital ID (PWD and senior citizen) | Positive | Live | **My Kilala ID** with MAKATI CITY, the **masked** name (`J*** S. D*** C***`), privilege type, card number, Status: ACTIVE and the QR image; tapping the QR code shows the name (`Juan S. Dela Cruz` – middle initial since PR #67). For Juan and Maria | – |
| CH-02 | Wrong password is rejected | Negative | Live | An error is shown and the app stays on login. Plan: the message is "Invalid email or password" | F-03 (message) |
| CH-03 | Login stays disabled until email and password are entered | Negative | – | Disabled (empty) → disabled (password only) → enabled | – |
| CH-04 | Logging out or reopening the app requires signing in again | Positive | Live | Log Out (Profile tab, since PR #67) returns to login; after relaunch the login screen shows (the JWT is kept in memory only) | – |
| CH-05 | Sign-up requires names, card number and a past date of birth | Negative | – | Empty form → "Please fill in your first name, last name, and physical card number." Plan: date left on today → "Please select your date of birth."; future months disabled | F-06 (date checks) |
| CH-06 | Sign-up details that match no LGU record are rejected | Negative | Live | Juan's record with a blank middle name → "No matching LGU record found…"; no create-login step. Plan: plus the middle-name hint | F-02 (hint) |
| CH-07 | Cardholder verifies their LGU record and creates a login | Positive | Live | "Record Found!" with Ana's name; **Proceed** opens the create-login step (email, password, confirm password, "Send OTP to email"), where **Create Account** stays disabled until the email is verified | – |
| CH-08 | Revoked card shows its status on the Digital ID | Negative | Live, **write** | The LGU admin revokes Maria's card (restored afterwards); her Digital ID shows "Status: REVOKED" | – |

Since PR #43 the create-login step exists (finding F-01 is addressed), with an email-code (OTP) screen before **Create Account** can be used. The code is emailed, and a UI test can't read it, so CH-07 stops at the create-login screen. The rest of the plan's steps (the email code, "Passwords do not match." and Ana's new Digital ID) are manual check M-19 (§6). CH-07 claims nothing, so it can run again without resetting the QA record.

#### iOS Business App – `BusinessAppUITests.swift`

Since PR #58 a business lands on its dashboard (**Home** tab, "NET SALES COLLECTED"), with **Transactions** and **Profile** tabs at the bottom. The floating **Scan QR** button opens the Merchant Scanner full screen; **Close** returns to the tab. The transaction history is the Transactions tab, and a business logs out from the bottom of its Profile tab. QR codes are entered in the scanner's **Simulator Debug Input**, because the simulator has no camera; it runs the same verification as a camera scan.

Since PR #64 a business can't register from scratch: its LGU first adds it as an accredited business (web portal, PR #61), and the owner then **claims** it in the app. Step 1 (*Verify Your Business*) matches the business name, Issuing LGU, permit number and TIN; step 2 asks for the address, email and a password that meets the rules (8+ characters, an uppercase letter, a number and a special character); **Continue to Verification** then emails a code (OTP). BUS-02 and BUS-03 have the LGU admin create a throwaway unclaimed business (`QA Business …`) through `POST /api/lgu/businesses` and stop before the code is sent; the rest is manual check M-20.

| ID | Test | Type | Backend | Expected result | Known issue |
|---|---|---|---|---|---|
| BUS-01 | Business user logs in to the Merchant Scanner and logs out | Positive | Live | Business dashboard; **Scan QR** opens the scanner (QR input ready); **Close** returns to the dashboard; **Log Out** (Profile tab) returns to login | – |
| BUS-02 | Registration requires all fields, a valid email and an 8-character password | Negative | Live, **write** | Step 1: Verify Business disabled on an empty form; a wrong TIN → "No matching accredited business record found…"; Mercury Drug's details → "…already been claimed…". Step 2: Continue disabled while empty, with a short password, and with a mismatched confirmation ("Passwords do not match."); with matching passwords it is enabled, and `not-an-email` → "Please enter a valid email address." | – |
| BUS-03 | Register a new business and land on the Merchant Scanner | Positive | Live, **write** | The QA business is verified ("Accredited record found" with its name); with valid account details **Continue to Verification** is enabled (not tapped – it emails a code; manual check M-20) | – |
| BUS-04 | Verify an active cardholder's QR code | Positive | Live, **write** | VERIFIED, "Valid Privilege Card", Juan Santos Dela Cruz, MKT-PWD-2026-00481 and the discount section | – |
| BUS-05 | Unrecognized QR code is flagged as invalid | Negative | Live | NOT RECOGNIZED, "No Matching Cardholder Record", no Record Transaction; Dismiss returns to the scanner | – |
| BUS-06 | Revoked card is not accepted | Negative | Live, **write** | The LGU admin creates a throwaway QA card and revokes it: "Card status is REVOKED", status REVOKED, no discount | – |
| BUS-07 | Expired card is not accepted | Negative | Live, **write** | The LGU admin creates a throwaway QA card that expired yesterday: "Privilege card has expired" and EXPIRED (its own status since PR #58), not VERIFIED, no discount | – |
| BUS-08 | Business with inactive accreditation cannot verify cards | Negative | Live, **write** | Mercury Drug's accreditation is turned off (restored afterwards): "Unable to verify QR code…", no result sheet | – |
| BUS-09 | 20% discount is calculated from the bill amount | Positive | Live, **write** | ₱1234.50 → -₱246.90 → ₱987.60; Record Transaction enabled (not tapped) | – |
| BUS-10 | Transaction can't be recorded without a valid bill amount | Negative | Live, **write** | Record Transaction disabled for empty, `0` and `.` | – |
| BUS-11 | Recorded transaction appears in the transaction history | Positive | Live, **write** | "Transaction Recorded" alert with the amounts; on the Transactions tab the newest row is Juan Santos Dela Cruz, ₱987.60, From ₱1234.50, at the current time | – |

Every recognised scan adds a verification log, which is why BUS-04 and BUS-09 – BUS-11 are write tests. BUS-02 and BUS-03 pick **Makati City (MKT)** explicitly, because the LGU menu preselects the first city (F-17). Business sign-up has no way to close the keyboard (Return moves to the next field), so these two tests tap from field to field and send step 1 with the keyboard's **Go** key on the TIN field, which runs the same verification as the Verify Business button. On an empty password field iOS shows a "Use Strong Password?" panel instead of the keyboard; the `focus` helper closes it so the test's own password is typed. BUS-06 and BUS-07 use throwaway cards (`MKT-PWD-QA-…`) rather than a shared record, because Xcode can run the Cardholder and Business test classes in parallel on simulator clones, and a shared card changed by one would break the other (this happened in the first run: CH-07 was skipped).

#### Supporting tests – `KilalaUITests.swift` (not in the MCO4 plan)

| Test | Backend | Expected result |
|---|---|---|
| `testAppLaunchesToLoginScreen` | – | Foreground, title and Sign In button visible |
| `testLGUAdminIsDirectedToWebPortal` | Live | "Please use the Kilala Web Portal for LGU Admin access."; Logout works |
| `testLaunchPerformance` | – | Records launch time (Xcode template; no pass/fail baseline set) |

#### Cardholder dashboard – `CardholderDashboardUITests.swift` (not in the MCO4 plan)

Since PR #53 a cardholder lands on a dashboard with **Home**, **Transactions** and **Profile** tabs. Home shows the Digital ID with the QR code behind a privacy cover. All three tests log in as Juan and only read data.

| Test | Backend | Expected result |
|---|---|---|
| `testDashboardShowsThreeTabsAndOpensOnHome` | Live | Home, Transactions and Profile tabs; Home is selected |
| `testQRCodeIsHiddenUntilTapped` | Live | "QR code is hidden for your privacy" on arrival; a tap shows the code ("Tap or swipe QR code to hide") and the name; a second tap hides it and masks the name again |
| `testSwipeShowsQRCodeAndLeavingHomeHidesIt` | Live | A swipe shows the code; after switching to Transactions and back to Home it is hidden again |

The privacy cover is faded out, not removed, so it stays in the accessibility tree; the tests tell shown from hidden by the caption under the code. Since PRs #58 and #67 the tabs are the app's own bar (plain buttons), not a system tab bar, and "My Kilala ID" is a heading rather than a navigation bar; cardholders log out from the Profile tab. Cardholder sign-up (restyled in PR #67) moves to the next field on Return and closes the keyboard only after the card number, so CH-05 – CH-07 fill the fields in order. The Transactions and Profile tabs were filled in by PRs #60 and #62; they aren't automated yet (manual checks M-21 – M-23).

#### Screenshots – `KilalaUITestsLaunchTests.swift`

Each test runs in four UI configurations: light and dark appearance, each in portrait and landscape. A screenshot is attached for each. The result summary counts each test once, not once per configuration.

| Test | Backend | Screenshot |
|---|---|---|
| `testLaunch` | – | Launch Screen (login) |
| `testLaunchCardholderSignup` | – | Cardholder Signup |
| `testLaunchCardholderDigitalID` | Live | Cardholder Digital ID (after Juan's details load) |
| `testLaunchMerchantScanner` | Live | Business dashboard, Home tab (after a business login) |

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
| Business | Mercury Drug (accredited, claimed by `cashier@mercury-mkt.com`), permit `MKT-BP-2026-99102`, TIN `000-123-456-001` |
| LGUs | The 17 Metro Manila cities (in `seed.sql` since PR #44, so CI has them). A local database loaded before PR #44 only has Makati; add the rest with `psql -d kilala_dev -f backend/src/schema/ncr-lgus-seed.sql` (safe to re-run) |

CH-08 (Maria's card status) and BUS-08 (Mercury Drug's accreditation) restore what they change in a teardown block, even when they fail. Write tests also leave behind unclaimed QA businesses (`QA Business …`, from BUS-02/03, each with a locked placeholder user `unclaimed-…@unclaimed.kilala`), throwaway QA cards (`MKT-PWD-QA-…`, from BUS-06/07), verification logs and transactions. Older runs also left test businesses with `qa.ios.<random>@example.test` logins. To remove them from a **local** database (the business rows are deleted explicitly, because since PR #64 `schema.sql` no longer deletes a business with its user):
```sql
DELETE FROM verification_logs WHERE cardholder_id IN (SELECT id FROM cardholder_profiles WHERE lgu_id_number LIKE 'MKT-PWD-QA-%');
DELETE FROM cardholder_profiles WHERE lgu_id_number LIKE 'MKT-PWD-QA-%';
DELETE FROM users WHERE id IN (SELECT user_id FROM business_profiles WHERE business_name LIKE 'QA Business %');
DELETE FROM business_profiles WHERE business_name LIKE 'QA Business %';
DELETE FROM business_profiles WHERE user_id IN (SELECT id FROM users WHERE email LIKE 'qa.ios.%@example.test');
DELETE FROM users WHERE email LIKE 'qa.ios.%@example.test';
DELETE FROM otp_verifications WHERE email LIKE 'qa.ios.%@example.test';
```
If a run was interrupted before its teardown, reset the shared QA data with:
```sql
UPDATE cardholder_profiles SET status = 'ACTIVE' WHERE lgu_id_number = 'MKT-OSCA-2026-08912';
UPDATE business_profiles SET is_accredited = TRUE WHERE business_name = 'Mercury Drug';
```
If a manual check changed a seeded account's password (M-22), the automated tests can't log in with it. Put the test password back with:
```sql
UPDATE users SET password_hash = '$2b$10$MockHashForTestingOnly123456789012' WHERE email = 'maria.senior@email.com';
```
If Ana's QA record was claimed (by manual check M-19 or LIVE-07), CH-07 and LIVE-07 are skipped. Unclaim it by deleting the account that claimed it; the profile's `user_id` is set back to NULL:
```sql
DELETE FROM users WHERE id = (SELECT user_id FROM cardholder_profiles WHERE lgu_id_number = 'MKT-PWD-2026-TEST-001');
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

`.github/workflows/ios-tests.yml` runs in three ways. It is separate from `ci.yml`, so web and iOS results don't block each other.

| Trigger | What runs |
|---|---|
| Pull request to `dev`, or push to `dev`, that changes `kilala-ios/**`, `backend/**` or the workflow | **Unit tests only** (`KilalaTests`, about a minute of testing) – since PR #52 |
| **Nightly** at 18:00 UTC (02:00 Philippine time) | The whole suite – unit and UI tests, write tests on. GitHub runs scheduled workflows from the **default branch (`main`)**, so the nightly run tests `main`'s code, not `dev`'s; it started running once the workflow reached `main` (PR #56) |
| By hand: **Actions** tab → *iOS Tests* → *Run workflow* | Pick `all`, `unit_only` or `ui_only`, on any branch |

Because PRs run unit tests only, a PR that renames screen text can pass CI and still break the UI tests (this happened with PR #58). Run the UI tests by hand (*Run workflow* → `ui_only` on the PR's branch, or locally, §5.2) for PRs that change screens. Failed tests are retried up to 3 times (`-retry-tests-on-failure -test-iterations 3`).

| Step | What it does |
|---|---|
| Runner | `xcode-27` – macOS 27 with Xcode 27.2 and the iOS 27.2 iPhone 17 simulator, the same setup as §7 |
| Database | Installs PostgreSQL 16 with Homebrew, creates a throwaway `kilala_test` database and loads `schema.sql` + `seed.sql` |
| Backend | `npm ci`, `npm run build`, starts `node dist/index.js` on port 5001 and waits for `/api/health` |
| Tests | Boots the simulator, then runs `xcodebuild test` with the shared **Kilala** scheme (`Kilala.xcodeproj/xcshareddata/xcschemes/Kilala.xcscheme`), serially (`-parallel-testing-enabled NO`) for stable timing on CI machines |
| Report | Writes a pass / fail / skip / known-issue table to the run's summary page; on failure, uploads the `.xcresult` (with screenshots), the `xcodebuild` log and the backend and Postgres logs as the **ios-test-results** artifact (kept 7 days) |

A failing iOS test fails the **iOS Unit and UI Tests** check (on a PR, a unit test). Known issues (§3.2) are expected failures and don't fail the check. To make the check required before merging, add it to a branch protection rule for `dev` (repository Settings → Branches).

---

## 6. Manual test procedures

Use these to check by hand what the automated tests cover, for example during Sprint Review or UAT. Start the backend (§4.2) and run the app on the simulator (**⌘R**). Record the device, iOS version and a screenshot for anything that fails, following the bug report format in the masterfile.

| # | Steps | Expected result | Automated by |
|---|---|---|---|
| M-01 | Launch the app. | "Sign in to Kilala" with Email (`name@example.com`), Password, **Sign In**, and under "New to Kilala?" **Register a Business** and **Claim Cardholder ID**. | `testAppLaunchesToLoginScreen` |
| M-02 | Leave both fields empty. Type an email only. Then add a password. | Sign In is greyed out until both fields have text. | CH-03 |
| M-03 | Log in as `juan.pwd@email.com` with password `wrong`. | Red text "Invalid credentials or server offline."; stays on login. | CH-02 |
| M-04 | Log in as `juan.pwd@email.com` with the test password. | "My Kilala ID" with the name masked (`J*** S. D*** C***`), the card number blurred, and Home / Transactions / Profile tabs. Tap the QR code → `Juan S. Dela Cruz` and card number `MKT-PWD-2026-00481` show. **Profile → Log Out** → back to login. | CH-01, CH-04 |
| M-05 | Log in as `maria.senior@email.com`. | "My Kilala ID" with Maria's senior citizen card. | CH-01 |
| M-06 | Log in as `cashier@mercury-mkt.com`. Tap **Scan QR**, then **Close**. Open **Profile** and tap **Log Out**. | Dashboard ("Mercury Drug · Makati City", Accredited, NET SALES COLLECTED, Recent Activity); Scan QR opens the scanner full screen; Log Out returns to login. | BUS-01 |
| M-07 | Log in as `admin@makati.gov.ph`. | Message to use the Kilala Web Portal, and a Logout button. | `testLGUAdminIsDirectedToWebPortal` |
| M-08 | Log in as Juan, then quit the app from the app switcher and reopen it. | Login screen; you must sign in again. | CH-04 |
| M-09 | Stop the backend (Ctrl-C in its terminal) and log in as Juan. Restart the backend afterwards. | "Invalid credentials or server offline." | Manual only |
| M-10 | Tap **Claim Cardholder ID**. | "Register Account" with PWD / Senior Citizen choices, name fields, card number, date of birth, Verify Record. | CH-05 |
| M-11 | Tap **Verify Record** with an empty form, then with only a first name. | "Please fill in your first name, last name, and physical card number." both times. | CH-05 |
| M-12 | Fill in Juan, Santos, Dela Cruz, `MKT-PWD-2026-00481`, born 14 May 1998, and tap **Verify Record**. | "This ID has already been claimed by an existing account." | LIVE-06 (API level) |
| M-13 | Same as M-12 but leave **Middle Name** empty. | Currently "No matching LGU record found…". See finding F-02. | CH-06 |
| M-14 | Fill in made-up details and tap **Verify Record**. | "No matching LGU record found. Please check your details." | LIVE-05 (API level) |
| M-15 | Tap **Register a Business**. | "Step 1 of 2 · Verify Accreditation": Business Name, Issuing LGU (the first city in the list is preselected – F-17), Business Permit Number, TIN. **Verify Business** is greyed out. | BUS-02 |
| M-16 | Fill in made-up details and tap **Verify Business**. Then use Mercury Drug's details (`Mercury Drug`, Makati City, `MKT-BP-2026-99102`, `000-123-456-001`). | "No matching accredited business record found. Please check your details."; then "This business record has already been claimed by an existing account." | BUS-02 |
| M-17 | Call `POST /api/auth/register-business` directly (Postman). | Today it still creates an **accredited** business without the LGU's record – finding F-18. | LIVE-09 (API level) |
| M-18 | Log in as Juan. Tap the QR code, tap it again, swipe it, then switch to **Transactions** and back to **Home**. | The code starts blurred ("QR code is hidden for your privacy"); a tap shows it, the next tap hides it, a swipe shows it, and returning to Home hides it again. | `CardholderDashboardUITests` |
| M-19 | **Claim Cardholder ID** → PWD → Ana / Marie / Santos, `MKT-PWD-2026-TEST-001`, 17 March 1999 → **Verify Record** → **Proceed**. Enter an email you can read and tap **Send OTP to email**; enter the 6-digit code. Back on the form, enter a valid password and a different confirmation, tap **Create Account**; then fix the confirmation and tap it again. *(Claims the QA record and needs the backend's email settings (F-15) – local database only; reset Ana afterwards with the SQL in §4.3.)* | "Record Found!", then the create-login form ("Create Your Account"). After the code, the email shows **Verified** and Create Account is enabled. A mismatch shows "Passwords do not match."; then you land on "My Kilala ID" for Ana. | CH-07 (up to the create-login form) |
| M-20 | Have the LGU admin add a business in the web portal (**Businesses → Add Business**, PR #61). In the app: **Register a Business** → pick its LGU and enter its name, permit number and TIN → **Verify Business**. Fill in the address, an email you can read and a valid password twice → **Continue to Verification** → enter the 6-digit code → **Complete Registration**. *(Creates data and needs the backend's email settings (F-15) – local database only.)* | "Accredited record found" with the business's name and permit; after the code, you are signed in on the business dashboard. Signing in again with the new email works. | BUS-03 (up to Continue to Verification) |
| M-21 | Log in as Juan → **Transactions**. Search for `Mercury`, set a date range and tap **Apply Filter**, then **Reset Filter**. Tap a transaction. | His purchases, newest first; the search and date filter narrow the list; Transaction Details shows the merchant, branch, "20% Discount Granted" and the Net Total. | Manual only |
| M-22 | Log in as Maria → **Profile**. Tap **Update details**, change the emergency contact, **Save Changes**. Then **Change password**: a wrong current password, then a correct one with a new password that meets the rules. *(Changes Maria's password – reset it afterwards with the SQL in §4.3.)* | Card details (name, privilege type, LGU, dates, address, email); the contact is saved; the wrong password is refused; the new one works at the next login. | Manual only |
| M-23 | Log in as the business → **Transactions** (search by name or ID number, date filter, tap a row) and **Profile** (**Update details**). | Rows show the cardholder, time, net amount and original amount; details show the card number and the 20% discount; profile changes are saved. | BUS-11 (newest row only) |

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

**Run G – after the app redesign (PRs #58 – #60, #62, #67) and the business claim flow (PR #64), branch `test/app/redesign-and-business-claim`, everything, write tests on: passed – 73 passed, 3 known issues, 0 failed, 0 skipped (76 tests).** 26 Nov 2026, one test at a time, about 17 minutes, local database with the 17 Metro Manila LGUs. Before this branch, the nightly runs of 25 and 26 Nov failed: all 47 unit tests passed, but 26 UI tests failed at their first step because PR #58 renamed the login screen's texts ("Login" → "Sign In", "Create new account" → "Claim Cardholder ID", "Register your Business" → "Register a Business") and replaced the scanner drawer. None of those were app bugs. PR #67 then restyled the cardholder screens while this branch was in progress. This branch updates the tests for the new screens: the login placeholders, the business tabs and full-screen scanner, Log Out on the Profile tab, the masked cardholder name (PR #59) and its middle initial (PR #67), the cardholder sign-up placeholders and field order (PR #67), the NOT RECOGNIZED and EXPIRED results, the Transactions tab as the history, and the new business claim flow (BUS-02, BUS-03). BUS-02's F-06 known issue was removed, because PR #64 added the email and password checks. The test data was cleaned afterwards with the SQL in §4.3.

| Group | Passed | Known issue (expected failure) | Failed |
|---|---|---|---|
| `KilalaTests` (unit) | 47 | – | 0 |
| CH-01 – CH-08 | 5 | 3 (CH-02, CH-05, CH-06) | 0 |
| BUS-01 – BUS-11 | 11 | – | 0 |
| Cardholder dashboard, supporting UI tests and launch screenshots | 10 | – | 0 |
| **Total** | **73** | **3** | **0** |

**Run F – after PRs #43 (create-login step) and #53 (cardholder dashboard), branch `test/app/signup-dashboard-tests`, everything, write tests on: passed – 72 passed, 4 known issues, 0 failed, 0 skipped (76 tests).** 22 Nov 2026, one test at a time (`-parallel-testing-enabled NO`), about 15 minutes. This run checks CH-07's new create-login flow, the three new cardholder dashboard tests, and the QR helper that now checks the typed token (BUS-05 had once tapped Verify with an empty field). The known issues are CH-02 (F-03), CH-05 (F-06), CH-06 (F-02) and BUS-02 (F-06); CH-07's F-01 check was removed because PR #43 added the step. The test data was cleaned afterwards with the SQL in §4.3.
```sh
TEST_RUNNER_KILALA_ALLOW_WRITE_TESTS=1 xcodebuild test -project kilala-ios/Kilala/Kilala.xcodeproj \
  -scheme Kilala -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO
```

| Group | Passed | Known issue (expected failure) | Failed |
|---|---|---|---|
| `KilalaTests` (unit) | 47 | – | 0 |
| CH-01 – CH-08 | 5 | 3 (CH-02, CH-05, CH-06) | 0 |
| BUS-01 – BUS-11 | 10 | 1 (BUS-02) | 0 |
| Cardholder dashboard, supporting UI tests and launch screenshots | 10 | – | 0 |
| **Total** | **72** | **4** | **0** |

**Run E – after PR #35 (Business Dashboard), branch `fix/app-bus/local-api-url`, everything, write tests on: passed – 68 passed, 5 known issues, 0 failed, 0 skipped.** 20 Nov 2026, Xcode's default parallel testing. This run verifies the Debug `localhost` API URL and the BUS tests' new dashboard and scanner-drawer flow. Earlier attempts on this branch failed for test-side reasons now handled in the helpers: the open scanner drawer covering Logout, a late "Save Password?" prompt clearing the email field during a second login, and a local backend left unresponsive by a branch switch (restart the backend after switching branches).

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

These issues came up while designing and running the tests. **None are fixed by the test branches**, because they only add tests. F-01 was addressed by PR #43, F-16 by PRs #60 and #62, and the business half of F-06 by PR #64. F-02, F-03 and F-06 are tracked by known-issue checks in the MCO4 tests (CH-06, CH-02 and CH-05; see §3.2), which will report when the app is fixed. Priorities use the masterfile definitions: **High** breaks a core feature or exposes user data, **Medium** works but not correctly, **Low** is minor.

| ID | Area | Finding | Suggested priority |
|---|---|---|---|
| F-01 | Cardholder sign-up | **Addressed by PR #43:** after **Record Found!** and **Proceed**, a create-login step with an email code (OTP) calls `POST /api/auth/claim-cardholder` (checked by CH-07 and M-19). Original finding: sign-up stops after **Verify Record**. The app shows "Verified: …" but never asks for an email or password, and never calls `POST /api/auth/claim-cardholder`. A PWD or senior citizen therefore can't create an account in the app, even though "Login/Signup UI" is ticked in the masterfile. | High – confirm with the PO whether the claim step is planned for a later sprint |
| F-02 | Cardholder sign-up | Leaving **Middle Name** empty fails with "No matching LGU record found" whenever the LGU record has a middle name. The backend compares `COALESCE(middle_name,'') ILIKE ''`. Confirmed with Juan's record. The field isn't marked as required. | Medium |
| F-03 | Login | All failures (wrong password, server down, 500) show the same message, "Invalid credentials or server offline.", because `APIService.login` turns every non-2xx response into the same `URLError`. Users can't tell a typo from an outage. | Low |
| F-04 | Security | `Info.plist` sets `NSAllowsArbitraryLoads = true`, which allows plain HTTP to **every** server, not just the local backend. `NSAllowsLocalNetworking` is enough for development, and release builds should use HTTPS. APP-02 accepts either setting, so tightening it won't break the test. | Low (hardening) |
| F-05 | Testability | The views have no `accessibilityIdentifier`s. The UI tests find elements by visible text (collected in `UIText` in `KilalaUITestSupport.swift`), and find the cardholder sign-up fields by position because they have empty placeholders. Adding identifiers would make the tests resistant to copy changes. Likewise, the category list in `BusinessSignupView` is `private`, so SCH-03 has to compare against a copy; making it `internal` (or moving it to a shared model) would let the test read the real list. | Low |
| F-06 | Sign-up UX | The cardholder date of birth picker defaults to today and accepts future dates. *(Business sign-up has had password rules and an email format check since PR #64; BUS-02 checks them.)* | Low |
| F-07 | CI/CD | **Addressed in branch `chore/ci/ios-tests`:** a shared scheme and `.github/workflows/ios-tests.yml` (§5.3). Original finding: `.github/workflows/ci.yml` has no iOS job, and the project has no **shared** Xcode scheme (`xcshareddata`). `xcodebuild` currently relies on an auto-generated scheme. Ops would need a macOS runner and a shared scheme for iOS tests to run in CI. | Ops backlog |
| F-08 | Backend (for Ops) | If `JWT_SECRET` is missing, the backend falls back to a hard-coded secret, and the masterfile contains the live database password and JWT secret in plain text. Change both and keep them out of shared documents. | High (security, backend/Ops) |
| F-09 | API agreement | The `POST /api/auth/verify-record` handler tries to include `middle_name` in its response, but the SQL query doesn't select that column, so the key is always absent from the JSON. The app handles this (API-07), but the response doesn't contain what the code intends. | Low |
| F-10 | Repository | The `.gitignore` rule `*.xcodeproj/*` contains a slash, so git applies it only at the repo root, never to `kilala-ios/Kilala/Kilala.xcodeproj`. Personal Xcode files (`xcuserdata/`) aren't ignored; two developers' are already committed (the second by PR #59). A rule such as `**/*.xcodeproj/xcuserdata/` would fix it. This branch doesn't commit any `xcuserdata`. | Low |
| F-11 | Backend (for Ops) | `POST /api/auth/login` skips the bcrypt check when a user's stored hash equals the seed placeholder, and accepts the placeholder text itself as the password. Since PR #62, `POST /api/auth/change-password` has the same shortcut. All four seeded accounts use it, **including the LGU admin**, and that password is published in `seed.sql`, the masterfile and this document. On any database where `seed.sql` was loaded, such as the shared Supabase database per the masterfile, anyone who reads the repo can sign in as the LGU admin and read cardholder records through `/api/lgu/cardholders`. This is acceptable for throwaway test data only. Remove the shortcut, or limit it to test environments, before any real data is stored. | High (security, backend/Ops) |
| F-12 | Backend (privacy) | `POST /api/auth/verify-record` passes the name fields to `ILIKE` without escaping. Anyone who knows a card number and date of birth can send `%` as the names and receive the cardholder's first and last name (confirmed on the local database with the PR #32 seed record). The different 404 / 403 / 409 responses also reveal whether a record exists and whether it's claimed or inactive. | Medium (privacy, backend) |
| F-13 | Backend (security) | `POST /api/auth/claim-cardholder` (PR #43) only checks the email code when the request uses `profile_id`, the app's flow. The older form, `lgu_id_number` + `date_of_birth` (kept for the Postman tests), claims an account **without any email code**, so anyone who knows a card number and date of birth can take over an unclaimed card with an email of their choice. Confirmed on the local database (201). | High (security, backend) |
| F-14 | Backend (security) | `POST /api/auth/verify-otp` has no attempt limit, so the 6-digit code can be guessed by trying every value within its 10-minute lifetime. | Medium (security, backend) |
| F-15 | Backend / setup | `POST /api/auth/request-otp` sends the code through the email account in `EMAIL_USER`/`EMAIL_PASS` (or `SMTP_*`). Without them, as in a fresh local setup, **Send OTP to email** shows "Failed to send verification code…" and cardholders can't finish signing up. The code is saved before sending, so a failed send still leaves it in `otp_verifications`. Add the variables to the setup notes and confirm they are set on Render. | Medium |
| F-16 | Cardholder dashboard | **Addressed by PRs #60 and #62** (Transactions and Profile tabs). Original finding: the tabs added in PR #53 were empty screens. | – |
| F-17 | Business sign-up | **Issuing LGU** preselects the first LGU returned by the backend. Once more LGUs exist (PR #44 seeds 17 Metro Manila cities, Caloocan first), a business that doesn't change it registers under the wrong city. Leave it empty until the user picks one. | Medium |
| F-18 | Backend (security) | PR #64 makes a business claim a record its LGU accredited, but the old `POST /api/auth/register-business` is still open and creates a business with `is_accredited` = TRUE (the column default). Anyone can call it directly and get an accredited business that can verify cardholders and record 20% discounts, so the new check only exists in the app. Remove the route, or create businesses as not accredited until the LGU approves them. LIVE-09 still uses this route and will need updating with it. | High (security, backend) |
| F-19 | Database | PR #64 changes `business_profiles.user_id` in `schema.sql` to allow NULL and to `ON DELETE SET NULL` (it was `NOT NULL … ON DELETE CASCADE`), with no migration. Only new databases get the change; the shared and Render databases keep the old rule, so `schema.sql` and the real databases no longer match. The code still works with the old rule (it also accepts the placeholder users from PR #61). Add a migration, or keep `schema.sql` as it was. | Medium |
| F-20 | Business sign-up (question for the PO) | Step 1 proves ownership with the business name, LGU, permit number and TIN. The permit is usually posted in the store and the TIN is printed on receipts, so someone other than the owner could claim an unclaimed business. Is that enough, or should the LGU give the owner a claim code? | Question |

---

## 9. Limitations and out of scope

- **CI/CD Schema** and **PostgreSQL deployment** are infrastructure goals. The iOS suite only checks them indirectly, by talking to a running backend and database.
- **QR verification, card status, discounts and transaction history** are covered by BUS-04 – BUS-11 and CH-08. The QR code is entered through the scanner's Simulator Debug Input, not scanned.
- The **camera** isn't available in the simulator, so the scanner's camera path can't be UI-tested there.
- **LIVE-07** and **CH-07** need the unclaimed QA record (in `seed.sql` on `dev`). They are skipped if it is missing or already claimed.
- **Token expiry** after 24 hours isn't simulated in the app. JWT-01 checks the expiry claim, and JWT-03 checks that the backend rejects invalid tokens.
- `testLaunchPerformance` is the Xcode template's measurement. It has no baseline, so it never fails. Each launch takes about 2.6 s (§7), but the test launches and closes the app several times, so it adds about 40 seconds to a full run.
- CH-06 and CH-07 set the date of birth through the picker's month and year wheels (`setDateOfBirth`). This relies on the system picker's accessibility labels ("DatePicker.Show", "March 17"), so an iOS update could require changing the helper.
- iOS's "Save Password?" prompt can appear a few seconds after login and swallow the next tap. `logOut`, `openScanner` and `verifyQR` dismiss it and retry; if a UI test fails on a tap right after login, check the failure screenshot for this prompt first.
- **Known issues** (CH-02, CH-05, CH-06) are reported as expected failures until the app is fixed; see §3.2.
- **Email codes (OTP)** are sent by email, which a UI test can't read, so CH-07 stops at the create-login form and BUS-03 before Continue to Verification; the rest of cardholder and business sign-up is manual checks M-19 and M-20.
- The cardholder **Transactions** and **Profile** tabs (PRs #60, #62) and the business Transactions filters and Profile aren't automated yet; see manual checks M-21 – M-23.
- iOS's **"Use Strong Password?"** panel replaces the keyboard on an empty new-password field (business sign-up). `focus` closes it; if a sign-up test types a wrong password, check the failure screenshot for this panel.

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
