# GitHub Dev Mode — App Deployment Reference

> **SDK-Level Documentation** for developers building or debugging React apps on the Audos platform

This document covers everything you need to successfully deploy a React app via GitHub Dev Mode on Audos: how the pipeline works, what can break it, and how to diagnose problems fast. It is a reference, not a tutorial. Read it before starting a new app; return to it when debugging a blank page.

---

## Table of Contents

1. [How the Pipeline Works](#how-the-pipeline-works)
2. [CDN Dependency Rules](#cdn-dependency-rules)
3. [Routing on Audos](#routing-on-audos)
4. [Platform Detection](#platform-detection)
5. [File Scope — What Audos Compiles](#file-scope--what-audos-compiles)
6. [External API Calls — Guarding Against Unavailable Services](#external-api-calls--guarding-against-unavailable-services)
7. [Debugging Sync Issues](#debugging-sync-issues)
8. [Deployment Checklist](#deployment-checklist)

---

## How the Pipeline Works

### The Stages

```
GitHub push
    → Audos webhook receives push event (immediate, but occasionally dropped)
    → Audos syncs repository (pulls latest commit)
    → ESBuild compiles all .tsx files in apps/{appName}/
    → Compiled output is deployed to CDN
    → Browser loads app from CDN
```

### Timing

| Stage | Typical latency |
|---|---|
| Webhook delivery | Seconds |
| Sync + compile | 2–5 min |
| CDN propagation | 5–20 min |
| **Total: push to live** | **15–30 min** |

The 15-30 minute window is normal. Do not assume the pipeline is broken because your change is not live after 5 minutes.

### Webpack Webhook Misses

Occasionally a push webhook is silently dropped by Audos — no error, no indication, the previous version continues to serve. If you are past the 30-minute window and nothing has changed:

1. Go to the Audos Developer panel for your workspace
2. Click **Sync from GitHub** manually
3. Wait another 5-10 minutes

Manual sync always works. There is no way to force a recompile independently of sync.

### One-Way Sync

GitHub → Audos is one-way. Audos never writes back to GitHub. Do not make conflicting edits in the Audos UI and the repo at the same time.

### Dev Mode Switching

Avoid switching between **GitHub Dev Mode** and **Platform Dev Mode** on a live app. The behavior of switching is undocumented and can leave the app in an inconsistent state. Choose one mode and stay with it.

---

## CDN Dependency Rules

### How Dependencies Work

Audos apps cannot use npm packages in the traditional sense. There is no `node_modules`. Instead:

1. You declare dependencies in `config.json` under `cdnDependencies`
2. Audos generates a browser **importmap** pointing each package name at `esm.sh`
3. ESBuild compiles your `.tsx` files as ESM modules with bare import specifiers (`import { useState } from 'react'`)
4. The browser resolves those bare specifiers using the importmap at runtime

### Pre-Configured Packages

Audos pre-configures a set of packages with correct `?deps=react@18.3.1` query params so they bundle against the same React version the platform uses:

| Package | Version | Notes |
|---|---|---|
| `react` | 18.3.1 | Platform renderer — do not override |
| `react-dom` | 18.3.1 | Platform renderer — do not override |
| `lucide-react` | 0.462.0 | Correct `?deps=react@18.3.1` set by platform |
| `react-markdown` | 9.0.1 | Correct `?deps=react@18.3.1` set by platform |

These packages are automatically available without adding them to `cdnDependencies`.

### Adding Custom Packages

Add packages to `config.json` like this:

```json
{
  "cdnDependencies": {
    "date-fns": { "version": "3.6.0" },
    "clsx": { "version": "2.1.1" }
  }
}
```

Audos will generate importmap entries pointing at `esm.sh/{package}@{version}` — **without** `?deps=react@18.3.1`.

### The Dual-React Trap — Read This Before Adding Any React-Dependent Package

**This is the most dangerous failure mode on the Audos platform.**

When you add a package that has React as a peer dependency (any component library, router, state manager, etc.), Audos generates the importmap entry without `?deps=react@18.3.1`. The package then resolves its own peer dependency through esm.sh's peer-dep URL mechanism, which may fetch a **different React version** than the one Audos uses.

**Concrete example — what happened with `@tanstack/react-router`:**

`config.json`:
```json
{
  "cdnDependencies": {
    "@tanstack/react-router": { "version": "1.168.10" }
  }
}
```

Generated importmap:
```json
{
  "react": "https://esm.sh/react@18.3.1",
  "react-dom": "https://esm.sh/react-dom@18.3.1",
  "lucide-react": "https://esm.sh/lucide-react@0.462.0?deps=react@18.3.1",
  "@tanstack/react-router": "https://esm.sh/@tanstack/react-router@1.168.10"
}
```

Because `@tanstack/react-router` has a peer dep of `react@>=18.0.0 || >=19.0.0`, esm.sh resolved it to **React 19.2.5** at runtime. The page then had:

- React 18.3.1 — the Audos renderer
- React 19.2.5 — loaded by TanStack Router internally

React elements created by the TanStack Router's React 19 were passed to the React 18 renderer. React 18 did not recognize the `$$typeof` Symbol from React 19 and threw:

```
Minified React error #31: Objects are not valid as a React child
(found: object with keys {$$typeof, type, key, ref, props, ...})
```

The page mounted briefly then went blank. No network error. No 404. The importmap looked correct at a glance. The only way to catch it was to inspect the actual network resources and observe two React versions loading simultaneously.

### Package Safety Classification

| Safe to add | Caution | Avoid entirely |
|---|---|---|
| `date-fns`, `clsx`, `zod` | Any package with `react` as peerDep | TanStack Router, React Router DOM, Next.js |
| `lodash-es`, `nanoid` | Headless UI libraries | Any React-dependent component library not pre-configured by Audos |
| Pure utility ESM libraries | State managers with React bindings | |

**Rule:** If a package lists `react` or `react-dom` in `peerDependencies`, do not add it to `cdnDependencies`. Either write the functionality yourself or ask whether Audos can add it to the pre-configured list.

### Verifying the Live Importmap

To inspect what importmap Audos actually generated for your workspace:

```
GET https://audos.com/api/space/{workspaceId}/file/importmap.json
```

Compare the entries against what you expect. Look specifically for any package that is missing `?deps=react@18.3.1`. If a React-dependent package is missing it, that package will load a different React.

---

## Routing on Audos

### Why URL-Based Routers Fail

URL-based routers (React Router DOM, TanStack Router, etc.) fail on Audos for two compounding reasons:

1. **Dual-React trap** — They have React as a peer dependency and will pull a second React version (see above)
2. **URL control** — Audos controls the URL. The platform may intercept history API calls in ways that conflict with a library router's expectations. Deep-link URLs (e.g. `/episodes/123`) may not resolve to your app

Do not use URL-based router libraries on Audos. Use a state-based router instead.

### The State-Based Router Pattern

A state-based router keeps the current route in React state. Navigation is a function call, not a URL change. There is no history API, no browser back/forward (unless you add it), and no external library.

**Full implementation — `lib/router.tsx`:**

```tsx
import { createContext, useContext, useState } from 'react';

// Define all pages as a discriminated union.
// Add new pages here as your app grows.
export type Route =
  | { page: 'home' }
  | { page: 'episodes' }
  | { page: 'episode-detail'; episodeId: string; tab?: 'research' | 'story' | 'interview' | 'studio' }
  | { page: 'settings' }
  | { page: 'onboarding' };

type RouterCtx = {
  route: Route;
  navigate: (route: Route) => void;
};

const RouterContext = createContext<RouterCtx>({
  route: { page: 'home' },
  navigate: () => {},
});

export const useRouter = () => useContext(RouterContext);
export const useNavigate = () => useContext(RouterContext).navigate;
export const useRoute = () => useContext(RouterContext).route;

export function RouterProvider({ children }: { children: React.ReactNode }) {
  const [route, setRoute] = useState<Route>({ page: 'home' });
  return (
    <RouterContext.Provider value={{ route, navigate: setRoute }}>
      {children}
    </RouterContext.Provider>
  );
}
```

**Usage in `App.tsx`:**

```tsx
import { RouterProvider } from './lib/router';
import { AppShell } from './AppShell';

export default function App() {
  return (
    <RouterProvider>
      <AppShell />
    </RouterProvider>
  );
}
```

**Navigation in components:**

```tsx
import { useNavigate } from './lib/router';

function EpisodeCard({ episodeId }: { episodeId: string }) {
  const navigate = useNavigate();

  return (
    <button onClick={() => navigate({ page: 'episode-detail', episodeId })}>
      Open episode
    </button>
  );
}
```

**Page switcher:**

```tsx
import { useRoute } from './lib/router';
import { HomePage } from './pages/HomePage';
import { EpisodesPage } from './pages/EpisodesPage';
import { EpisodeDetailPage } from './pages/EpisodeDetailPage';

export function PageContent() {
  const route = useRoute();

  switch (route.page) {
    case 'home':       return <HomePage />;
    case 'episodes':   return <EpisodesPage />;
    case 'episode-detail': return <EpisodeDetailPage episodeId={route.episodeId} tab={route.tab} />;
    case 'settings':   return <SettingsPage />;
    default:           return <HomePage />;
  }
}
```

**Nav links (use buttons, not `<a>` or `<Link>`):**

```tsx
import { useNavigate, useRoute } from './lib/router';

function NavItem({ target, label }: { target: Route; label: string }) {
  const navigate = useNavigate();
  const route = useRoute();
  const isActive = route.page === target.page;

  return (
    <button
      onClick={() => navigate(target)}
      className={isActive ? 'nav-active' : 'nav-item'}
    >
      {label}
    </button>
  );
}
```

---

## Platform Detection

### The Correct Signal

Audos always injects a `__WORKSPACE_ID__` global into the browser environment. Use this to detect whether your app is running on the Audos platform:

```tsx
export function isOnPlatform(): boolean {
  return !!(window as any).__WORKSPACE_ID__;
}
```

### The Wrong Signal

`window.__spaceContext` is **not** set by Audos. Do not use it. It may appear in older internal docs or forum posts but it is not injected by the current platform.

### When to Use Platform Detection

Use `isOnPlatform()` to gate API calls that are only available when on the Audos platform — or conversely, to skip calls to services that are only available in local development.

```tsx
// Skip daemon health check on platform — no /daemon proxy exists there
if (!isOnPlatform()) {
  await checkDaemonConnection();
}

// Use platform-specific API endpoint
const baseUrl = isOnPlatform()
  ? 'https://audos.com/api/hooks/execute/workspace-351699'
  : 'http://localhost:8106';
```

Do not gate rendering or routing logic on `isOnPlatform()`. Keep platform detection to API and service initialization only.

---

## File Scope — What Audos Compiles

### All .tsx Files in the App Directory

Audos compiles **every `.tsx` file** inside `apps/{appName}/` as a separate ESM module. It does not trace imports from your entry point and compile only reachable files. If a file exists in the directory, it is compiled and loaded.

**Implication:** If you have a file that imports a broken library — even if `App.tsx` does not import that file — the library is still fetched and executed. This will cause failures.

**Example of the problem:**

```
apps/myapp/
├── App.tsx          ← does NOT import routes.tsx
├── AppShell.tsx
└── routes.tsx       ← imports @tanstack/react-router
```

Even though `App.tsx` does not import `routes.tsx`, Audos compiles `routes.tsx` and the browser loads it. The bad import in `routes.tsx` fires.

**What this means for debugging:** When stripping a library from your app, removing it from the entry point is not enough. You must remove all imports of that library from every file in the app directory, or delete the files entirely.

**What this means for development:** Keep unused files out of the app directory. Do not leave experimental or WIP files in `apps/{appName}/` unless they are import-safe.

---

## External API Calls — Guarding Against Unavailable Services

When your app calls external services (a local daemon, a development proxy, etc.), those services are not available when the app runs on the Audos platform. An uncaught rejection at startup will crash the app.

**Pattern:** Gate initialization calls with `isOnPlatform()`.

```tsx
// In your app's initialization or useEffect
useEffect(() => {
  if (isOnPlatform()) {
    // Platform-specific init: use Audos hooks, not the daemon
    initPlatformMode();
  } else {
    // Local dev: connect to local daemon
    initLocalMode();
  }
}, []);
```

**For API base URLs**, resolve once at startup:

```tsx
const API_BASE = isOnPlatform()
  ? 'https://audos.com/api/hooks/execute/workspace-351699'
  : 'http://localhost:8106';
```

**Do not** make calls to `localhost` from production. These will fail silently or with CORS errors, depending on browser security policy.

---

## Debugging Sync Issues

### Step 1: Verify what is actually live

Do not trust visual inspection of the app alone. Fetch the actual source file from the Audos file API:

```
GET https://audos.com/api/space/{workspaceId}/file/{path}
```

Example:
```
GET https://audos.com/api/space/workspace-351699/file/apps/myapp/App.tsx
```

Compare the returned content against your local file. If they match, the sync succeeded. If not, the sync has not completed or the webhook was dropped.

### Step 2: Inspect the live importmap

```
GET https://audos.com/api/space/{workspaceId}/file/importmap.json
```

Look at every entry. Check for:
- Missing `?deps=react@18.3.1` on any React-dependent package
- Unexpected packages (leftover from previous deploys)
- Correct version numbers

### Step 3: Check browser network tab for multiple React versions

If the app mounts and immediately crashes with a React error, open DevTools > Network > filter by `react`. If you see more than one React version loading (e.g. `react@18.3.1` and `react@19.2.5`), you have the dual-React problem. The package causing the second load is in your `cdnDependencies`.

### Step 4: If past 30 min with no change

1. Go to Developer panel in Audos UI
2. Click **Sync from GitHub**
3. Wait 10 minutes
4. Re-fetch the file API endpoint to confirm sync

### Common Patterns

| Symptom | Likely cause | Action |
|---|---|---|
| App unchanged after 30 min | Webhook drop | Manual sync from Developer panel |
| Blank page with React error #31 | Dual-React: package missing `?deps=` | Inspect importmap, remove offending package |
| Blank page, no JS errors | Compile error | Check browser console for ESBuild errors |
| Changes to one file not reflected | Bundler scope — another file may be caching | Try clearing browser cache; check if old file content is in CDN |
| App works locally, blank on platform | Platform detection or daemon dependency | Check `isOnPlatform()` guards; check for uncaught localhost calls |

---

## Deployment Checklist

Copy this checklist for every new Audos app before the first push.

```
PRE-PUSH CHECKLIST — AUDOS GITHUB DEV MODE

Dependencies
  [ ] All packages in cdnDependencies are pure utility libraries with no React peer dep
  [ ] No URL-based router libraries (React Router, TanStack Router, etc.) in cdnDependencies
  [ ] Pre-configured packages (react, react-dom, lucide-react, react-markdown) NOT re-declared
  [ ] config.json is valid JSON (run `cat config.json | python3 -m json.tool` to verify)

Routing
  [ ] lib/router.tsx uses state-based routing (discriminated union + useState)
  [ ] Navigation uses button onClick + navigate(), not <a href> or <Link>
  [ ] No RouterProvider from any external library
  [ ] All app pages are registered in the Route union type

Platform Detection
  [ ] isOnPlatform() uses window.__WORKSPACE_ID__ (not __spaceContext)
  [ ] Daemon/localhost calls are guarded with !isOnPlatform()
  [ ] API base URL resolves correctly for both platform and local

File Scope
  [ ] No files in apps/{appName}/ that import broken or missing libraries
  [ ] No leftover WIP files in the app directory
  [ ] Every .tsx file in the app directory is import-safe

After Push
  [ ] Wait 15-30 min before declaring sync broken
  [ ] Verify with file API: GET /api/space/{workspaceId}/file/apps/{app}/App.tsx
  [ ] Verify importmap: GET /api/space/{workspaceId}/file/importmap.json
  [ ] Check Network tab for multiple React versions if app crashes on mount
  [ ] Use manual Sync from GitHub if past 30 min with no change
```

---

## Reference

### Key Global Injected by Audos

| Global | Value | Use |
|---|---|---|
| `window.__WORKSPACE_ID__` | Workspace UUID string | Platform detection |
| `window.__spaceContext` | NOT injected | Do not use |

### ESM Dependency URL Format

| Pattern | `?deps=` present | React version used |
|---|---|---|
| `https://esm.sh/lucide-react@0.462.0?deps=react@18.3.1` | Yes | React 18.3.1 |
| `https://esm.sh/@tanstack/react-router@1.168.10` | No | Resolved by esm.sh (may be React 19+) |

### File API Endpoints

```
GET https://audos.com/api/space/{workspaceId}/file/importmap.json
GET https://audos.com/api/space/{workspaceId}/file/apps/{appName}/App.tsx
GET https://audos.com/api/space/{workspaceId}/file/apps/{appName}/config.json
```

### Related Docs

- `04-development-workflow.md` — Local vs platform development patterns
- `inbox/INCIDENT-REACT-ERROR-31.md` — Post-mortem for the dual-React debugging session that produced this guide
