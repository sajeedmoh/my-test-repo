# my-test-repo

A collection of web projects with a shared authentication system and central dashboard.

## Project Structure

```
my-test-repo/
├── login.html          ← Entry point (all users start here)
├── register.html       ← Create a new account
├── dashboard.html      ← Project launcher (requires login)
├── todo-list.html      ← To-Do app (requires login)
├── prayer-times.html   ← Islamic Prayer Times app
└── calculator.py       ← Python calculator script
```

## User Flow

```
register.html
      ↓
login.html  ──────────────→  dashboard.html
                                   │
                    ┌──────────────┼──────────────┐
                    ↓              ↓               ↓
             calculator.py   todo-list.html  prayer-times.html
                    │              │               │
                    └──────────────┴───────────────┘
                                   │
                             ← Back to Dashboard
```

---

## Pages

### `login.html` — Login
- Email + password authentication against `localStorage` accounts
- Live field validation on blur
- Redirects already-logged-in users straight to the dashboard
- On success, saves session and navigates to `dashboard.html`

### `register.html` — Registration
- Collects first name, last name, email, and password
- Real-time password strength meter with 5 validation rules
- Rejects duplicate email addresses
- Stores accounts in `localStorage`

### `dashboard.html` — Project Dashboard
- Auth-guarded: redirects to login if no session exists
- **Left sidebar** with vertical project tiles (Calculator, Todo List, Prayer Times)
- Personalised greeting using the logged-in user's name (adapts to time of day)
- Live clock and date in the top bar
- Sign out button clears session and returns to login

---

## Projects

### To-Do List (`todo-list.html`)
A protected task management app. Requires login to access.

**Features:**
- Add, edit, complete, and delete tasks
- Filter by All / Active / Done
- Per-user task storage (each account has its own list)
- Auth guard — redirects to login without a session
- **← Back to Dashboard** bar at the top

### Islamic Prayer Times (`prayer-times.html`)
A full-featured Islamic prayer times web app.

**Features:**

| Feature | Detail |
|---------|--------|
| Prayer times | Fajr, Dhuhr, Asr, Maghrib, Isha with Adhan times |
| Iqama times | Displayed on each card — +20 min for all prayers, +5 min for Maghrib |
| Next Prayer banner | Highlights the upcoming prayer with a live countdown |
| Next Iqama banner | Shows the upcoming Iqama with a live countdown |
| Calculation methods | 16 methods selectable (Muslim World League, ISNA, Umm Al-Qura, etc.) |
| Asr school | Standard (Shafi'i/Maliki/Hanbali) or Hanafi |
| Location | City + Country input, or GPS auto-detect |
| Hijri date | Displayed in the info bar |
| **Ramzan Fasting banner** | Shown during Ramadan — displays today's fasting day number, progress bar, and days remaining |
| Kerala moon sighting | Fasting day calculated from local Kerala moon sighting date (Feb 19, 2026 = Day 1 for Ramadan 1447 AH) |
| Islamic theme | Dark green background, geometric tile overlay, animated crescent moon, star field, mosque silhouette |
| **← Back to Dashboard** | Fixed nav bar at the top of the page |

**Iqama offsets:**
```
Fajr    → Adhan + 20 min
Dhuhr   → Adhan + 20 min
Asr     → Adhan + 20 min
Maghrib → Adhan +  5 min
Isha    → Adhan + 20 min
```

**Prayer times API:** [Aladhan API](https://aladhan.com) (free, no API key required)

### Calculator (`calculator.py`)
A Python script for basic arithmetic operations. Open in a Python environment or terminal — not a web page.

---

## Getting Started

Clone the repository:

```bash
git clone https://github.com/sajeedmoh/my-test-repo.git
cd my-test-repo
```

Open `login.html` in any modern browser. Register an account, then log in to access the dashboard and all projects.

> **Note:** All authentication data is stored in `localStorage` — no backend required.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Plain HTML, CSS, JavaScript (no frameworks) |
| Auth & storage | `localStorage` |
| Prayer times data | Aladhan REST API |
| Python | Calculator script (`calculator.py`) |

## License

This repository is for personal testing and learning purposes.
