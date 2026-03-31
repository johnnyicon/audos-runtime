# Throughline Development Guide
## For Coding Assistants Working with Audos Platform

**Last Updated:** Based on platform investigation
**Workspace ID:** `workspace-8f1ad824-832f-4af8-b77e-ab931a250625`
**Config ID:** `351699`
**Live Domain:** `trythroughline.com`

---

## Overview

This document provides instructions for developing Throughline locally and syncing changes to the Audos platform. The platform has a GitHub sync feature that we need to validate through testing.

---

## Part 1: Architecture Understanding

### What We Know

1. **GitHub repo** is connected to this workspace (confirmed by user)
2. **Developer tab** in Audos has a "Sync from GitHub" option
3. **`.sync-manifest.json`** exists in the workspace and tracks file changes
4. **Folder structure must match** between GitHub and platform

### Workspace Folder Structure (Platform Side)

Based on `.sync-manifest.json`, the platform expects:

```
workspace/
├── config.json                    # Space configuration (apps, theme, settings)
├── Desktop.tsx                    # Main desktop UI component
├── SpaceRuntimeContext.tsx        # Mode-aware context provider
├── types.ts                       # TypeScript type definitions
├── apps/                          # Mini-apps (LOWERCASE folder names!)
│   ├── home/App.tsx              # NOT Home/ - lowercase!
│   ├── briefing/App.tsx
│   ├── signature/App.tsx
│   ├── studio/App.tsx
│   └── [other-apps]/App.tsx
├── components/                    # Shared components
│   ├── AgentChat.tsx
│   ├── EmailGate.tsx
│   ├── FileBrowser.tsx
│   └── Settings.tsx
├── hooks/                         # Custom React hooks
│   └── useSpaceData.ts
├── lib/                           # Utility libraries
│   ├── colors.ts
│   └── friendly-terms.ts
├── data/                          # JSON data files
│   └── *.json
└── integrations/                  # Integration examples (reference only)
    └── */example.tsx
```

### Critical Constraint: Lowercase Folder Names

The `.sync-manifest.json` shows paths like:
- `apps/home/App.tsx` ✅
- `apps/briefing/App.tsx` ✅
- NOT `apps/Home/App.tsx` ❌

**Your GitHub repo folder names must be lowercase.**

---

## Part 2: GitHub Repo Setup

### Required Folder Structure

Your GitHub repo (github.com/johnnyicon/throughline) should have:

```
throughline/
├── apps/
│   ├── home/
│   │   └── App.tsx
│   ├── briefing/
│   │   └── App.tsx
│   ├── signature/
│   │   └── App.tsx
│   └── studio/
│       └── App.tsx
├── components/
│   └── [shared components]
├── hooks/
│   └── useSpaceData.ts
├── lib/
│   └── [utilities]
├── data/
│   └── [json files]
├── config.json
├── Desktop.tsx
├── SpaceRuntimeContext.tsx
└── types.ts
```

### Important: Separate Vite App from Sync Folder

If you're using Vite for local development, keep it separate:

```
throughline/
├── .vite/                    # Vite build output (gitignore)
├── src/                      # Vite source (for local dev only)
│   ├── App.tsx
│   ├── main.tsx
│   └── [vite components]
├── apps/                     # <-- THIS syncs to Audos
├── components/               # <-- THIS syncs to Audos
├── hooks/                    # <-- THIS syncs to Audos
├── config.json               # <-- THIS syncs to Audos
└── [other workspace files]   # <-- THESE sync to Audos
```

The Audos sync should only pick up the workspace-compatible files, not Vite-specific files.

---

## Part 3: Code Constraints

### Import Rules

```tsx
// ✅ ALLOWED - Relative imports
import { useSpaceData } from '../../hooks/useSpaceData';
import { colors } from '../lib/colors';

// ✅ ALLOWED - CDN imports (resolved at compile time)
import { useState, useEffect } from 'react';
import { Activity, Home, Settings } from 'lucide-react';

// ❌ NOT ALLOWED - Node.js/npm packages directly
import express from 'express';
import axios from 'axios';

// ❌ NOT ALLOWED - Alias imports
import { Button } from '@/components/ui/button';
```

### Data Persistence

```tsx
// ✅ CORRECT - Use platform hooks
import { useSpaceData } from '../../hooks/useSpaceData';

const { data, update, loading } = useSpaceData<Item[]>({
  dataFile: 'data/items.json',
  autoFetch: true
});

// ✅ CORRECT - Use WorkspaceDB for database operations
const db = window.useWorkspaceDB();
const results = await db.query('my_table', { filters: [...] });

// ❌ WRONG - localStorage breaks mode isolation
localStorage.setItem('items', JSON.stringify(items));

// ❌ WRONG - Direct file system access
import fs from 'fs';
```

### Component Pattern

```tsx
// ✅ CORRECT - Self-contained with dataFile prop
interface MyAppProps {
  dataFile: string;  // Always accept from config.json
}

export default function MyApp({ dataFile }: MyAppProps) {
  const { data, update, loading } = useSpaceData<MyData[]>({
    dataFile,
    autoFetch: true
  });

  if (loading) return <div>Loading...</div>;

  return (
    <div className="p-4">
      {/* Your UI */}
    </div>
  );
}
```

---

## Part 4: Validation Tests

### Test 1: Verify Sync Mechanism Works

**Goal:** Confirm changes in GitHub appear on the live platform after sync.

**Steps:**

1. **Add a visible test marker to `apps/home/App.tsx`:**
   ```tsx
   // Add this at the top of the component's return statement
   <div className="fixed top-0 left-0 bg-red-500 text-white px-4 py-2 z-50">
     SYNC TEST: {new Date().toISOString()}
   </div>
   ```

2. **Commit and push to GitHub:**
   ```bash
   git add apps/home/App.tsx
   git commit -m "Test: Add sync verification marker"
   git push origin main
   ```

3. **Trigger sync in Audos:**
   - Go to the Developer tab in Audos
   - Click "Sync from GitHub"
   - Wait for sync to complete

4. **Verify on live site:**
   - Visit https://trythroughline.com
   - Look for the red banner with timestamp
   - If visible → Sync works! ✅
   - If not visible → Check for errors, report findings

5. **Clean up:**
   - Remove the test marker
   - Commit and push
   - Sync again

### Test 2: Check Auto-Sync (Optional)

**Goal:** Determine if sync happens automatically or requires manual trigger.

**Steps:**

1. Make another small, visible change (e.g., change test marker color to blue)
2. Push to GitHub
3. **Do NOT manually trigger sync**
4. Wait 5 minutes
5. Check live site
6. If change appears → Auto-sync works
7. If not → Manual sync required

### Test 3: Verify Branch

**Goal:** Confirm which branch is being synced.

**Steps:**

1. Create a test branch: `git checkout -b test-branch`
2. Make a visible change
3. Push: `git push origin test-branch`
4. Trigger sync
5. If change appears → Syncs from current branch or all branches
6. If not → Syncs only from main

---

## Part 5: Backend APIs

Throughline has custom server functions (hooks) for backend operations.

### Base URL

```
https://audos.com/api/hooks/execute/workspace-351699/{endpoint}
```

### Available Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/db-api` | POST | Database operations (query, insert, update, delete) |
| `/ai-api` | POST | AI text generation |
| `/email-api` | POST | Send emails |
| `/storage-api` | POST | File storage operations |
| `/scheduler-api` | POST | Schedule tasks |
| `/web-api` | POST | Web search and scraping |
| `/crm-api` | POST | Contact management |
| `/analytics-api` | POST | Track events, get funnel metrics |

### Example: Database Query

```typescript
const response = await fetch('https://audos.com/api/hooks/execute/workspace-351699/db-api', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    action: 'query',
    table: 'speakers',
    filters: [{ column: 'status', operator: 'eq', value: 'active' }]
  })
});

const { data } = await response.json();
```

### Example: AI Generation

```typescript
const response = await fetch('https://audos.com/api/hooks/execute/workspace-351699/ai-api', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    action: 'generate',
    prompt: 'Write interview questions for a tech founder',
    maxTokens: 500
  })
});

const { text } = await response.json();
```

---

## Part 6: Development Workflow Summary

### Recommended Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                    DEVELOPMENT PIPELINE                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   1. LOCAL DEVELOPMENT                                          │
│   ────────────────────                                          │
│   - Edit files in GitHub repo (github.com/johnnyicon/throughline)
│   - Use Vite for fast local iteration if needed                 │
│   - Ensure folder structure matches platform expectations       │
│   - Use relative imports only                                   │
│                                                                 │
│   2. VERSION CONTROL                                            │
│   ──────────────────                                            │
│   - Commit changes to Git                                       │
│   - Push to main branch (assuming main is synced)               │
│                                                                 │
│   3. SYNC TO PLATFORM                                           │
│   ────────────────────                                          │
│   - Go to Audos Developer tab                                   │
│   - Click "Sync from GitHub"                                    │
│   - (Or wait for auto-sync if it's enabled)                     │
│                                                                 │
│   4. VERIFY LIVE                                                │
│   ──────────────                                                │
│   - Check https://trythroughline.com                            │
│   - Confirm changes appear correctly                            │
│                                                                 │
│   5. BACKEND CALLS                                              │
│   ────────────────                                              │
│   - Use server function endpoints for database, AI, email       │
│   - These work from local dev AND from platform                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Part 7: Questions to Answer After Testing

Please report back on:

1. **Did Test 1 work?** (Manual sync from GitHub)
   - Yes/No
   - Any errors encountered?

2. **Did Test 2 work?** (Auto-sync without manual trigger)
   - Yes/No - is auto-sync enabled?

3. **Which branch is synced?**
   - main only?
   - current branch?
   - all branches?

4. **What's the sync delay?**
   - How long after push does it take to appear?

5. **Any file structure issues?**
   - Did all files sync correctly?
   - Any missing or extra files?

---

## Part 8: Troubleshooting

### Common Issues

**Sync doesn't seem to work:**
- Check that folder names are lowercase
- Verify GitHub repo is actually connected (Developer tab)
- Check for compilation errors in console

**Changes don't appear on live site:**
- May need to clear browser cache
- Check if you're looking at draft vs published
- Verify the correct file was modified

**Import errors after sync:**
- Ensure only relative imports are used
- No `@/` alias paths
- No Node.js-specific imports

**Data not persisting:**
- Use `useSpaceData` hook, not localStorage
- Or use server function endpoints for database operations

---

## Contact

If tests reveal issues or clarify the workflow, update this document and share findings with the team.

**Workspace Owner:** Can ask Otto (AI assistant) in Audos for help
**Platform Issues:** Use the feature request tool in Audos
