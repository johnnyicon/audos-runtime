# Audos Platform Architecture

## Overview

Audos is a **React-based platform** with a custom runtime that provides:
- Frontend: React 18+ with TypeScript
- Styling: Tailwind CSS (built-in)
- State: React hooks + optional custom hooks
- Backend: REST APIs via server functions (hooks)
- Database: PostgreSQL with workspace-scoped schemas

## Can You Use ShadCN/Tailwind V4/TanStack?

| Library | Compatible? | Notes |
|---------|-------------|-------|
| **Tailwind CSS** | ✅ YES | Already included in the runtime. V3 syntax confirmed. V4 untested but likely works. |
| **ShadCN UI** | ⚠️ PARTIAL | ShadCN components are just React + Tailwind. You can copy component code directly into your apps. The `cnpm add` CLI won't work, but manual copy does. |
| **TanStack Query** | ⚠️ PARTIAL | You can use it for client-side state/if you bundle it. The platform doesn't pre-include it. |
| **TanStack Router** | ❌ NO | The platform has its own routing (hash-based via Desktop.tsx). |

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        AUDOS PLATFORM                                    │
├─────────────────────────────────────────────────────────────────┤│                         FRONTEND (Browser)                                │
│                                                                        │
│  ┌─────────────┐    ┌───────────────┐    ┌───────────────┐     │
│  │Your App Code│    │Desktop.tsx Shell│    │Platform Hooks│     │
│  │(React+TS)   │    │(Navigation/Dock)│    │(useSpaceFiles│     │
│  └─────────────┘    └───────────────┘    │ useBranding) │     │
│                                                 └───────────────┘     │
│                                   │ Tailwind CSS is available globally │ │
├─────────────────────────────────────────────────────────────────┤
│                         BACKEND (Server Functions)                       │
│                                                                          │
│  ┌─────────────┐    ┌───────────────┐    ┌───────────────┐     │
│  │ db-api       │    │ ai-api         │    │ email-api      │     │
│  │ (Database)  │    │ (AI Generation│    │ (Send Emails) │     │
│  └─────────────┘    └───────────────┘    └───────────────┘     │
│                                                                          │
│  ┌─────────────┐    ┌───────────────┐    ┌───────────────┐     │
│  │ web-api     │    │ scheduler-api │    │ storage-api   │     │
│  │ (Fetch URLs) │    │ (Cron Jobs)     │    │ (File Uploads) │     │
│  └─────────────┘    └───────────────┘    └───────────────┘     │
│                                                                          │
└─────────────────────────────────────────────────────────────────┘
```

## Frontend ↔ Backend Communication

**There are TWO ways to communicate with the backend:**

### Option 1: Platform Hooks (Internal)

```tsx
// These hooks are injected by the Audos runtime
import { useSpaceFiles } from '@audos/hooks';
import { useWorkspaceDB } from '@audos/hooks';
import { useBranding } from '@audos/hooks';

function MyApp() {
  const { data, save } = useSpaceFiles('my-data.json');
  const { query, insert } = useWorkspaceDB('my_table');
  const { colors, logo } = useBranding();
}
```

### Option 2: REST APIs (External & Local)

```tsx
// These work from ANYWHERE - local dev, external apps, etc.
const WORKSPACE_ID = '8f1ad824-832f-4af8-b77e-ab931a250625';
const API_BASE = 'https://audos.app'; // or your custom domain

async function queryDatabase(table, filters = {}) {
  const response = await fetch(`${API_BASE}/api/hooks/execute/workspace-${WORKSPACE_ID}/db-api`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      action: 'query',
      table,
      ...filters
    })
  });
  return response.json();
}
```

## Key Insight: You Don't NEED the Hooks

**The platform hooks are convenience wrappers around REST APIs.**

If you prefer to use TanStack Query or plain `fetch`, you can call the same backend APIs directly:

| Platform Hook | Equivalent REST API |
|---------------|---------------------|
| `useWorkspaceDB()` | `POST /api/hooks/execute/workspace-{id}/db-api` |
| `useSpaceFiles()` | `POST /api/hooks/execute/workspace-{id}/storage-api` |
| AI generation | `POST /api/hooks/execute/workspace-{id}/ai-api` |
| Send email | `POST /api/hooks/execute/workspace-{id}/email-api` |
| Fetch web page | `POST /api/hooks/execute/workspace-{id}/web-api` |
| Schedule task | `POST /api/hooks/execute/workspace-{id}/scheduler-api` |

## What the Platform Provides (that you'd need to mock locally)

| Feature | What It Does | Mock Strategy |
|---------|--------------|---------------|
| **Branding** | Injects colors, fonts, logo | Hardcode or load from JSON file |
| **Session** | Visitor tracking, email capture | Mock with localStorage |
| **Desktop** | Dock/navigation shell | Build your own nav component |
| **EmailGate** | Entry screen with email capture | Skip locally or build simple mock |
| **Compilation** | TSX → optimized JS bundle | Vite handles this locally |

## Recommendation for Local Development

1. **Use REST APIs directly** instead of platform hooks
2. **Use ShadCN + Tailwind** for UI (copy components manually)
3. **Use TanStack Query** for data fetching/caching if preferred
4. **Create a thin mock layer** for branding/session
5. **Accept visual differences** - the platform applies its own theming