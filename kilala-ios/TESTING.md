# Kilala iOS – Sprint 1 QA Test Suite

| | |
|---|---|
| **Scope** | Sprint 1 – Foundation, Contracts & Auth (iOS app) |
| **Author** | Edson John Willie (QA / iOS Developer) |
| **Branch** | `test/app/sprint-1` |
| **Targets** | `KilalaTests` (Swift Testing) · `KilalaUITests` (XCTest / XCUIAutomation) |
| **Last run** | 6 Nov 2026 · Xcode 27.2 · iPhone 17 simulator (iOS 27.2) · see [§7](#7-latest-results) |

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
| **Database Schema** | The app's user roles, sign-up ID types and business categories match the enums in `backend/src/schema/schema.sql`. Card statuses are checked against the agreed list (see the note under SCH-04). | SCH-01 – SCH-04 |
| **PostgreSQL deployment** | The backend serves real rows from the database (seeded Makati LGU, seeded accounts). DB-01 only confirms the API process is up; it doesn't query the database. | DB-02, LIVE-01 (DB-01 supporting) |
| **CI/CD Schema** | Not testable from the app. All tests run headless with one `xcodebuild` command (§5.3), ready for an iOS CI job. See finding F-07. | – |
| **JWT Auth API** | The token is stored after login, sent as `Bearer`, has the agreed claims and 24-hour expiry, and is refused when missing, forged or used by the wrong role. | AUTH-01 – AUTH-06, JWT-01 – JWT-05, UI-17 |
| **Login/Signup UI** | Login screen, button states, error messages, role-based landing screens, logout, cardholder and business sign-up screens and their validation, and creating a cardholder account from a verified record. | UI-01 – UI-21, VAL-01 – VAL-03, launch screenshots |
| **Finalize API agreements** | The app's models decode the backend's JSON, requests use the agreed paths, fields and headers, and error statuses map to the right app errors. | API-01 – API-10, AUTH-*, SIGN-01 – SIGN-12, LIVE-01 – LIVE-09 |
| *App foundation (supporting)* | The app's Info.plist allows HTTP to local servers and declares camera access. | APP-01 – APP-03 |

### Test types

| Type | Needs backend? | Creates data? | Behaviour when backend is down |
|---|---|---|---|
| **Unit – offline** (models, schema, stubbed API) | No | No | Runs normally |
| **Unit – live** (`S1-LIVE`) | Yes | No* | Whole suite is **skipped** |
| **UI – offline** | No | No | Runs normally |
| **UI – live** | Yes | No* | Test is **skipped** |
| **Write tests** (LIVE-09, UI-15, UI-20) | Yes | **Yes** | Skipped unless `KILALA_ALLOW_WRITE_TESTS=1` |

\* Logging in updates `users.last_login_at`, and the `trg_users_updated_at` trigger also updates `users.updated_at`. Nothing else is written.

---

## 2. Test files

```
kilala-ios/
├── TESTING.md                              ← this document
└── Kilala/
    ├── KilalaTests/                         Swift Testing, runs inside the app host
    │   ├── KilalaTests.swift                S1-APP   app foundation (Info.plist)
    │   ├── ModelContractTests.swift         S1-API   JSON ↔ Codable models
    │   ├── SchemaContractTests.swift        S1-SCH   app enums ↔ schema.sql
    │   ├── APIServiceAuthTests.swift        S1-JWT   APIService vs stubbed backend
    │   ├── LiveBackendContractTests.swift   S1-LIVE  APIService vs real backend
    │   ├── InputValidationTests.swift       S1-VAL   sign-up email/password checks
    │   └── Support/
    │       ├── MockURLProtocol.swift        intercepts URLSession.shared
    │       ├── Fixtures.swift               agreed JSON payloads + seeded accounts
    │       └── LiveBackend.swift            localhost:5001 helpers, JWT decoder
    └── KilalaUITests/                       XCTest, drives the app in the simulator
        ├── KilalaUITests.swift              launch smoke, relaunch, launch performance
        ├── KilalaUITestsLaunchTests.swift   screenshots in light/dark, portrait/landscape
        ├── LoginUITests.swift               login screen and role landing
        ├── SignupUITests.swift              cardholder and business sign-up
        └── Support/
            └── KilalaUITestSupport.swift    accounts, on-screen text, helpers
```

The Sprint 1 tests were added without changing production code. `APIService` uses a fixed URL and `URLSession.shared`, so the unit tests intercept `URLSession.shared` with `MockURLProtocol` instead of adding test hooks to the app. The branch `fix/app/sprint-1-findings` then changed the app to fix findings F-01 to F-06 (§8) and updated the affected tests. New files are picked up automatically (the project uses synchronized folders), so nothing needs to be added to the Xcode project.

Unit tests that touch the network sit under one parent suite, `NetworkTests`. Both that parent and each of its two child suites are marked `.serialized`, so these tests run one at a time. That way a stub installed by one test can never answer a request from another, and tests that share the app's stored token never overlap.

---

## 3. Test case catalogue

### 3.1 Unit tests – `KilalaTests` (Swift Testing)

#### S1-APP · App foundation – `KilalaTests.swift` (offline)

| ID | Test | Expected result |
|---|---|---|
| APP-01 | Tests run inside the Kilala app host | Host executable is `Kilala` |
| APP-02 | App Transport Security allows plain HTTP to the local backend | `NSAllowsLocalNetworking` (or `NSAllowsArbitraryLoads`) is true. The app now uses `NSAllowsLocalNetworking` (F-04). |
| APP-03 | Camera usage description is present | `NSCameraUsageDescription` exists and is not blank |

#### S1-API · Model contracts – `ModelContractTests.swift` (offline)

| ID | Test | Expected result |
|---|---|---|
| API-01 | Login response decodes for `CARDHOLDER`, `BUSINESS`, `LGU_ADMIN` | Message, token, user id and role decoded |
| API-02 | `UserRole` raw values | `CARDHOLDER`, `BUSINESS`, `LGU_ADMIN` |
| API-03 | Unknown role (`SUPER_ADMIN`) | Decoding fails |
| API-04 | Login response without `token` | Decoding fails |
| API-05 | Non-UUID user id | Decoding fails |
| API-06 | LGU list with `province: null` | Decodes, province is nil |
| API-07 | Verify-record response without `middle_name` | Decodes, middle name is nil |
| API-08 | Business registration response | User, token and snake_case `businessProfile` decoded |
| API-09 | Cardholder profile with extra columns | Decodes and ignores unknown keys |
| API-10 | Full name with missing / blank / present middle name | `Maria Bautista` or `Maria Clara Bautista` |

#### S1-SCH · Database schema contracts – `SchemaContractTests.swift` (offline)

Reads `backend/src/schema/schema.sql` from the repo. Skipped if the file is not found.

| ID | Test | Expected result |
|---|---|---|
| SCH-01 | `UserRole` vs `user_role` enum | Identical sets |
| SCH-02 | Sign-up ID types vs `privilege_type` enum | `PWD`, `SENIOR_CITIZEN` |
| SCH-03 | `business_category` enum vs `BusinessSignupView.categories` | Identical sets, no duplicates in the app list |
| SCH-04 | `card_status` enum contains the agreed statuses | Contains `ACTIVE`, `EXPIRED`, `REVOKED`, `SUSPENDED` |

> **Note on SCH-03 and SCH-04.** SCH-03 reads the category list the business sign-up screen actually shows (`BusinessSignupView.categories`, made readable by the F-05 fix), so a change on either side fails the test. SCH-04 checks the **schema side** only, against the agreed list of statuses; the app itself currently only checks for `ACTIVE`.

#### S1-JWT · APIService with a stubbed backend – `APIServiceAuthTests.swift` (offline)

Every error-path test also checks that the stub answered exactly one request (`assertAnsweredByStub()`). Without that check, a broken stub could let a test pass against a running real backend, because the real backend returns the same errors.

| ID | Test | Expected result |
|---|---|---|
| AUTH-01 | Login request shape | `POST http://localhost:5001/api/auth/login`, JSON body with exactly `email` and `password`, no `Authorization` header |
| AUTH-02 | Successful login | Returns the session and stores the JWT in `authToken` |
| AUTH-03 | Login gets 400 / 401 / 403 / 500 | `badRequest("Email and password are required")`, `unauthorized("Invalid email or password")`, `unauthorized("Account is deactivated")`, `serverError("The Kilala server had a problem…")`; no token stored (F-03) |
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
| SIGN-09 | Claim-cardholder request shape (F-01) | `POST /api/auth/claim-cardholder` with exactly `lgu_id_number`, `date_of_birth`, `email`, `password` |
| SIGN-10 | Claim-cardholder 201 | Returns a `CARDHOLDER` session and stores the JWT |
| SIGN-11 | Claim-cardholder 409 (ID already claimed, email in use) | `APIError.conflict` carrying the backend message, no token |
| SIGN-12 | Claim-cardholder 400 / 404 / 500 | `badRequest` / `badRequest` / `serverError` carrying the backend message, no token |

#### S1-VAL · Sign-up input validation – `InputValidationTests.swift` (offline)

| ID | Test | Expected result |
|---|---|---|
| VAL-01 | Well-formed emails (5 cases, including surrounding spaces) | Accepted |
| VAL-02 | Malformed emails (8 cases: empty, no `@`, no domain, space, double `@`, one-letter TLD) | Rejected |
| VAL-03 | Password length | Fewer than 8 characters → "Password must be at least 8 characters."; 8 or more → accepted |

#### S1-LIVE · Real backend on localhost:5001 – `LiveBackendContractTests.swift`

The whole suite is skipped if `GET /api/health` doesn't answer.

| ID | Test | Expected result |
|---|---|---|
| DB-01 | Health endpoint | `200 {"status":"healthy","system":"Kilala Backend API"}` |
| DB-02 | LGU list from the database | Contains Makati City (`MKT`, id `1111…1111`) |
| LIVE-01 | Seeded accounts log in through `APIService` | Correct role for Juan, Maria, cashier, admin; token stored |
| LIVE-02 | Wrong password through `APIService` | `APIError.unauthorized("Invalid email or password")`, no token stored |
| LIVE-03 | Login error contract | `{}` → 400, email only → 400 (`Email and password are required`); unknown user → 401 (`Invalid email or password`) |
| JWT-01 | Token structure and claims | 3 parts; `id`, `email`, `role` match the user; `exp − iat` = 86 400 s |
| JWT-02 | Cardholder token opens the profile | Juan's profile, card `MKT-PWD-2026-00481` |
| JWT-03 | Missing / malformed / forged token on `/cardholder/me` | 401 `Access token required` or 403 `Invalid or expired token` |
| JWT-04 | Valid token, wrong role | 403 `Forbidden: Insufficient permissions` (business → cardholder route, admin → cardholder route, cardholder → business route, cardholder → LGU route) |
| JWT-05 | `APIService` with a forged token | Throws |
| LIVE-04 | Verify-record with no fields | 400 `All fields are required for verification` |
| LIVE-05 | Verify-record with unknown details | `APIError.badRequest` with the no-match message |
| LIVE-06 | Verify-record for Juan's (already claimed) card | `APIError.conflict` with the already-claimed message |
| LIVE-07 | Verify-record for the unclaimed seed record | Succeeds. **Skipped if the record (Ana Santos) isn't in the database or was already claimed, for example by UI-20.** Reset it with the SQL in §4.3. |
| LIVE-08 | Business registration with missing fields | `APIError.badRequest`, no token |
| LIVE-09 | Register a new business, log in, then register again | Registration succeeds with a `BUSINESS` JWT, login works, duplicate → `APIError.conflict`. **Write test.** |

### 3.2 UI tests – `KilalaUITests` (XCTest)

The login, sign-up and app launch tests (`LoginUITests`, `SignupUITests`, `KilalaUITests`) start in portrait from a cold launch on the login screen, and close the app after each test. The screenshot tests (`KilalaUITestsLaunchTests`) set no orientation, because Xcode runs them in each configuration.

#### Login – `LoginUITests.swift`

| ID | Test | Backend | Expected result |
|---|---|---|---|
| UI-01 | Login screen shows all entry points | – | Email, secure Password, Login, Create new account, Register your Business |
| UI-02 | Login disabled until both fields filled | – | Disabled → disabled (email only) → enabled |
| UI-03 | Login disabled with password only | – | Disabled |
| UI-04 | Password is masked | – | Typed text is not visible in the field value |
| UI-05 | Wrong password | Live | `Invalid email or password` (the backend's message, F-03); stays on login |
| UI-06 | PWD cardholder login and logout | Live | **My Kilala ID**, then Logout returns to login |
| UI-07 | Senior citizen login | Live | **My Kilala ID** |
| UI-08 | Business login and logout | Live | **Merchant Scanner**, then Logout returns to login |
| UI-09 | LGU admin login | Live | "Please use the Kilala Web Portal for LGU Admin access."; Logout works |

#### Sign-up – `SignupUITests.swift`

| ID | Test | Backend | Expected result |
|---|---|---|---|
| UI-10 | Create new account opens cardholder sign-up | – | Register Account, PWD / Senior Citizen options, first / middle / last name, card number and date of birth inputs (found by accessibility ID), Verify Record |
| UI-11 | Cardholder sign-up validation | – | Empty form and first-name-only both show "Please fill in your first name, last name, and physical card number." |
| UI-12 | Back from cardholder sign-up | – | Returns to login |
| UI-13 | Business sign-up form | – | All 6 text fields, secure Password, Register Business disabled |
| UI-14 | LGU list loads and form enables submit | Live | Makati City (MKT) preselected; Register Business enabled after required fields (not submitted) |
| UI-15 | Register a new business through the UI | Live, **write** | Lands on **Merchant Scanner** |
| UI-18 | Date of birth is required and can't be in the future (F-06) | – | Leaving it on today shows "Please select your date of birth."; the calendar's Next Month button is disabled |
| UI-19 | Blank middle name on a record that has one (F-02) | Live | "No matching LGU record found…" plus "If your ID shows a middle name, enter it as well." |
| UI-20 | Cardholder sign-up creates a login (F-01) | Live, **write** | Verify Ana's record, mismatched passwords are caught, then **Create Account** lands on **My Kilala ID** showing "Ana Marie Santos". Skipped if the record was already claimed. |
| UI-21 | Business sign-up rejects an invalid email and a short password (F-06) | Live | Both hints shown and Register Business disabled; fixing both hides the hints and enables it (not submitted) |

#### App launch – `KilalaUITests.swift`

| ID | Test | Backend | Expected result |
|---|---|---|---|
| UI-16 | App launches to the login screen | – | Foreground, title and Login button visible |
| UI-17 | Relaunch starts signed out | Live | After logging in and relaunching, the login screen shows (the JWT is kept in memory only) |
| – | `testLaunchPerformance` | – | Records launch time (Xcode template; no pass/fail baseline set) |

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

> ⚠️ **Use a local database for testing.** The app always calls `localhost:5001`, so tests hit whatever database your backend's `.env` points to. If that's the shared Supabase database, login tests update `last_login_at` there. With the write flag on, LIVE-09 and UI-15 also create businesses there.

### 4.3 Test data

These seeded accounts are local test data only. They are the same accounts used in the masterfile and the web and Postman tests.

| Role | Email | Password |
|---|---|---|
| PWD cardholder | `juan.pwd@email.com` (card `MKT-PWD-2026-00481`, born 1998-05-14) | `MockHashForTestingOnly123456789012` |
| Senior citizen | `maria.senior@email.com` (card `MKT-OSCA-2026-08912`) | same |
| Business | `cashier@mercury-mkt.com` | same |
| LGU admin | `admin@makati.gov.ph` | same |
| Unclaimed record (no login yet) | Ana Marie Santos, PWD, card `MKT-PWD-2026-TEST-001`, born 1999-03-17 (in `seed.sql` on `dev`) | – |

Write tests create businesses named `QA iOS Store <random>` with emails `qa.ios.<random>@example.test`, and UI-20 claims Ana's record with the email `qa.ios.claim.<random>@example.test`. To undo both on a **local** database (unlink the record first, then delete the test users):
```sql
UPDATE cardholder_profiles SET user_id = NULL
 WHERE lgu_id_number = 'MKT-PWD-2026-TEST-001'
   AND user_id IN (SELECT id FROM users WHERE email LIKE 'qa.ios.%@example.test');
DELETE FROM users WHERE email LIKE 'qa.ios.%@example.test';   -- cascades to business_profiles
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

**Login and sign-up UI tests only:**
```sh
xcodebuild test -project kilala-ios/Kilala/Kilala.xcodeproj -scheme Kilala \
  -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO \
  -only-testing:KilalaUITests/LoginUITests -only-testing:KilalaUITests/SignupUITests
```

**A single test:**
```sh
# XCTest (UI):        Target/Class/method
-only-testing:KilalaUITests/LoginUITests/testUI06_CardholderLogsInToDigitalIDAndLogsOut
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

### 5.3 For a future CI job

The suite needs no manual steps. A macOS runner with Xcode 26+ can run the unit tests with the "unit tests only" command above. Without a backend, the live suites skip themselves. To run them in CI too, start PostgreSQL and the backend first (§4.2). See finding F-07.

---

## 6. Manual test procedures

Use these to check by hand what the automated tests cover, for example during Sprint Review or UAT. Start the backend (§4.2) and run the app on the simulator (**⌘R**). Record the device, iOS version and a screenshot for anything that fails, following the bug report format in the masterfile.

| # | Steps | Expected result | Automated by |
|---|---|---|---|
| M-01 | Launch the app. | Login screen shows "Kilala", Email, Password (dots), Login, Create new account, Register your Business. | UI-01, UI-16 |
| M-02 | Leave both fields empty. Type an email only. Then add a password. | Login is greyed out until both fields have text. | UI-02, UI-03 |
| M-03 | Log in as `juan.pwd@email.com` with password `wrong`. | Red text "Invalid email or password"; stays on login. | UI-05 |
| M-04 | Log in as `juan.pwd@email.com` with the test password. | "My Kilala ID" with Juan's card `MKT-PWD-2026-00481`. Tap **Logout** → back to login. | UI-06 |
| M-05 | Log in as `maria.senior@email.com`. | "My Kilala ID" with Maria's senior citizen card. | UI-07 |
| M-06 | Log in as `cashier@mercury-mkt.com`. | "Merchant Scanner". Tap **Logout** → back to login. | UI-08 |
| M-07 | Log in as `admin@makati.gov.ph`. | Message to use the Kilala Web Portal, and a Logout button. | UI-09 |
| M-08 | Log in as Juan, then quit the app from the app switcher and reopen it. | Login screen; you must sign in again. | UI-17 |
| M-09 | Stop the backend (Ctrl-C in its terminal) and log in as Juan. Restart the backend afterwards. | "Can't reach the Kilala server. Check your internet connection and try again." | Manual only |
| M-10 | Tap **Create new account**. | "Register Account" with PWD / Senior Citizen choices, name fields, card number, date of birth, Verify Record. | UI-10 |
| M-11 | Tap **Verify Record** with an empty form, then with only a first name. | "Please fill in your first name, last name, and physical card number." both times. | UI-11 |
| M-12 | Fill in Juan, Santos, Dela Cruz, `MKT-PWD-2026-00481`, born 14 May 1998, and tap **Verify Record**. | "This ID has already been claimed by an existing account." | LIVE-06 (API level) |
| M-13 | Same as M-12 but leave **Middle Name** empty. | "No matching LGU record found…" followed by "If your ID shows a middle name, enter it as well." | UI-19 |
| M-14 | Fill in made-up details and tap **Verify Record**. | "No matching LGU record found. Please check your details." | LIVE-05 (API level) |
| M-15 | Tap **Register your Business**. | Form with Issuing LGU (Makati City (MKT) preselected), business fields, email and password. Register Business is greyed out. | UI-13, UI-14 |
| M-16 | Fill in all fields marked * with new values and tap **Register Business**. *(Creates data – local database only.)* | Signed in on "Merchant Scanner". | UI-15, LIVE-09 |
| M-17 | Repeat M-16 with the same email or permit number. | Alert "Duplicate Registration – Email or Business Permit No. already exists". | LIVE-09 (API level) |
| M-18 | Tap **Create new account**, fill in names and card number, leave the date of birth on today and tap **Verify Record**. Then open the date picker. | "Please select your date of birth."; days after today are greyed out and you can't move to next month. | UI-18 |
| M-19 | Fill in Ana Marie Santos, `MKT-PWD-2026-TEST-001`, born 17 March 1999, and tap **Verify Record**. Enter a new email and two different passwords and tap **Create Account**; then fix the confirmation and tap it again. *(Claims the record – local database only; reset with §4.3.)* | "Verified: Ana Santos!" and a **Create your login** section; "Passwords do not match."; then signed in on "My Kilala ID" for Ana Marie Santos. | UI-20 |
| M-20 | In **Register your Business**, type `not-an-email` as the email and `short` as the password. | Red hints under both fields; Register Business stays greyed out until both are valid. | UI-21 |

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

**Run D – branch `fix/app/sprint-1-findings` (fixes for F-01 to F-06), everything, write tests on: passed, 80 / 80, nothing skipped.** 13 Nov 2026, about 9 minutes, on a local database with Ana's record unclaimed at the start.
```sh
TEST_RUNNER_KILALA_ALLOW_WRITE_TESTS=1 xcodebuild test -project kilala-ios/Kilala/Kilala.xcodeproj \
  -scheme Kilala -destination 'platform=iOS Simulator,name=iPhone 17'
```

| Target | Passed | Failed | Skipped |
|---|---|---|---|
| `KilalaTests` (unit, including the new SIGN-09 – SIGN-12 and VAL-01 – VAL-03) | 54 | 0 | 0 |
| `KilalaUITests` (UI, including the new UI-18 – UI-21) | 26 | 0 | 0 |
| **Total** | **80** | **0** | **0** |

This run used Xcode's default parallel testing (simulator clones). Earlier runs on the branch failed for test-side reasons that are now handled in the helpers: iOS's "Save Password?" prompt swallowing the Logout tap (UI-06, UI-08, UI-09), and iOS's "Use Strong Password?" sheet replacing the keyboard in the new sign-up form (UI-20). See §9. The two test businesses and the claimed record were removed and reset afterwards with the SQL in §4.3. Runs A to C below were on the Sprint 1 test branch, before the fixes.

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

These issues came up while designing the tests. **F-01 to F-06 are fixed in the branch `fix/app/sprint-1-findings`**; the rest are open. Priorities use the masterfile definitions: **High** breaks a core feature or exposes user data, **Medium** works but not correctly, **Low** is minor.

**Fixes in `fix/app/sprint-1-findings`**

| ID | Fix | Verified by |
|---|---|---|
| F-01 | After **Verify Record**, the sign-up screen shows **Create your login** (email, password, confirm password). **Create Account** calls `POST /api/auth/claim-cardholder` with the verified card number and birth date and signs the user in to their Digital ID. Editing a matched field after verifying clears the verification, so the account is always created for the record that was verified. A 409 (already claimed or email in use) suggests logging in instead. | SIGN-09 – SIGN-12, UI-20 |
| F-02 | Fixed in the app, without changing the backend's matching rule: the Middle Name field now says to enter it exactly as on the ID, and a failed match with a blank middle name adds "If your ID shows a middle name, enter it as well." Making the backend ignore a blank middle name instead is a product decision for the PO and backend owner. | UI-19 |
| F-03 | `APIService.login` maps 400 → `badRequest`, 401/403 → new `APIError.unauthorized`, 5xx → `serverError`, each with a readable message. The login screen shows that message, a separate "Can't reach the Kilala server…" message for network errors, and a generic message otherwise. | AUTH-03, LIVE-02, UI-05, M-09 |
| F-04 | `Info.plist` uses `NSAllowsLocalNetworking` instead of `NSAllowsArbitraryLoads`, so plain HTTP is allowed only to local hosts. | APP-02, the full live suite |
| F-05 | Accessibility identifiers on the login, sign-up, Digital ID and LGU admin screens (listed in `UIID` in `KilalaUITestSupport.swift`). The sign-up UI tests now find inputs by identifier instead of position. `BusinessSignupView.categories` is no longer private, and SCH-03 reads it directly. | UI-10, UI-11, SCH-03 |
| F-06 | The date of birth can't be in the future, and leaving it on today shows "Please select your date of birth." Business sign-up and the new cardholder login require a valid email format and a password of at least 8 characters, with inline hints (`InputValidation.swift`). | VAL-01 – VAL-03, UI-18, UI-21 |


| ID | Area | Finding | Suggested priority |
|---|---|---|---|
| F-01 | Cardholder sign-up | Sign-up stops after **Verify Record**. The app shows "Verified: …" but never asks for an email or password, and never calls `POST /api/auth/claim-cardholder`. A PWD or senior citizen therefore can't create an account in the app, even though "Login/Signup UI" is ticked in the masterfile. | High – confirm with the PO whether the claim step is planned for a later sprint |
| F-02 | Cardholder sign-up | Leaving **Middle Name** empty fails with "No matching LGU record found" whenever the LGU record has a middle name. The backend compares `COALESCE(middle_name,'') ILIKE ''`. Confirmed with Juan's record. The field isn't marked as required. | Medium |
| F-03 | Login | All failures (wrong password, server down, 500) show the same message, "Invalid credentials or server offline.", because `APIService.login` turns every non-2xx response into the same `URLError`. Users can't tell a typo from an outage. | Low |
| F-04 | Security | `Info.plist` sets `NSAllowsArbitraryLoads = true`, which allows plain HTTP to **every** server, not just the local backend. `NSAllowsLocalNetworking` is enough for development, and release builds should use HTTPS. APP-02 accepts either setting, so tightening it won't break the test. | Low (hardening) |
| F-05 | Testability | The views have no `accessibilityIdentifier`s. The UI tests find elements by visible text (collected in `UIText` in `KilalaUITestSupport.swift`), and find the cardholder sign-up fields by position because they have empty placeholders. Adding identifiers would make the tests resistant to copy changes. Likewise, the category list in `BusinessSignupView` is `private`, so SCH-03 has to compare against a copy; making it `internal` (or moving it to a shared model) would let the test read the real list. | Low |
| F-06 | Sign-up UX | The date of birth picker defaults to today and accepts future dates. Business sign-up has no password rules and no client-side email format check. | Low |
| F-07 | CI/CD | `.github/workflows/ci.yml` has no iOS job, and the project has no **shared** Xcode scheme (`xcshareddata`). `xcodebuild` currently relies on an auto-generated scheme. Ops would need a macOS runner and a shared scheme for iOS tests to run in CI. | Ops backlog |
| F-08 | Backend (for Ops) | If `JWT_SECRET` is missing, the backend falls back to a hard-coded secret, and the masterfile contains the live database password and JWT secret in plain text. Change both and keep them out of shared documents. | High (security, backend/Ops) |
| F-09 | API agreement | The `POST /api/auth/verify-record` handler tries to include `middle_name` in its response, but the SQL query doesn't select that column, so the key is always absent from the JSON. The app handles this (API-07), but the response doesn't contain what the code intends. | Low |
| F-10 | Repository | The `.gitignore` rule `*.xcodeproj/*` contains a slash, so git applies it only at the repo root, never to `kilala-ios/Kilala/Kilala.xcodeproj`. Personal Xcode files (`xcuserdata/`) aren't ignored; one developer's are already committed. A rule such as `**/*.xcodeproj/xcuserdata/` would fix it. This branch doesn't commit any `xcuserdata`. | Low |
| F-11 | Backend (for Ops) | `POST /api/auth/login` skips the bcrypt check when a user's stored hash equals the seed placeholder, and accepts the placeholder text itself as the password. All four seeded accounts use it, **including the LGU admin**, and that password is published in `seed.sql`, the masterfile and this document. On any database where `seed.sql` was loaded, such as the shared Supabase database per the masterfile, anyone who reads the repo can sign in as the LGU admin and read cardholder records through `/api/lgu/cardholders`. This is acceptable for throwaway test data only. Remove the shortcut, or limit it to test environments, before any real data is stored. | High (security, backend/Ops) |
| F-12 | Backend (privacy) | `POST /api/auth/verify-record` passes the name fields to `ILIKE` without escaping. Anyone who knows a card number and date of birth can send `%` as the names and receive the cardholder's first and last name (confirmed on the local database with the PR #32 seed record). The different 404 / 403 / 409 responses also reveal whether a record exists and whether it's claimed or inactive. | Medium (privacy, backend) |
| F-13 | Backend (security) | `POST /api/auth/claim-cardholder` only checks the card number and date of birth. It ignores the names, the privilege type and the card status that `verify-record` checks, so anyone who calls it directly with a card number and birth date can claim an unclaimed record, even a `REVOKED` or `SUSPENDED` one. The app's F-01 flow always verifies first, but the API doesn't enforce it. Found while fixing F-01. | High (security, backend) |

---

## 9. Limitations and out of scope

- **CI/CD Schema** and **PostgreSQL deployment** are infrastructure goals. The iOS suite only checks them indirectly, by talking to a running backend and database.
- **QR scanning, the digital ID's QR display and transaction history** are Sprint 2–3 features and aren't covered here. Only their login entry points are.
- The **camera** isn't available in the simulator, so the scanner's camera path can't be UI-tested there.
- **LIVE-07** and **UI-20** need Ana's unclaimed record. UI-20 claims it, so after a run with write tests on, both are skipped until the record is reset (§4.3).
- **Token expiry** after 24 hours isn't simulated in the app. JWT-01 checks the expiry claim, and JWT-03 checks that the backend rejects invalid tokens.
- `testLaunchPerformance` is the Xcode template's measurement. It has no baseline, so it never fails. Each launch takes about 2.6 s (§7), but the test launches and closes the app several times, so it adds about 40 seconds to a full run.
- **iOS password prompts.** When the new sign-up form's Password field is focused while both password fields are empty, iOS shows its "Use Strong Password?" sheet instead of the keyboard, and XCUITest can't operate that sheet. UI-20 therefore types Confirm Password first. In the simulator, closing the sheet with ✕ left an empty panel with no keyboard; **check on a real iPhone** that a user who doesn't want a generated password can still type their own (M-19). Separately, iOS's "Save Password?" prompt can appear a few seconds after login; the `logOut` helper dismisses it and retries the Logout tap.
- UI-19 and UI-20 set the date of birth through the picker's month and year wheels (`setDateOfBirth` in `KilalaUITestSupport.swift`). This depends on the system date picker's accessibility labels ("Show year picker", "March 17"), so an iOS update could require changing the helper.

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
