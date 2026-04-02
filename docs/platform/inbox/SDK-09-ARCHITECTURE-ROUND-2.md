# Audos Platform — Architecture Answers (Round 2)

Answers to follow-up architecture questions based on codebase review.

**Date**: January 2025  
**Workspace**: Throughline  
**SDK Version**: 0.9

---

## Quick Summary

| Question | Answer |
|----------|--------|
| **Q1: Single App vs. Multi-App?** | ✅ **YES - Single app is viable**. Apps are just React components. You can build one app with internal routing. |
| **Q2: Eliminating two codebases?** | ✅ **`audos-workspace/` is the only source of truth**. Use the mock layer for local dev. |
| **Q3: Custom UI with platform backend?** | ✅ **YES - No UI dependencies**. Use ShadCN, Tailwind, any router. Minimal shell requirements. |
| **Q4: useSession & useBranding?** | useSession = contact/plan info, useBranding = ❌ **no hook** — branding via `config.json` |
| **Q5: "Doc" primitive?** | ❌ **No built-in doc type**. Use `useWorkspaceDB` for persistence. |

---

## Question 1 — Single App vs. Multi-App

### Can we consolidate all of Throughline into a single Audos app?

**✅ YES.** Apps are just React components with no special isolation.

#### Architectural Analysis

After examining the codebase, here's what I found:

1. **Apps are just React components** — The `config.json` defines apps as pointers to `.tsx` files:
   ```json
   {
     "apps": [
       { "id": "home", "name": "Home", "component": "apps/home/App.tsx" },
       { "id": "studio", "name": "Studio", "component": "apps/studio/App.tsx" }
     ]
   }
   ```

2. **No permissions/isolation between apps** — All apps run in the same React context (`SpaceRuntimeProvider`). They share the same session, the same database access, the same everything.

3. **Apps are loaded dynamically** into a single window via `Desktop.tsx`:
   ```tsx
   {isAppWindow && CurrentApp && currentAppConfig && (
     <Suspense fallback={<LoadingSpinner />}>
       <CurrentApp appConfig={currentAppConfig} dataFile={currentAppConfig.dataFile} />
     </Suspense>
   )}
   ```

#### What a Single-App Architecture Looks Like

```json
// config.json — one app entry
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

```tsx
// apps/throughline/App.tsx — own internal routing
import { useState } from 'react';

// Sub-pages as components
import Home from './pages/Home';
import Studio from './pages/Studio';
import Briefing from './pages/Briefing';
import Signature from './pages/Signature';
import Setup from './pages/Setup';

export default function ThroughlineApp() {
  const [page, setPage] = useState<string>('home');

  return (
    <div className="flex h-full">
      {/* Your own navigation */}
      <nav className="w-64 bg-gray-50 border-r">
        <button onClick={() => setPage('home')}>Home</button>
        <button onClick={() => setPage('studio')}>Studio</button>
        <button onClick={() => setPage('briefing')}>Briefing</button>
        <button onClick={() => setPage('signature')}>Signature</button>
        <button onClick={() => setPage('setup')}>Setup</button>
      </nav>

      {/* Content area */}
      <div className="flex-1 overflow-auto">
        {page === 'home' && <Home />}
        {page === 'studio' && <Studio />}
        {page === 'briefing' && <Briefing />}
        {page === 'signature' && <Signature />}
        {page === 'setup' && <Setup />}
      </div>
    </div>
  );
}
```

#### Dock Navigation - Your Choice

| Option | How It Works |
|--------|--------------|
| **Use platform dock** | Keep multiple apps in `config.json`. The dock switches between them. |
| **Hide dock, use own nav** | One app in `config.json`. The dock shows only that app. You build internal nav. |
| **Hybrid** | One "Throughline" app + a separate Settings app. Minimal dock, internal routing for core features. |

**Recommended**: The hybrid approach. One core app with internal routing, Settings remains separate (it's a platform component).

#### Using React Router or TanStack Router

**✅ YES** - You can use any React router inside your app. But:

| Router | Notes |
|--------|-------|
| **Hash-based routing** (`HashRouter`) | ✅ Recommended. Platform already uses hashes for deep links. |
| **BrowserRouter** (history API) | ⚠️ May conflict with platform URL handling. |
| **TanStack Router** | ⚠️ Avoid. The platform has its own routing; TanStack is overkill. |

#### Conclusion

– *"Apps" are just a scaffolding convention**. One app with internal routing is equally valid.
- No performance, permissions, or isolation reasons to split.
- You manage your own navigation and state.

---

## Question 2 — Eliminating the Two-Codebase Problem

### What is the intended relationship between `audos-workspace/` and local dev?

**– `audos-workspace/` is the single source of truth.**

**The correct architecture:**

```
audos-workspace/
  ├── apps/                     # Source of truth for all apps
  │   ├── home/App.tsx
  │   ├── studio/App.tsx
  │   ├── briefing/App.tsx
  │   └── signature/App.tsx
  ├── config.json               # App registry
  ├── Desktop.tsx                # Platform shell (don't modify)
  ├── SpaceRuntimeContext.tsx   # Platform context (don't modify)
  ├── lib/colors.ts             # Design system
  └── integrations/             # SDK docs

src/                                 # LOCAL DEV ONLY - MOCK LAYER
  ├── lib/audos-api.ts          # Mock API client
  ├── lib/audos-hooks.ts        # Mock hooks
  └── .env.local                # VITE_USE_REMOTE_API=true/false
```

**Your current `src/pages/apps/` shouldn't exist.**

#### Correct Local Dev Workflow

1. **Edit files in `audos-workspace/apps/`**
2. **Import mock layer that switches based on environment**

```tsx
// lib/audos-sdk.ts — IMPORT THIS IN YOUR APPS
const IS_LOCAL = !import.meta.env.VITE_USE_REMOTE_API;
const BASE_URL = IS_LOCAL ? '' : 'https://your-workspace.audos.app';

export async function dbQuery(table: string, options?: any) {
  if (IS_LOCAL) {
    // Use localStorage mock
    return JSON.parse(localStorage.getItem(table) || '[]');
  }
  // Use real API
  return fetch(`${BASE_URL}/api/hooks/execute/workspace-${WORKSPACE_ID}/db-api`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ action: 'query', table, ...options })
  }).then(r => r.json());
}
```

#### Does the Mock Layer Cover Everything?

| Hook/API | Mock Available | Notes |
|----------|----------------|-------|
| `useWorkspaceDB` | ✅ Yes | Use localStorage or IndexedDB |
| `window.__workspaceDb` | ✅ Yes | Same - mock the global |
| `useSpaceRuntime` (~session) | ✅ Yes | Return mock session data |
| `useBranding` | ❌ **Doesn't exist** | Branding comes from `config.json` |
| REST APIs (db-api, ai-api, etc.) | ✥ Partial | Mock or use real APIs via env flag |

#### GitHub Sync Note

When GitHub sync is enabled:
- Pushing to `audos-workspace/apps/*.tsx` auto-deploys to the platform
- New apps **cannot** be created via GitHub (see SDK-01 docs) — create via Otto first, then edit via GitHub

---

## Question 3 — Using Platform Capabilities Without Platform UI Conventions

### Can we build a React app with no dependency on Audos UI components?

**✅ YES.** Apps are pure React components. The platform only injects:

1. `SpaceRuntimeContext` — Provides session, file ops, event tracking
2. `window.__workspaceDb` and `window.useWorkspaceDB` — Database SDK
3. Global Tailwind CSS

#### Minimal Shell Requirements

Your app must:

1. **Export a default React component**

   ```tsx
   export default function MyApp() {
     return <div>Hello</div>;
   }
   ```

2. **NOT mount itself** (no `createRoot`)

3. **Optionally accept props**

   ```tsx
   interface MyAppProps {
     appConfig?: any;
     dataFile?: string;
   }
   export default function MyApp({ appConfig, dataFile }: MyAppProps) { ... }
   ```

That's it. No other requirements.

#### Using ShadCN Components

**✅ Fully supported.** ShadCN components are just React + Tailwind.

```bash
# Copy ShadCN components manually to:
audos-workspace/components/ui/
  ├── button.tsx
  ├── input.tsx
  ├── card.tsx
  └── etc.
```

**Potential Conflicts:**

| Area | Conflict? | Resolution |
|------|-----------|------------|
| Tailwind classes | 🟡 Yes | Platform has Tailwind v3 with custom config. V4 may have syntax differences. |
| CSS variables | 🟡 Maybe | ShadCN uses `--primary`, `--accent`, etc. Define them in your app's root. |
| Radix UI primitives | 🟡 Maybe | If ShadCN components import Radix, you need them bundled or via CDN. |

**Recommended approach:**
- Copy ShadCN component files directly (not via CLI)
- Use Tailwind v3 syntax to match platform
- Define CSS variables in your app's root element

#### Routing Libraries

| Library | Supported? | Notes |
|---------|------------|-------|
| Simple state (`useState`) | ✅ Recommended | Lightweight, no conflicts. |
| React Router `HashRouter` | ✅ Works | Platform uses hashes for deep links. |
| React Router `BrowserRouter` | ⚠️ Risky | May conflict with platform URL handling. |
| TanStack Router | ⚠️ Overkill | Heavy for an embedded app. |

#### Using TanStack Query

| Library | Supported? | Notes |
|---------|------------|-------|
| TanStack Query | ✅ Yes | Works great for data fetching/caching. |

```tsx
import { useQuery } from '@tanstack/react-query';

const { data } = useQuery({
  queryKey: ['voice_profiles'],
  queryFn: () => fetch(DB_API_URL, {
    method: 'POST',
    body: JSON.stringify({ action: 'query', table: 'voice_profiles' })
  }).then(r => r.json())
});
```

#### Conclusion

**You can build a standard React + TypeScript + Tailwind + ShadCN application.**

The platform provides:
- Database (PostgreSQL via WorkspaceDB SDK)
- AI generation (`ai-api` hook)
- Email (`email-api` hook)
- File storage (`storage-api` hook)
- Authentication (session via `SpaceRuntimeContext`)

You provide:
- UI components
- Layout
- Routing (internal)
- Styling

---

## Question 4 — Auth and Branding Hooks

### What does `useSession` expose?

There's no `useSession` hook — the equivalent is `useSpaceRuntime()` and `useSubscription()`.

#### `useSpaceRuntime()` — Core Context

```tsx
import { useSpaceRuntime } from '../SpaceRuntimeContext';

const {
  mode,                // 'entrepreneur' | 'customer'
  spaceId,             // Workspace ID
  sessionId,           // User session ID (from EmailGate)
  visitorId,           // Persistent visitor cookie
  config,              // Space config (includes branding)
  isLoading,           // Config loading state
  error,               // Config load error
  readFile,            // Read file from space storage
  writeFile,           // Write file to space storage
  listFiles,           // List files in space storage
  trackEvent,          // Track funnel event
  subscription,        // Subscription state
  checkAppAccess,      // Check if user has access to a tier
} = useSpaceRuntime();
```

#### `useSubscription()` — Subscription State

```tsx
import { useSubscription } from '../SpaceRuntimeContext';

const {
  subscription,        // Full subscription state object
  isPremium,           // true if active subscription or manual override
  isTrial,             // true if in trial period
  isExpired,           // true if trial expired or canceled
  loading,             // Subscription loading state
  trialDaysRemaining,  // Days left in trial
  refreshSubscription, // Refetch subscription status
  checkAppAccess,      // Check access by tier
} = useSubscription();
```

#### Subscription State Object

```ts
interface SubscriptionState {
  status: 'loading' | 'not_registered' | 'trial' | 'trialing' | 'trial_expired' | 'active' | 'canceled' | 'past_due' | 'incomplete';
  planTier: string | null;          // e.g. 'essentials', 'pro'
  email: string | null;
  stripeCustomerId: string | null;
  subscriptionId: string | null;
  trialDaysRemaining: number;
  trialDays: number;
  trialExpired: boolean;
  hasPaymentMethod: boolean;
  contactId: string | null;
  manualOverride: { tier: string; grantedBy: string; reason: string; expiresAt: string | null } | null;
}
```

#### Storing User Preferences

There's no built-in user preferences system. **Use `useWorkspaceDB`** with a `user_preferences` table:

```tsx
// Data is automatically scoped by session_id
const { data: prefs } = (window as any).useWorkspaceDB('user_preferences');
// Each user sees only their own preferences
```

---

### What does `useBranding` expose?

**╌— ⚠️ **There is no `useBranding` hook.*****

Branding comes from `config.json` and is accessed via `useSpaceRuntime().config`:

```tsx
// config.json - Where branding is defined
{
  "desktop": {
    "theme": {
      "gradient": "from-[#1B2A4A]/5 via-[#00D2B4]/5 to-[#6C5CE7]/5",
      "accentColor": "#6C5CE7",
      "dockStyle": "glass"
    },
    "branding": {
      "name": "Throughline",
      "tagline": "Every great show has a throughline. Now so does your production.",
      "headingFont": "DM Sans",
      "logoUrl": "https://..."
    }
  }
}
```

#### Accessing Branding in Your App

```tsx
import { useSpaceRuntime } from '../SpaceRuntimeContext';

const { config } = useSpaceRuntime();

const brandName = config?.desktop?.branding?.name;       // "Throughline"
const tagline = config?.desktop?.branding?.tagline;      // "Every great show..."
const logoUrl = config?.desktop?.branding?.logoUrl;      // URL or undefined
const accentColor = config?.desktop?.theme?.accentColor; // "#6C5CE7"
const font = config?.desktop?.branding?.headingFont;     // "DM Sans"
```

#### Overriding Branding

You can't override branding per-app via config. But you can:

1. **Ignore platform branding entirely** — Define your own constants in your app:

   ```tsx
   // lib/theme.ts — YOUR branding
   export const THEME = {
     primary: '#1B2A4A',
     accent: '#00D2B4',
     highlight: '#6C5CE7',
     font: 'DM Sans',
   };
   ```

2. **Use the design system file** — `lib/colors.ts` already defines Throughline brand colors:

   ```tsx
   import { brand, tw, typography } from '../lib/colors';

   <div className={tw.button.brand}>Click me</div>
   <p style={{ color: brand.primary[600] }}>Text</p>
   ```

---

## Question 5 — The "Doc" Primitive (Revisited)

### Is there a `doc` app type in the Audos workspace config?

**╌— ❌ **No.*****

After searching the codebase, there is no `doc` type in `config.json` or the platform. The only app "types" are implicit (just React components).

#### Persistence for Documents

| Use Case | Recommended Storage |
|----------|---------------------|
| **Permanent documents** (briefings, show notes) | `useWorkspaceDB` — Tables like `guest_briefings`, `show_notes` |
| **Transient drafts** (unsaved edits) | `useSpaceFiles` (`SpaceRuntimeContext.readFile`/`writeFile`) |
| **Real-time collaborative editing** | ❌ Not supported natively — use external service (Y.js, Liveblocks) |

#### Document Data Model Example

```sql
-- guest_briefings table
CREATE TABLE guest_briefings (
  id SERIAL PRIMARY KEY,
  session_id TEXT,                  -- Auto-injected
  created_at TIMESTAMP WITH TIMEX�NE,
  updated_at TIMESTAMP WITH TIMEX�NE,
  
  -- Custom columns
  guest_name TEXT,
  episode_title TEXT,
  recording_date DATE,
  status TEXT,                      -- 'draft' | 'ready' | 'sent'
  content JSONB                     -- Structured briefing data
);
```

```tsx
// Reading briefings
const { data: briefings } = (window as any).useWorkspaceDB('guest_briefings', {
  orderBy: { column: 'created_at', direction: 'desc' },
  limit: 50
});
```

---

## Final Architectural Decision Verdict

> **Build Throughline as a single Audos app with our own internal routing and component library, using platform hooks only for backend services (DB, AI, storage, email).**

**✓ VIABLE.**

### Constraints

1 **No `BrowserRouter`** — Use hash-based routing or simple `useState`.
2. **No direct Tailwind v4 syntax** — Platform uses Tailwind v3.
3. **No `useBranding` hook** — Access branding via `config.desktop.branding`.
4. **New apps can't be created via GitHub sync** — Create via Otto first.

### Minimal Setup

1. **Update `config.json`** to have one app:
   ```json
   { "apps": [{ "id": "throughline", "name": "Throughline", "component": "apps/throughline/App.tsx" }] }
   ```

2. **Build `apps/throughline/App.tsx`** with:
   - Internal routing (state or HashRouter)
   - Your own navigation component
   - ShadCN components in `components/ui/`
   - Tailwind v3 classes

3. **Use platform SDKs for backend**:
   - `window.__workspaceDb` for database
   - REST APIs for AI, email, storage
   - `useSpaceRuntime()` for session/identity

4. **Delete `src/pages/apps/`** — Remove the duplicate local dev stubs.

5. **Set up mock layer** in `src/lib/audos-sdk.ts` that switches between local/remote based on env.

---

## Appendix: Key Files Reference

| File | Purpose |
|------|---------|
| `config.json` | App registry, branding, theme |
| `Desktop.tsx` | Platform shell (dock, window management) |
| `SpaceRuntimeContext.tsx` | Core context (session, config, file ops) |
| `integrations/workspace-db/docs.md` | WorkspaceDB SDK documentation |
| `APP_INTEGRATION_MANIFEST.md` | All 25+ platform integrations |
| `lib/colors.ts` | Throughline design system |
| `SPACE_APP_GUIDE.md` | App development guide |

---

*Generated by Otto — January 2025*