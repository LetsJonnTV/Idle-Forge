# Sprint 3 — Done ✅

**PR:** https://github.com/LetsJonnTV/Idle-Forge/pull/4
**Branch:** `feature/sprint-3`
**Merged into:** `main` (pending Producer review)

---

## What was built

### 37 files created/modified across `frontend/src/`

| Area | Files | Notes |
|------|-------|-------|
| Environments | `environment.ts`, `environment.prod.ts` | dev=localhost:3000, prod=api.idle-forge.jonn2008.me |
| Core services | `auth.service.ts`, `api.service.ts`, `modal.service.ts`, `admin.service.ts` | No third-party auth libs |
| Guards | `auth.guard.ts`, `admin.guard.ts` | Redirect on unauthorized access |
| Header | 3 files | Sticky, responsive, live auth state |
| Auth Modal | 3 files | Backdrop blur, Escape key, tab switching |
| Landing | 3 files | Exact replica of docs/index.html in Angular |
| Dashboard | 3 files | 4 tabs, ReactiveForm password, friends handling |
| Admin | 3 files | Debounced search, inline per-row forms |
| App shell | `app.module.ts`, `app-routing.module.ts`, `app.component.*` | Module-based |
| Styles | `styles.scss` | Full design system |
| Config | `angular.json`, `src/index.html`, `src/CNAME` | Build output to docs/ |
| Sprint docs | `docs/sprint-3/progress.md`, `done.md` | This file |

---

## Build setup

From `frontend/`:
```bash
ng build              # → outputs to ../docs/ (production)
ng build --configuration development  # → outputs to ../docs/ (dev, no minification)
ng serve              # → dev server on localhost:4200
```

The `docs/CNAME` file is preserved because `src/CNAME` is listed in the angular.json assets array.

---

## API contract assumptions
- JWT payload contains `playerId` (or falls back to `player_id` / `id` / `sub`)
- JWT payload contains `username` and `isAdmin` (or `is_admin`)
- Friends response: `{ friends: [{ id, status, requester: {...}, addressee: {...} }] }`
- Admin reset-password: `POST /api/admin/players/:id` with `{ newPassword }`

---

## Post-merge actions for Producer
1. Merge PR #4 into main
2. Run `cd frontend && ng build` to rebuild the GitHub Pages docs
3. Push the updated `docs/` folder (the build output) to trigger GitHub Pages deployment
4. Verify https://idle-forge.jonn2008.me renders the Angular app
