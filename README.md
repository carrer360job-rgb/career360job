# Career360 — Job Portal Platform

A full-featured, scalable job recruitment platform built for modern job seekers and enterprise recruiters:
- **Brand Name:** **Career360**
- **Slogan:** *Job Portal — Find Your Next Career Move*
- **Theme:** Corporate Blue (Primary: `#155EEF`, Dark: `#0B1F3A`, Accent: `#38BDF8`, Background: `#F8FAFC`, Cards: `#FFFFFF`, Text: `#172B4D`)
- **Candidate Experience:** Built with Flutter for Android & Web (Free tier, OTP login, profile/resume management, location/category job search, and 1-tap applications).
- **Employer Experience:** Built with Flutter (Responsive Web & App) for recruiters & companies (Company verification, subscription plans, quota-managed job posts, applicant tracking).
- **Admin Management:** Secure portal for verification moderation, subscription plan management, financial auditing, and reports.
- **Unified Onboarding Flow:** Users select their role upon first launch:
  - 💼 **Job Seeker:** Boots directly into Candidate Discovery Feed.
  - 🏢 **Employer / Recruiter:** Boots into Employer ATS & Post Job Dashboard.
  - 🔄 **Role Switcher:** Users can toggle between Candidate & Employer modes anytime.
- **Unified Backend API:** Built with Node.js, Express.js, Prisma ORM, and Neon PostgreSQL.

---

## 📁 Repository Structure

```text
Job_portal/
├── backend/                       # REST API (Node.js + Express + Prisma + Neon PostgreSQL)
│   ├── prisma/
│   │   └── schema.prisma          # Relational DB models (11 core models)
│   ├── src/
│   │   ├── config/                # Cloudflare R2, Razorpay, FCM, DB configs
│   │   ├── controllers/           # Route handlers
│   │   ├── middlewares/          # JWT auth, role validation, rate-limiting
│   │   ├── routes/                # REST API endpoints
│   │   ├── services/              # Quotas, notifications & payment business logic
│   │   ├── utils/                 # Helpers & validators
│   │   └── index.js               # Express server entry point
│   ├── .env.example
│   └── package.json
│
├── frontend/                      # Universal Responsive Flutter App (Android + iOS + Web)
│   ├── lib/
│   │   ├── core/                  # Design system, constants, responsive breakpoints
│   │   │   ├── theme/             # VetriJobs official color palette & typography
│   │   │   ├── constants/         # Tamil Nadu districts & job categories
│   │   │   └── responsive/        # Mobile (<768px), Tablet, Desktop (>=1024px)
│   │   ├── data/                  # Data layer (contracts & mock data)
│   │   │   ├── models/            # Job, User, Application models (mirrors Prisma schema)
│   │   │   └── mock/              # Realistic Tamil & English sample jobs & quotas
│   │   ├── features/              # Feature modules
│   │   │   ├── auth/              # Mobile OTP login & Role Switcher
│   │   │   ├── candidate/         # Job discovery, district filters, 1-tap apply, tracking
│   │   │   ├── employer/          # Job posting wizard, applicant ATS, quota overview
│   │   │   └── admin/             # Admin Panel: Verify employers, job moderation, metrics
│   │   ├── shared/                # Reusable widgets and layouts
│   │   └── main.dart              # Multi-role shell (Candidate, Employer, Admin)
│   ├── pubspec.yaml
│   └── analysis_options.yaml
│
├── docs/                          # Blueprints & Brand Specs
│   ├── Job_Portal_Complete_Project_Documentation_Updated.pdf
│   └── UI_THEME_AND_DESIGN_SYSTEM.md
│
├── .gitignore
├── package.json                   # Root workspace scripts
└── README.md
```

---

## 🚀 Quick Start Guide

### 1. Prerequisites
- **Node.js** v20+ / v24+
- **Flutter** 3.24+ / 3.47+
- **PostgreSQL** database (e.g. [Neon](https://neon.tech))
- **Git**

### 2. Backend Setup
```bash
cd backend
npm install
cp .env.example .env
# Edit .env with your Neon DB and secret keys
npm run prisma:generate
npm run dev
```
API runs on `http://localhost:5000` (Health check: `http://localhost:5000/api/health`).

### 3. Web Dashboard Setup (Employer & Admin)
```bash
cd web
npm install
npm run dev
```
Web app runs on `http://localhost:3000`.

### 4. Candidate Mobile App (Flutter)
```bash
cd mobile
flutter pub get
flutter run
```

---

## 🔒 Security & Data Boundaries
- **Cloudflare R2:** Resumes and sensitive company verification documents are stored in private buckets and served strictly via temporary pre-signed URLs.
- **Server-Side Quota Controls:** Atomic database transactions ensure subscription quota can never be circumvented by client-side manipulation.
- **Razorpay Idempotency:** Webhook signatures are validated and idempotently processed to prevent duplicate subscription grants.
