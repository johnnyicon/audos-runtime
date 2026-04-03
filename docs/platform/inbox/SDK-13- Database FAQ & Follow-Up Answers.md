# SDK-13: Database FAQ & Follow-Up Answers

### Audos Platform SDK Documentation

**Document Version:** 1.0  
**Date:** June 2025  
**Workspace:** Throughline  
**Author:** Otto (AI Assistant)

**Purpose:** Answers to follow-up questions about session scoping, EmailGate identity, REST API tokenization, and multi-tenant data isolation.

---

## Table of Contents

1. [Session Scoping vs. REST-Inserted Data](#1-session-scoping-vs-rest-inserted-data)
2. [EmailGate and Session Identity](#2-emailgate-and-session-identity)
3. [REST db-api Security](#3-rest-db-api-security)
4. [Multi-Tenant Data Isolation](#4-multi-tenant-data-isolation)
5. [Recommended Pattern for Throughline](#5-recommended-pattern-for-throughline)

---

## 1. Session Scoping vs. REST-Inserted Data

### The Question

> `useWorkspaceDB` defaults to `shared: false`, which scopes reads to the current user's `session_id`. Data inserted via the REST API has `session_id = NULL`. Is the intended pattern to always use `shared: true` and rely on manual `user_id`/`org_id` column filters for isolation? Or is there a way to backfill `session_id` on existing rows so session scoping works?

### The Answer

**Yes, for your use case, you should always use `shared: true` and rely on manual filtering.**

Here's why:

#### How `session_id` Scoping Works

| Data Source | `session_id` Value | Visible with `shared: false`? |
|-------------|---------------------|-------------------------------|
| App code (`window.__workspaceDb.insert`) | Auto-populated with current session | ✅ Yes (to that user) |
| Otto (`db_insert`) | `NULL` | ❌ No |
| REST API (`db-api` hook) | `NULL` | ❌ No |
| Server functions (`db.insert`) | `NULL` | ❌ No |

The `session_id` scoping is designed for a simple use case: **each user sees only their own data that they created in the app**. It's not designed for:
- Data pre-populated by admins
- Data shared across team members
- Multi-tenant applications with org-level isolation

#### Can You Backfill `session_id`?

Technically yes, but **it's not recommended**:

```typescript
// You COULD ask Otto to do this:
db_update({
  table: "reels",
  filters: [{ column: "user_id", operator: "eq", value: "john@merkhetventures.com" }],
  data: { session_id: "wses_4144f2109a064615b71040ba895d2607" }
})
```

But this creates problems:
- Sessions are **browser-specific** — if the user logs in from a different device, they get a new session_id
- Sessions can expire or be recreated
- You'd need to constantly map emails to session_ids

#### The Recommended Pattern

```typescript
// ALWAYS use shared: true + manual filters
const { data } = useWorkspaceDB('reels', {
  shared: true,  // Read all data
  filters: [
    { column: 'org_id', operator: 'eq', value: currentUser.orgId }
  ]
});
```

This gives you:
- Full control over isolation logic
- Works with data from any source (app, Otto, API)
- Supports org-level sharing (multiple users in same org)

---

## 2. EmailGate and Session Identity

### The Question

> Does the Throughline app have an EmailGate? When a user authenticates, does the platform capture that email as the session identity? Does `useWorkspaceDB` with `shared: false` scope to that authenticated user's session?

### The Answer

#### Current EmailGate Status

**Yes, Throughline has an EmailGate configured.** It collects:
- Email address (required)
- Name (optional)

#### How Session Identity Works

When a user authenticates through the EmailGate:

1. **A session is created/reused** with a deterministic UUID format:
   ```
   space-{email}-{workspaceId}
   ```
   Example: `space-john@merkhetventures.com-8f1ad824-832f-4af8-b77e-ab931a250625`

2. **The email is captured** as `channelEmail` and `username` on the session

3. **The session is persistent** — if the same email logs in again, they get the same session

#### Verified Session Data

Here are actual sessions from your workspace:

| Email | Session ID | UUID Pattern |
|-------|------------|--------------|
| `john@merkhetventures.com` | `wses_4144f2109a064615b71040ba895d2607` | `space-john@merkhetventures.com-8f1ad824...` |
| `test@throughline.com` | `wses_df978c913404464facbcdf8f9ea1324` | `space-test@throughline.com-8f1ad824...` |
| `test2@throughline.com` | `wses_82220d23c3c94e3c9b33ce98cb3df846` | `space-test2@throughline.com-8f1ad824...` |

#### Does `shared: false` Scope to That User?

**Yes, but only for data that user created in the app.**

When a user inserts data via `window.__workspaceDb.insert()`, the platform automatically populates `session_id` with their current session. Then `shared: false` will filter to only that data.

**But it doesn't work for:**
- Data inserted by Otto (`session_id = NULL`)
- Data inserted via REST API (`session_id = NULL`)
- Data inserted by server functions (`session_id = NULL`)

#### Key Insight

The session identity is **email-based and persistent**, which is good. But the `session_id` scoping is only useful if **all data is created by users in the app**.

For Throughline, where you want to:
- Pre-populate data for users
- Sync data from external sources
- Share data across team members in an org

**You should use `shared: true` + manual `user_id`/`org_id` filters.**

---

## 3. REST db-api Security

### The Question

> The `db-api` endpoint requires no authentication — it's publicly callable by anyone who knows the workspace URL. Is there a way to add an API key or token requirement? Or is the intended model that production apps should use the in-runtime SDK rather than the REST endpoint?

### The Answer

#### Current State: No Built-in Authentication

You're correct — the `db-api` hook is publicly callable. The URL is:

```
https://audos.ai/api/hooks/execute/workspace-8f1ad824-832f-4af8-b77e-ab931a250625/db-api
```

Anyone who discovers this URL could:
- Query your data
- Insert rows
- Update/delete rows

#### You CAN Add API Key Validation

Server functions have access to request headers. You can modify the `db-api` hook to require an API key:

```javascript
// Add this at the top of the db-api hook
const API_KEY = 'your-secret-api-key-here'; // Use a strong random string

const providedKey = request.headers['x-api-key'] || request.headers['authorization']?.replace('Bearer ', '');

if (providedKey !== API_KEY) {
  respond(401, { error: 'Unauthorized: Invalid or missing API key' });
  return;
}

// ... rest of the hook code
```

Then call it with:

```bash
curl -X POST https://audos.ai/api/hooks/execute/workspace-.../db-api \
  -H "Content-Type: application/json" \
  -H "x-api-key: your-secret-api-key-here" \
  -d '{"action": "list-tables"}'
```

#### Limitations of This Approach

| Pros | Cons |
|------|------|
| Simple to implement | API key is hardcoded in the hook code |
| Blocks casual access | No key rotation without code change |
| Works immediately | No per-user keys or rate limiting |

#### The Intended Model

You're right about the intended usage:

- **Production apps** → Use the in-runtime SDK (`useWorkspaceDB`, `window.__workspaceDb`)
- **Server-side logic** → Use server functions (hooks) with `db.query()`, `db.insert()`, etc.
- **External integrations** → Use the REST API with a custom API key check

#### Recommendation

If you need external API access, **add API key validation to the `db-api` hook**. Want me to update it for you?

---

## 4. Multi-Tenant Data Isolation

### The Question

> We're building Throughline as a tool for multiple podcast hosts — each host is a separate "org." Is column-based isolation using `user_id` and `org_id` fields the correct pattern? Or should each org have their own separate workspace?

### The Answer

#### Both Approaches Are Valid

| Approach | Pros | Cons |
|----------|------|------|
| **Column-based isolation** (current) | Simpler to manage, shared codebase, easier cross-org reporting | Requires discipline to always filter, risk of data leaks if filter missed |
| **Separate workspaces per org** | Complete isolation, no risk of cross-contamination | More management overhead, code duplication, harder to update |

#### For Throughline: Column-Based Is Correct

Your current approach is the right one. Here's why:

1. **You're building a SaaS product**, not provisioning isolated instances
2. **You want shared features** across all orgs (same code, same UI)
3. **You may want cross-org insights** later (benchmarks, aggregates)
4. **Management is simpler** — updates apply to everyone immediately

#### When to Use Separate Workspaces

Separate workspaces make sense when:
- Each org needs **custom branding** (logo, colors, domain)
- Each org needs **custom features** or apps
- You have **regulatory requirements** for data isolation (HIPAA, etc.)
- Orgs are **large enterprises** with different needs

#### Best Practices for Column-Based Isolation

1. **Always filter at the data layer** — never rely on UI to hide data

2. **Create a custom hook** that wraps `useWorkspaceDB` with automatic filtering:

   ```typescript
   // hooks/useOrgDB.ts
   function useOrgDB(table: string, options = {}) {
     const { currentUser } = useAuth(); // Get current user from context
     
     return useWorkspaceDB(table, {
       ...options,
       shared: true,
       filters: [
         { column: 'org_id', operator: 'eq', value: currentUser.orgId },
         ...(options.filters || [])
       ]
     });
   }
   ```

3. **Add `org_id` to all inserts** automatically:

   ```typescript
   // Wrapper for inserts
   async function insertWithOrg(table: string, data: any) {
     const { currentUser } = useAuth();
     return window.__workspaceDb.from(table).insert({
       ...data,
       user_id: currentUser.email,
       org_id: currentUser.orgId
     });
   }
   ```

4. **Validate on updates/deletes** — ensure users can only modify their org's data

---

## 5. Recommended Pattern for Throughline

Based on all the above, here's the recommended architecture:

### Data Model

```
┌─────────────────────────────────┐
│ Every table has:               │
│ - id (auto)                     │
│ - created_at (auto)             │
│ - session_id (auto, ignore it)  │
│ - user_id (TEXT, email)         │
│ - org_id (TEXT, org slug)        │
└─────────────────────────────────┘
```

### App Code Pattern

```typescript
// 1. Get current user from EmailGate context
const currentUser = {
  email: window.__spaceContext?.username || 'unknown',
  orgId: 'sow-good-to-grow-good' // Look this up from a mapping table
};

// 2. Always query with shared: true + org_id filter
const { data: reels } = useWorkspaceDB('reels', {
  shared: true,
  filters: [
    { column: 'org_id', operator: 'eq', value: currentUser.orgId }
  ]
});

// 3. Always include user_id and org_id on inserts
await window.__workspaceDb.from('reels').insert({
  title: 'New Reel',
  status: 'draft',
  user_id: currentUser.email,
  org_id: currentUser.orgId
});
```

### User-Org Mapping

You'll need a way to map emails to orgs. Options:

1. **Hardcoded mapping** (simplest for now):
   ```typescript
   const ORG_MAP = {
     'john@merkhetventures.com': 'sow-good-to-grow-good',
     'cohost@example.com': 'sow-good-to-grow-good',
     // ...
   };
   ```

2. **Database table** (more flexible):
   ```typescript
   // Create an org_members table
   const { data: membership } = useWorkspaceDB('org_members', {
     shared: true,
     filters: [{ column: 'email', operator: 'eq', value: currentEmail }]
   });
   const orgId = membership?.[0]?.org_id;
   ```

---

## Summary

| Question | Answer |
|----------|--------|
| Should we use `shared: true`? | **Yes, always** — then filter by `org_id` |
| Can we backfill `session_id`? | Technically yes, but **don't** (sessions are unstable) |
| Does EmailGate capture identity? | **Yes** — email is stored as `channelEmail` and `username` |
| Is `shared: false` useful? | Only for data created by that user in the app |
| Can we secure the REST API? | **Yes** — add API key validation to the hook |
| Separate workspaces or column-isolation? | **Column-isolation** is correct for SaaS |

---

**SDK Document ID:** SDK-13  
**Related Documents:** SDK-12 (Database Management API)