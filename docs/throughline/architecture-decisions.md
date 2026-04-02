---
last-updated: 2026-04-02
sources:
  - SDK-09-ARCHITECTURE-ROUND-2.md
  - AUDOS.md (auto-generated, throughline repo root)
  - UX audit (inbox/2026-04-02T1500-ux-audit-report.md)
  - Single-app architecture test (live, 2026-04-02)
---

# Throughline — Architecture Decisions

Confirmed findings from platform investigation. Answers to all architecture questions.

---

## Confirmed: Single App Architecture

**Decision: Consolidate to one entry in config.json.**

Apps are just React components loaded dynamically by Desktop.tsx. No permissions, isolation, or performance difference between 1 app and 5 apps. "Apps" is a scaffolding convention, not a technical requirement.

```json
// config.json — target state
{
  "apps": [
    {
      "id": "throughline",
      "name": "Throughline",
      "icon": "Sparkles",
      "component": "apps/throughline/App.tsx"
    }
  ]
}
```

Internal routing via `useState` (recommended) or `HashRouter`. Do not use BrowserRouter — may conflict with platform URL handling.

---

## Confirmed: audos-workspace/ is the Only Source of Truth

**`src/pages/apps/` should be deleted.** Audos ignores everything outside `audos-workspace/`. The `src/` folder is dead weight.

Correct structure:
```
audos-workspace/
  apps/throughline/App.tsx   ← Single entry point
  components/ui/             ← ShadCN components
  components/                ← Shared app components
  hooks/                     ← Custom hooks
  lib/                       ← Utilities, API wrappers, theme
  data/                      ← JSON data files
  config.json                ← App registry + branding
```

Local dev uses a mock layer in `src/lib/audos-sdk.ts` with env flag switching (`VITE_USE_REMOTE_API`).

---

## Confirmed: No Platform UI Constraints

Apps are pure React components. The platform injects:
- `SpaceRuntimeContext` — session, file ops, event tracking
- `window.__workspaceDb` / `window.useWorkspaceDB` — database SDK
- Global Tailwind CSS (v3)

Minimum requirement: export a default React component. That's it.

ShadCN: copy components to `audos-workspace/components/ui/`. Fully supported.

Radix UI (ShadCN dependency): must be in `cdnDependencies` in config.json, OR use ShadCN components that don't require Radix. To be validated by test.

---

## Confirmed: Compilation Model

- **Bundler**: ESBuild (ES2020, ESM)
- **Entry points**: One TSX file per app — can import from `components/`, `hooks/`, `lib/`
- **CDN deps**: React, ReactDOM, Lucide React pre-configured. Others added via `cdnDependencies` in config.json.
- **Deploy**: Push to GitHub → Audos inbound sync → ESBuild compile → live

No npm packages available inside apps. All dependencies must be in CDN importmap.

---

## Root Cause: Blank White Screens

Studio, Briefing, Signature all show blank white screens because **the app files don't exist**. config.json references:
- `apps/briefing/App.tsx` — folder does not exist in audos-workspace/
- `apps/signature/App.tsx` — folder does not exist
- `apps/studio/App.tsx` — folder does not exist

Only `apps/home/` and `apps/setup/` have real implementations. The `src/pages/apps/Studio.tsx` etc. are in the wrong location and ignored by the platform.

Fix: either create the missing files, or consolidate to single app (recommended).

---

## Hooks Reference

| Hook | Notes |
|------|-------|
| `useSpaceRuntime()` | Session, config, file ops, subscription state |
| `useWorkspaceDB(table, options)` | PostgreSQL via `window.useWorkspaceDB` |
| `useSubscription()` | Subscription status, plan tier, trial state |
| `useBranding` | ❌ Does not exist — use `useSpaceRuntime().config.desktop.branding` |
| `useSession` | ❌ Does not exist — use `useSpaceRuntime().sessionId` |

---

## Confirmed: Single-App Architecture Test Results (2026-04-02)

Live test passed. App running at workspace-351699 as `apps/throughline/App.tsx`.

| Test | Result | Notes |
|------|--------|-------|
| Single app with internal routing | ✅ | `useState<Page>` routing works |
| DB query — guest_prep_podcast_profiles | ✅ | Query ran, 0 rows (empty workspace) |
| DB query — voice_profiles | ✅ | Query ran, 0 rows |
| ShadCN-style components (no Radix) | ✅ | Button, Card, Badge render correctly |
| Radix UI primitives | ⏳ | Not yet tested |
| TanStack Query | ⏳ | Not yet tested |

**Next:** Add `@radix-ui/react-*` and `@tanstack/react-query` to `cdnDependencies` in config.json and test.

---

## Confirmed: New Apps Require Otto — 3-Step Process (SDK-10)

**GitHub sync alone is NOT sufficient to make a new app appear in the dock.**

Full details in `SDK-10-GITHUB-SYNC-NEW-APP-INVESTIGATION.md`.

### The Pipeline

There are TWO codebases on the platform, not one:

| Location | Contains | Updated by |
|----------|----------|-----------|
| `apps/{appId}/App.tsx` | Raw source (TypeScript/TSX) | GitHub sync ✅ |
| `.published-source/apps/{appId}/App.tsx` | Compiled bundle | Platform bundler only |

`Desktop.tsx` loads apps from `.published-source/`, not from source. GitHub sync updates source but never triggers the bundler for new apps. If `.published-source/apps/{appId}/` doesn't exist, the app is invisible regardless of what config.json says.

### "Ghost App" State

After a GitHub push that adds a new app, the app is in a **ghost state**:
- ✅ Listed in config.json
- ✅ Source file exists at `apps/{appId}/App.tsx`
- ❌ No compiled bundle at `.published-source/apps/{appId}/`
- ❌ Not visible in dock

`recompile` and `delegate_app_edit` on a ghost app both silently succeed but don't create the bundle.

### Correct Procedure for New Apps

Ask Otto to:
```
1. delete_app(appId: "{id}")                         — remove ghost
2. delegate_app_edit(appId: "new", ...)              — creates compiled bundle
3. publish_draft(target: "app", appId: "{id}")       — promotes draft to live
```

### For Coding Assistants

After pushing a new app via GitHub, tell the user:
> "I've added the config and source. Please ask Otto to publish the new [app name] app — the platform needs to compile and deploy it."

Do NOT assume it will appear automatically.

### What GitHub Sync Does Handle (Improved)

For **existing** apps (ones already with a compiled bundle):
- Config.json changes ✅
- Source file updates ✅
- Recompile picks up changes ✅

The GitHub → dock gap only affects **new** app entries.

---

## New Files Referenced (Not Yet in Repo)

SDK-09 referenced these files from the platform runtime — request from Auto if needed:
- `APP_INTEGRATION_MANIFEST.md` — all 25+ platform integrations
- `SPACE_APP_GUIDE.md` — app development guide
- `integrations/workspace-db/docs.md` — WorkspaceDB SDK documentation
