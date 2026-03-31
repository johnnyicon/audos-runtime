# Throughline Development Guide

**Last Updated:** 2026-03-31 (confirmed via live testing)
**Workspace ID:** `8f1ad824-832f-4af8-b77e-ab931a250625`
**Config ID:** `351699`

---

## Confirmed Development Pipeline

```
GitHub Repo                        Audos Platform
──────────────────────────         ──────────────────────
audos-workspace/               →   / (workspace root)
  apps/home/App.tsx             →   apps/home/App.tsx ✅
  apps/briefing/App.tsx         →   apps/briefing/App.tsx
  components/                   →   components/
  hooks/                        →   hooks/
  lib/                          →   lib/
  Desktop.tsx                   →   Desktop.tsx

src/  (local Vite dev only — NOT synced)
```

**The workflow:**
1. Edit files inside `audos-workspace/` locally
2. Commit and push to `main` on GitHub
3. Platform auto-syncs via webhook — no manual trigger needed

---

## What Syncs vs What Doesn't

| Path | Syncs? | Notes |
|------|--------|-------|
| `audos-workspace/apps/` | ✅ Yes | Mini-app components |
| `audos-workspace/components/` | ✅ Yes | Shared UI components |
| `audos-workspace/hooks/` | ✅ Yes | Custom React hooks |
| `audos-workspace/lib/` | ✅ Yes | Utilities |
| `audos-workspace/tools/` | ✅ Yes | Internal dashboards |
| `audos-workspace/Desktop.tsx` | ✅ Yes | Main space layout |
| `audos-workspace/SpaceRuntimeContext.tsx` | ✅ Yes | Context provider |
| `audos-workspace/config.json` | ✅ Yes | Space configuration |
| `audos-workspace/landing-pages/` | ❌ No | Otto-managed only |
| `src/` | ❌ No | Local Vite dev, not synced |

---

## Code Constraints

### Imports

```tsx
// ✅ Relative imports
import { useSpaceData } from '../../hooks/useSpaceData';
import { colors } from '../lib/colors';

// ✅ Platform-available packages (React, lucide-react, etc.)
import { useState } from 'react';
import { Activity } from 'lucide-react';

// ❌ Node.js / npm packages
import express from 'express';

// ❌ Alias imports
import { Button } from '@/components/ui/button';
```

### Data Persistence

```tsx
// ✅ Platform hook for JSON data files
import { useSpaceData } from '../../hooks/useSpaceData';
const { data, update } = useSpaceData<Item[]>({ dataFile: 'data/items.json', autoFetch: true });

// ✅ WorkspaceDB for database tables
const db = window.useWorkspaceDB();
const results = await db.query('my_table', { filters: [...] });

// ❌ localStorage — breaks mode isolation
localStorage.setItem('items', JSON.stringify(items));
```

### Folder Names

Folder names must be **lowercase**:
- `apps/home/App.tsx` ✅
- `apps/Home/App.tsx` ❌

---

## App Component Pattern

```tsx
interface MyAppProps {
  dataFile: string; // passed from config.json
}

export default function MyApp({ dataFile }: MyAppProps) {
  const { data, update, loading } = useSpaceData<MyData[]>({
    dataFile,
    autoFetch: true
  });

  if (loading) return <div>Loading...</div>;

  return <div className="p-4">{/* UI */}</div>;
}
```

---

## Backend API Calls

All server function endpoints are available from both local dev and from within the platform.

**Base URL:** `https://audos.com/api/hooks/execute/workspace-351699`

See [`throughline-api-reference.md`](./throughline-api-reference.md) for the full endpoint list.

---

## What Otto Manages (Do Not Edit Locally)

- **Landing pages** — use `delegate_landing_page_edit` via Otto
- **workspace-branding.json** — use Otto to update
- **Domain config** — platform-managed
- **Database table schemas** — create via Otto using `db_create_table`
