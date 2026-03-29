# web-apps

A personal web portal with a public profile landing page, multiple mini-apps, JWT authentication, role-based access control, and a serverless AWS backend.

**Live:** [sajeed.online](https://sajeed.online)

---

## Project Structure

```
web-apps/
├── index.html               ← Public profile / landing page
├── login.html               ← Portal entry point
├── register.html            ← Create account
├── dashboard.html           ← Project hub (auth required)
├── todo-list.html           ← To-Do app (auth required)
├── prayer-times.html        ← Islamic prayer times (auth required)
├── utilities.html           ← Gold, silver & FX rates (auth required)
├── electricity-tracker.html ← KSEB usage tracker (auth required)
├── admin.html               ← User management (admin only)
├── session-guard.js         ← 30-min inactivity auto-logout
├── config.js                ← API base URL (auto-generated)
└── assets/
    └── profile.jpeg         ← Profile photo for landing page
```

---

## Auth & Roles

Every user record has:
- `role` — `"admin"` or `"developer"` (default: `"developer"`)
- `status` — `"active"` or `"locked"` (default: `"active"`)
- `lastLoginAt` — ISO timestamp, updated on every successful login

JWT payload includes `role`. The frontend uses it to show/hide the Admin tile and section.

**Auth guard:** All protected pages have an early `<script>` in `<head>` that redirects to `login.html` before any content renders — prevents cached pages being viewed without a valid session.

**Auto-logout:** `session-guard.js` tracks inactivity. Shows a warning modal at 28 minutes, logs out at 30 minutes.

**Locked accounts** are rejected at login with a clear error message.

### Bootstrap first admin

```bash
aws dynamodb update-item \
  --table-name auth_users \
  --key '{"email": {"S": "your@email.com"}}' \
  --update-expression "SET #r = :r, #s = :s" \
  --expression-attribute-names '{"#r": "role", "#s": "status"}' \
  --expression-attribute-values '{":r": {"S": "admin"}, ":s": {"S": "active"}}' \
  --region ap-south-1
```

Log out and back in — the new JWT will carry `role: admin` and the Admin tile appears.

---

## Pages

### `index.html` — Public Landing Page
- Professional profile page for Muhammed Sajeed
- Sections: Hero, About, Skills, Experience, Certifications
- Contact form — submissions sent via Lambda + SES to `sajeedmoh@gmail.com`
- Emails sent from `noreply@sajeed.online` (DKIM verified domain)
- Portal Login button links to `login.html`

### `login.html`
- Split layout — left panel explains portal features, right panel is the login form
- Calls `POST /api/auth/login`
- Redirects already-logged-in users to `dashboard.html`
- Shows "Account locked" message if status is locked
- On success: saves `auth_session` + `auth_token` to localStorage, redirects to dashboard

### `register.html`
- Collects first name, last name, email, password
- Real-time password strength meter
- Calls `POST /api/auth/register` — new users get `role: developer`, `status: active`

### `dashboard.html`
- Personalised greeting (adapts to time of day)
- Sidebar with project tiles
- Admin section (tile + nav label) visible only when `session.role === 'admin'`
- Sidebar role label shows actual role (Admin / Developer)

### `admin.html` _(admin only)_
- Redirects non-admins to `dashboard.html`
- User table: Full Name · Email · Role · Status · Last Login · Actions
- Per-row actions: Lock/Unlock, Change Role (dropdown), Delete
- Add User form: first name, last name, email, password, role

### `todo-list.html`
- Add, edit, complete, delete tasks
- Filter: All / Active / Done
- Per-user storage in localStorage (keyed by email)

### `prayer-times.html`
- Fajr, Dhuhr, Asr, Maghrib, Isha with Adhan + Iqama times
- Live countdown to next prayer / Iqama
- 16 calculation methods, Hanafi/Standard Asr
- GPS auto-detect or manual city input
- Hijri date display

### `utilities.html`
- Live USD/INR, AED/INR exchange rates with converters
- Gold (22K, per gram & pavan) and silver (999) Kerala rates with converters

### `electricity-tracker.html`
- Manual meter reading entries (date, reading, usage, comment, type)
- Billing cycle tracking — resets on "Bill received" entry
- Data persisted to DynamoDB via authenticated API

---

## API Endpoints

**Base URL:** `https://1dcu9kqzz9.execute-api.ap-south-1.amazonaws.com`

### Auth
| Method | Path | Auth |
|--------|------|------|
| POST | `/api/auth/register` | — |
| POST | `/api/auth/login` | — |

### Contact Form
| Method | Path | Auth |
|--------|------|------|
| POST | `/contact` | — |

### Electricity
| Method | Path | Auth |
|--------|------|------|
| GET | `/api/electricity` | JWT |
| POST | `/api/electricity` | JWT |
| DELETE | `/api/electricity/:id` | JWT |

### Admin
| Method | Path | Auth |
|--------|------|------|
| GET | `/api/admin/users` | JWT + admin |
| POST | `/api/admin/users` | JWT + admin |
| PUT | `/api/admin/users/:email/role` | JWT + admin |
| PUT | `/api/admin/users/:email/status` | JWT + admin |
| DELETE | `/api/admin/users/:email` | JWT + admin |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | HTML, CSS, JavaScript (no frameworks) |
| Backend | Node.js, Express, serverless-http |
| Auth | bcryptjs, jsonwebtoken |
| Database | AWS DynamoDB |
| Hosting | AWS S3 + CloudFront (frontend), Lambda + API Gateway (backend) |
| Email | AWS SES — `noreply@sajeed.online` |
| DNS & SSL | AWS Route 53 + ACM |
| Prayer times | [Aladhan API](https://aladhan.com) |
| Exchange rates | [@fawazahmed0/currency-api](https://github.com/fawazahmed0/exchange-api) |

---

## License

Personal project — Muhammed Sajeed.
