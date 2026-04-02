# SDK-10: GitHub Sync + New App Creation — Investigation Report

**Date:** April 2, 2025
**Workspace:** Throughline (workspace-351699)
**Issue:** New app added via GitHub sync not appearing in dock

---

## Executive Summary

When a coding assistant added a new app ("Throughline") via GitHub sync, the app did not appear in the dock despite the config.json entry and source code being successfully synced. After extensive investigation, we discovered:

1. **GitHub sync DOES work** for config.json and source files (this is improved from before)
2. **The compiled bundle is NOT created** — the `.published-source/apps/{appId}/` folder is never generated for new apps added via GitHub
3. **Creating the app via `delegate_app_edit`** with `appId: "new"` DOES create the compiled bundle
4. **BUT the app is created in DRAFT mode** — it must be explicitly published to go live

**The fix required 3 steps:**
1. Delete the GitHub-synced app entry
2. Recreate via `delegate_app_edit` with `appId: "new"`
3. Publish the draft with `publish_draft`

---

## Timeline of Events

### Step 1: Coding Assistant's GitHub Push

The coding assistant pushed a new app with this prompt assumption:

```
Please create a new app in this workspace with the following config:
  - id: throughline
  - name: Throughline
  - icon: Sparkles
  - component: apps/throughline/App.tsx

The component file already exists in the repo from the latest GitHub sync.
Just register the app record so it appears in the dock.
```

**What the assistant assumed:** That adding a config.json entry would be sufficient.

**What actually happened:** The GitHub sync successfully added:
- ✅ Entry in `config.json`
- ✅ Source code at `apps/throughline/App.tsx`
- ❌ NO compiled bundle at `.published-source/apps/throughline/`

### Step 2: Initial Diagnosis

After the user reported the app wasn't showing, I verified:

```bash
# App registered in platform
$ mcp list_apps
→ "throughline" present in list ✅

# Source code exists
$ ls apps/throughline/
→ App.tsx exists ✅

# Compiled bundle missing
$ ls .published-source/apps/ | grep throughline
→ NOT FOUND ❌
```

The Desktop.tsx filter logic was checked — no exclusion for "throughline". The issue was confirmed: **the platform bundler doesn't compile apps added via config.json edits from GitHub**.

### Step 3: Failed Attempts

#### Attempt 1: Recompile
```
mcp__0__recompile()
→ "✅ Recompilation successful"
→ .published-source/apps/throughline/ still NOT created
```
**Result:** Recompile doesn't create new app bundles.

#### Attempt 2: Edit existing app to force rebuild
```
delegate_app_edit(appId: "throughline", task: "trigger rebuild...")
→ Job completed
→ .published-source/apps/throughline/ still NOT created
```
**Result:** Editing a "ghost" app (registered but not compiled) doesn't create the bundle.

### Step 4: Successful Fix

#### Step 4a: Delete the ghost app
```
delete_app(appId: "throughline", confirmDelete: true)
→ "✅ App deleted"
```

#### Step 4b: Create fresh via platform
```
delegate_app_edit(appId: "new", appName: "Throughline", task: "Create the app...")
→ Job #9472 completed
→ .published-source/apps/throughline/ CREATED ✅
```

#### Step 4c: Still not visible — discovered draft mode
```bash
# Compiled bundle now exists
$ ls .published-source/apps/throughline/
→ App.tsx (12,666 bytes) ✅

# But app still not in dock after refresh
```

#### Step 4d: Publish the draft
```
publish_draft(target: "app", appId: "throughline")
→ "Published successfully! Your changes are now live."
```

**Result:** App now visible in dock ✅

---

## Root Cause Analysis

### Issue 1: GitHub Sync Doesn't Trigger Bundler for New Apps

**Current behavior:**
- GitHub sync updates `config.json` ✅
- GitHub sync copies source files to `apps/{appId}/` ✅
- GitHub sync does NOT trigger the bundler to create `.published-source/apps/{appId}/` ❌

**Why this matters:**
The platform's app loading system requires compiled bundles in `.published-source/`. The `Desktop.tsx` receives apps as a `Record<string, LazyExoticComponent<any>>` prop — apps without compiled bundles are simply not included in this record.

### Issue 2: Apps Created via Subagent Default to Draft Mode

**Current behavior:**
- `delegate_app_edit` with `appId: "new"` creates the app successfully
- The app is created in **draft mode**
- Draft apps are not visible on the live site
- Explicit `publish_draft` call is required

**Why this matters:**
Users (and coding assistants) expect that "creating an app" means it will be visible. The draft/publish model is useful for review workflows but creates confusion when the expectation is immediate visibility.

### Issue 3: Editing a "Ghost" App Doesn't Create the Bundle

**Current behavior:**
- If an app is registered in `config.json` but has no compiled bundle, it's a "ghost"
- Running `delegate_app_edit` on a ghost app writes source code but doesn't create the bundle
- The subagent reports success even though the app remains non-functional

**Why this matters:**
This creates a confusing state where the platform says the app exists, the subagent says the edit succeeded, but the app doesn't work.

---

## What Was Fixed vs. Still Broken

### ✅ Fixed (Improved from Previous Investigation)

| Aspect | Before | Now |
|--------|--------|-----|
| GitHub sync updates config.json | ❌ Rejected | ✅ Works |
| GitHub sync copies source files | ❌ Rejected | ✅ Works |
| Can create apps without disabling GitHub mode | ❌ Had to disable | ✅ Works via delete + create flow |

### ❌ Still Broken

| Issue | Impact | Suggested Fix |
|-------|--------|---------------|
| GitHub sync doesn't trigger bundler | New apps via GitHub don't appear | Bundler should watch for new app entries in config.json |
| New apps default to draft mode | Confusion about why app isn't visible | Either auto-publish or clearly surface draft state |
| Editing ghost apps silently fails | Subagent reports success but app doesn't work | Detect ghost state and auto-create bundle |
| No error message for missing bundle | Hard to diagnose | Platform should warn when app has no bundle |

---

## Workaround Procedure

Until these issues are fixed, here's the reliable procedure for adding new apps when GitHub sync is enabled:

### For Platform Operators (Otto)

```
1. User reports app added via GitHub isn't showing

2. Verify the ghost state:
   - list_apps → app IS in list
   - Check .published-source/apps/{appId}/ → folder NOT present

3. Delete the ghost:
   delete_app(appId: "{appId}", confirmDelete: true)

4. Create fresh via platform:
   delegate_app_edit(
     appId: "new",
     appName: "{AppName}",
     task: "Create the app with [specifications]...",
     conversationContext: "Recreating app that was added via GitHub sync..."
   )

5. Wait for job completion, then publish:
   publish_draft(target: "app", appId: "{appId}")

6. User refreshes browser → app visible
```

### For Coding Assistants (External)

When adding new apps to an Audos workspace via GitHub:

```
⚠️ IMPORTANT: GitHub sync alone is NOT sufficient for new apps.

After pushing your changes:
1. Tell the user: "I've added the app config and source code.
   Please ask Otto to 'publish the new Throughline app'
   so the platform compiles and deploys it."

2. DO NOT assume the app will appear automatically.

3. The platform needs to:
   - Create the compiled bundle
   - Publish from draft to live
```

---

## Recommended Platform Fixes

### Priority 1: Auto-bundle new apps on sync

When GitHub sync detects a new app entry in config.json:
1. Check if `.published-source/apps/{appId}/` exists
2. If not, trigger the bundler to compile the app
3. Log the bundle creation for debugging

### Priority 2: Surface draft state clearly

Options:
- Auto-publish apps created via `delegate_app_edit`
- Return explicit "created as draft — call publish_draft to go live" message
- Add a `publish: true` parameter to `delegate_app_edit`

### Priority 3: Detect and fix ghost apps

When `delegate_app_edit` is called on an existing app:
1. Check if `.published-source/apps/{appId}/` exists
2. If not, treat it as a new app creation (create the bundle)
3. Warn: "App was registered but had no compiled bundle — recreating"

### Priority 4: Add diagnostic tooling

New MCP tool: `diagnose_app(appId)`
- Returns: config entry status, source file status, compiled bundle status, draft/published status
- Helps quickly identify where the pipeline is broken

---

## Files Referenced

| File | Purpose |
|------|---------|
| `config.json` | App registry — lists all apps with id, name, icon, component path |
| `apps/{appId}/App.tsx` | Source code — React component for the app |
| `.published-source/apps/{appId}/App.tsx` | Compiled bundle — what the platform actually loads |
| `Desktop.tsx` | Platform shell — receives compiled apps as props, renders dock |

---

## Appendix: Full Command Log

```
# Initial state check
list_apps → throughline present
ls apps/throughline/ → App.tsx exists
ls .published-source/apps/ | grep throughline → NOT FOUND

# Attempt 1: Recompile
recompile() → success
ls .published-source/apps/ | grep throughline → STILL NOT FOUND

# Attempt 2: Edit existing
delegate_app_edit(appId: "throughline", ...) → Job completed
ls .published-source/apps/ | grep throughline → STILL NOT FOUND

# Attempt 3: Delete and recreate
delete_app(appId: "throughline", confirmDelete: true) → success
delegate_app_edit(appId: "new", appName: "Throughline", ...) → Job #9472
ls .published-source/apps/ | grep throughline → FOUND ✅

# Still not visible after refresh
publish_draft(target: "app", appId: "throughline") → success

# App now visible ✅
```

---

## Document Info

- **Author:** Otto (via Claude)
- **Version:** 1.0
- **Status:** Ready for team review
- **Next Steps:** Share with platform team for prioritization of fixes
