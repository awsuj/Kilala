# Kilala: PWD & Senior Citizen Record Verification System

Kilala is a centralized mobile and web platform designed to digitize and streamline the verification process for Person with Disability (PWD) and Senior Citizen privilege cards. Developed as a software engineering project (STSWENG), Kilala mitigates fraudulent card usage, simplifies the validation of mandatory discounts for commercial establishments, and modernizes record-keeping for Local Government Units (LGUs).

## 🚀 Features

* **For Cardholders (iOS):** Secure digital ID generation featuring a dynamic, time-sensitive QR code linked directly to official LGU records.
* **For Businesses (iOS):** A fast, native camera scanner utilizing AVFoundation to instantly authenticate customer QR codes against the central database, keeping an immutable audit trail.
* **For LGUs (Web Portal):** A comprehensive dashboard for administrators to register constituents, manage ID statuses (Active, Suspended, Revoked), and monitor verification analytics within their municipality.

## 🛠 Tech Stack

**Frontend (LGU Web Portal)**
* Framework: Next.js (React)
* Language: TypeScript
* Styling: Tailwind CSS

**Mobile (Cardholder & Business Apps)**
* Framework: Native iOS (SwiftUI)
* Language: Swift
* Hardware Integration: AVFoundation (Camera), CoreImage (QR Generation)

**Backend (Central API)**
* Runtime & Framework: Node.js with Express.js
* Language: TypeScript
* Database: PostgreSQL (Hosted via Supabase)
* Security: JSON Web Tokens (JWT) & bcrypt

## 📁 Repository Structure

The Kilala project operates as a monorepo containing the following core environments:

* **`.github/workflows/`**: Continuous Integration (CI) pipelines and GitHub Actions configurations (e.g., `ci.yml`) managed by the Ops role.
* **`backend/`**: The Express.js API, database connection (`.env`), database schemas (`schema.sql`, `seed.sql`), and TypeScript configurations.
* **`kilala-web/`**: The Next.js web application for the LGU administrative dashboard.
* **`kilala-ios/`**: The Xcode project containing the native Swift/SwiftUI application.
* **`docs/`**: Project documentation, Sprint Backlogs, API specifications, and User Stories.
* **`qa-tests/`**: Automated test collections (e.g., Postman collections) used by the QA role.

## ⚙️ Local Development Setup

To run this project locally, you will need Node.js, Xcode (for the iOS app), and access to the team's Supabase PostgreSQL database.

### 1. Clone the Repository

```bash
git clone [https://github.com/](https://github.com/)[your-org]/kilala.git
cd kilala
```

### 2. Backend Setup

Navigate to the backend folder to install dependencies and configure your environment:

```bash
cd backend
npm install
```

Create a `.env` file in the `backend/` directory and request the `DATABASE_URL` and `JWT_SECRET` from the Project Manager or Ops Lead. It should follow this format:

```env
PORT=5001
DATABASE_URL="postgresql://postgres.[project-ref]:[password]@aws-0-[region][.pooler.supabase.com:6543/postgres](https://.pooler.supabase.com:6543/postgres)"
JWT_SECRET="your_secret_key"
```

Start the backend development server:

```bash
npm run dev
```

### 3. Web Portal Setup

Navigate to the web application folder:

```bash
cd ../kilala-web
npm install
npm run dev
```

The LGU portal will be accessible at `http://localhost:3000`.

### 4. iOS App Setup

1. Open Xcode.
2. Select **Open an existing project**.
3. Navigate to the `kilala-ios/` directory and open the `.xcodeproj` file.
4. Select your target simulator (e.g., iPhone 15 Pro) and press `Cmd + R` to build and run.

## 👥 Scrum Team Roles

* **Product Owner (PO):** Defines the product vision, manages the Sprint Backlog, and ensures the system meets the core verification goals.
* **Analysts:** Bridges stakeholder requirements with technical execution, crafting detailed User Stories.
* **Developers:** Cross-functional engineers building the iOS app, Next.js web portal, and Node.js backend.
* **QA (Quality Assurance):** Designs and executes test plans for the iOS scanner, web dashboard, and API performance.
* **Ops (Operations):** Manages the monorepo infrastructure, Supabase cloud environment, and automated CI/CD pipelines.
