# Incident Post-Mortem: React Error #31 — Blank App on Audos Platform

**Date:** 2026-04-22
**App:** Throughline (`app.trythroughline.com`) on Audos workspace `workspace-351699`
**Severity:** P1 — production app completely blank for multiple sessions
**Duration:** ~2 full debugging sessions (~6-8 hours elapsed)
**Resolved:** Yes

---

## Summary

The Throughline React app deployed to the Audos platform via GitHub Dev Mode mounted and immediately crashed with Minified React error #31. The page was blank. The root cause was that `@tanstack/react-router@1.168.10` was declared in `cdnDependencies`, which caused Audos to generate an importmap entry without the `?deps=react@18.3.1` query parameter that Audos uses for its pre-configured packages. At runtime, esm.sh resolved TanStack Router's React peer dependency independently and loaded React 19.2.5 alongside the platform's React 18.3.1. React elements created by Router code (which used React 19) were passed to the platform renderer (React 18), which did not recognize the `$$typeof` Symbol and threw error #31. The fix was to remove TanStack Router from `cdnDependencies` entirely and replace it with a 30-line state-based discriminated-union router with no external dependencies.

---

## Timeline

- **Session 1, early:** App deployed via GitHub push. Page blank. First hypothesis: pipeline broken, sync not working. Spent time monitoring GitHub → Audos sync, comparing timestamps, re-pushing. Sync was working normally; latency was 15-30 min. No pipeline issue.

- **Session 1, mid:** Hypothesis shifted to platform detection. Code was using `window.__spaceContext` to detect whether running on Audos. Audos does not inject this global — it was never set, causing detection logic to fail and take wrong initialization path. Fixed `isOnPlatform()` to use a different signal. App still blank.

- **Session 1, late:** Stripped `RouterProvider` from `App.tsx` to isolate whether the router was the issue. Made a diagnostic push. App still crashed. Concluded the router was not the problem because `App.tsx` no longer imported it. This conclusion was wrong. `routes.tsx` still imported TanStack Router and Audos compiles all `.tsx` files in the app directory regardless of whether they are reachable from the entry point. TanStack Router was still loading.

- **Session 2, early:** Pivoted to inspecting the live importmap via Chrome DevTools network inspection. Fetched the live importmap and observed the entry for `@tanstack/react-router` was missing `?deps=react@18.3.1`, while `lucide-react` had it.

- **Session 2, mid:** Filtered the Network tab by `react` and observed two React versions loading: `react@18.3.1` (from the platform importmap entry) and `react@19.2.5` (fetched by TanStack Router's internal peer dep resolution). Dual-React confirmed as root cause.

- **Session 2, late:** Removed `@tanstack/react-router` from `config.json`. Deleted or rewrote all files importing it. Wrote `lib/router.tsx` as a state-based replacement. Rewrote `AppShell.tsx` to use button-based navigation. App rendered successfully. Also corrected `isOnPlatform()` to use `window.__WORKSPACE_ID__` and added a guard to skip daemon health check on platform.

---

## Root Cause

**Audos adds `?deps=react@18.3.1` to its own pre-configured packages in the generated importmap but does NOT add it to packages declared in `cdnDependencies`.**

When a package with `react` as a peer dependency is added to `cdnDependencies`, Audos generates an importmap entry pointing at `esm.sh/{package}@{version}` without any `?deps=` qualifier. When the browser loads that URL, esm.sh resolves the package's peer dependencies using its own resolution logic, which may select a newer React version than the one the Audos platform uses.

In this case:

| Package | Importmap entry | React version used |
|---|---|---|
| `lucide-react` (pre-configured) | `esm.sh/lucide-react@0.462.0?deps=react@18.3.1` | React 18.3.1 |
| `@tanstack/react-router` (custom cdnDep) | `esm.sh/@tanstack/react-router@1.168.10` | React 19.2.5 |

React 18 and React 19 use different `$$typeof` Symbols to identify React elements. An element created in a React 19 context fails the `$$typeof` check when the React 18 renderer processes it, producing:

```
Minified React error #31: Objects are not valid as a React child
(found: object with keys {$$typeof, type, key, ref, props, ...})
```

---

## Contributing Factors

### 1. Wrong platform detection signal

The initial `isOnPlatform()` used `window.__spaceContext`, which Audos does not inject. This caused the app to take the wrong initialization path on every platform render, making it impossible to distinguish routing failures from initialization failures. Time was spent debugging the initialization path rather than the dependency issue.

**Lesson:** The correct signal is `window.__WORKSPACE_ID__`. Audos always injects this. `__spaceContext` is not injected.

### 2. Bundler scope surprise

Removing `RouterProvider` from `App.tsx` and making a diagnostic push appeared to eliminate TanStack Router from the app. It did not. Audos compiles every `.tsx` file in the app directory, not just the entry point's transitive imports. `routes.tsx` still imported TanStack Router and it still loaded.

This created a false negative: the diagnostic change appeared to isolate the router as not-the-cause, because "App.tsx no longer uses it." In fact the router was still loading from a sibling file.

**Lesson:** When removing a library from an Audos app, you must remove all imports across every file in the app directory, or delete the files. Removing an import from the entry point is not sufficient.

### 3. Sync latency confusion

Early in debugging, the 15-30 minute pipeline latency was misread as a sync failure. Pushes were re-done, the pipeline was re-examined, and time was spent on a non-problem. The pipeline was working correctly throughout.

**Lesson:** Do not assume pipeline failure until 30+ minutes have elapsed and a manual sync has been attempted. Verify with the file API endpoint before concluding sync is broken.

### 4. Error message is misleading for this failure mode

React error #31 ("Objects are not valid as a React child") is typically caused by accidentally rendering a plain object or a Promise as a child. The dual-React failure produces the same error because from React 18's perspective, the element handed to it by React 19 code is an unrecognized object. The error message does not suggest "you have two Reacts loaded." The investigation had to work backwards from the symptom to the root cause without a direct error pointing at the real issue.

**Lesson:** When React error #31 appears in an Audos app, immediately check the Network tab for multiple React versions before debugging rendering logic.

---

## Resolution

The following changes resolved the incident:

1. **Removed `@tanstack/react-router` from `config.json`** — eliminated the bad importmap entry

2. **Deleted `routes.tsx`** — removed the file importing TanStack Router (it was not reachable from App.tsx but was being compiled and loaded)

3. **Created `lib/router.tsx`** — a 30-line state-based router using a discriminated union `Route` type, `useState`, and React context. No external dependencies.

4. **Rewrote `AppShell.tsx`** — replaced `<Link>` and `<Outlet>` components with button-based navigation using `useNavigate()` from `lib/router.tsx` and a `PageContent` component with a switch statement

5. **Fixed `isOnPlatform()`** — changed from `!!(window as any).__spaceContext` to `!!(window as any).__WORKSPACE_ID__`

6. **Added daemon guard** — wrapped daemon health check in `!isOnPlatform()` so it is skipped when running on Audos (no `/daemon` proxy available there)

---

## Prevention

### Add to the deployment checklist (see `16-github-dev-mode-app-deployment.md`)

- Before adding any package to `cdnDependencies`, check whether it has `react` in `peerDependencies`. If yes, do not add it — write the functionality natively or find a pure utility alternative.
- After any push, verify the live importmap via `GET /api/space/{workspaceId}/file/importmap.json` and confirm no React-dependent package is missing `?deps=react@18.3.1`.
- When debugging a blank screen caused by a React error, open Network tab, filter for `react`, and confirm only one React version is loading before investigating anything else.
- When making diagnostic changes (removing a library from the app), verify it has been removed from every `.tsx` file in the app directory, not just the entry point.
- Do not use `window.__spaceContext` for platform detection. Use `window.__WORKSPACE_ID__`.

### Do not use URL-based router libraries on Audos

TanStack Router, React Router DOM, and similar URL-based routers are unsafe on Audos for two reasons: (1) they carry React as a peer dependency and will trigger the dual-React trap, and (2) Audos controls the URL namespace. Use the state-based router pattern in `lib/router.tsx` instead.

---

## Open Items

These are platform-level issues that remain unresolved and may cause friction in future sessions:

| Item | Description | Status |
|---|---|---|
| No force-rebuild API | There is no way to trigger a recompile without a GitHub push. If you need to re-test a compiled output without code changes, you must make a no-op commit or use manual Sync from GitHub (which only syncs, may not recompile if content is identical). | Open — no known workaround beyond a code change commit |
| Dev Mode switching docs | Switching between GitHub Dev Mode and Platform Dev Mode is undocumented. Behavior is unclear and may leave the app in an inconsistent state. | Open — avoid switching modes in production |
| New-app registration compile gap | When a new app is first registered in Audos and then immediately pushed via GitHub, there may be a compile gap where the app directory is known to the platform but the first sync has not fully propagated. The duration of this gap is undocumented. | Open — add a wait step after first registration before testing |
| `?deps=` for custom cdnDependencies | Audos does not add `?deps=react@18.3.1` to custom packages, only to its pre-configured set. There is no documented way to specify this in `cdnDependencies`. If you need a React-dependent package, you must implement the functionality natively. | Open — platform limitation; raise with Audos support |

---

## References

- `16-github-dev-mode-app-deployment.md` — The reference guide derived from this incident
- `GITHUB-DEV-MODE-DIAGNOSIS.md` — Raw diagnosis notes from the debugging sessions
- `Audos Platform Gaps Analysis- Desktop.tsx and Single-App Spaces` — Adjacent platform limitation analysis
