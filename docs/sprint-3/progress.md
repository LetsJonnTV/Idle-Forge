# Sprint 3 — Angular Frontend Progress

## Goal
Build complete Angular 17 frontend for Idle Forge game website.

## Status: ✅ Complete — PR #4 open

---

## Phase 1 — Infrastructure ✅
- [x] `src/environments/environment.ts` (dev → localhost:3000)
- [x] `src/environments/environment.prod.ts` (prod → api.idle-forge.jonn2008.me)
- [x] `src/CNAME` copied to assets to survive `deleteOutputPath: true` builds
- [x] `angular.json` — outputPath → `../docs`, fileReplacements, CNAME in assets

## Phase 2 — Core Services ✅
- [x] `src/app/core/auth.service.ts` — JWT localStorage, login/register/logout, getUser (base64 decode)
- [x] `src/app/core/api.service.ts` — HttpClient wrapper with auto Bearer auth header
- [x] `src/app/core/modal.service.ts` — BehaviorSubject for modal visibility
- [x] `src/app/core/admin.service.ts` — Admin API calls

## Phase 3 — Guards ✅
- [x] `src/app/guards/auth.guard.ts` — redirects to / if not logged in
- [x] `src/app/guards/admin.guard.ts` — redirects to /dashboard if not admin

## Phase 4 — Components ✅
- [x] `HeaderComponent` — sticky dark header, login/register buttons, live auth state
- [x] `AuthModalComponent` — modal with tabs, login/register forms, ModalService controlled

## Phase 5 — Pages ✅
- [x] `LandingComponent` — exact recreation of docs/index.html content as Angular component
- [x] `DashboardComponent` — 4 tabs: Profile, Cloud Save, Friends, Password
- [x] `AdminComponent` — search, player table, inline actions (reset pw, block, give, delete)

## Phase 6 — App Shell + Styles ✅
- [x] `app.module.ts` — HttpClientModule, FormsModule, ReactiveFormsModule, all components
- [x] `app-routing.module.ts` — routes with guards
- [x] `app.component.*` — minimal shell with header + auth-modal + router-outlet
- [x] `styles.scss` — CSS variables, global button/input styles
- [x] `src/index.html` — updated title to "Idle Forge"

## Decisions Made
- `outputPath` uses object form `{ "base": "../docs", "browser": "" }` so Angular build outputs directly to `docs/` (not `docs/browser/`)
- `deleteOutputPath: true` with CNAME preserved via assets list in angular.json
- Friends "me" side: determined by comparing `requester.id` with `AuthService.getUser().playerId`
- Password validator: custom validator function on FormGroup (no extra library)
- Admin inline forms: per-row state tracked by player ID in Maps (not a dialog library)
- Using traditional `*ngIf`/`*ngFor` directives (module-based app, not standalone)
- `| number` and `| date` pipes available via BrowserModule → CommonModule
