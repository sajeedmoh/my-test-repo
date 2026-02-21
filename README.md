# my-test-repo

A collection of sample testing projects for learning and experimentation.

## About

This repository contains small sample projects used for testing various concepts, tools, and technologies.

## Projects

### To-Do App (with Authentication)

A fully client-side To-Do application with user authentication, built with plain HTML, CSS, and JavaScript. All data is persisted in `localStorage`.

| File | Description |
|------|-------------|
| [register.html](register.html) | Registration page — create an account with name, email, and password. Includes real-time password strength meter and validation rules. Rejects duplicate emails. |
| [login.html](login.html) | Login page — authenticates against registered accounts. Shows an error on invalid credentials. Redirects to the app on success. |
| [todo-list.html](todo-list.html) | Protected To-Do app — requires login to access. Supports adding, editing, completing, and deleting tasks, with filters and per-user task storage. Includes a logout button. |

**User flow:**
```
Register → Login → To-Do List → Logout → Login
```

**Features:**
- Per-user task lists (each account has its own tasks)
- Auth guard: visiting the To-Do page without a session redirects to login
- Already-logged-in users are redirected away from login/register pages
- Password strength meter with 5 validation rules on registration

## Getting Started

Clone the repository:

```bash
git clone https://github.com/sajeedmoh/my-test-repo.git
cd my-test-repo
```

## License

This repository is for personal testing and learning purposes.
