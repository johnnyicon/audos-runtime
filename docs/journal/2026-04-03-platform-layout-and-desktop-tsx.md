# Journal: Platform Layout, Desktop.tsx, and App Loading

**Date:** 2026-04-03  
**Session context:** First live deploy of Throughline to production — debugging blank screen and wrong app loading

---

## What We Discovered

### 1. The platform has NO smart defaults — Desktop.tsx controls everything

The Audos runtime does not automatically detect which app should load. All of the following must be explicitly defined in `Desktop.tsx`:

- **Default app on load**: hardcoded `config.apps.find(app => app.id === 'throughline') || config.apps[0]`
- **Which apps appear in sidebar**: explicit filter by ID (`config.apps.filter(app => !['home'].includes(app.id))`)
- **Sidebar presence**: the sidebar JSX is in Desktop.tsx and can be removed if a full-canvas layout is wanted

→ See **INCIDENT-001-DESKTOP-APP-LOADING.md** for full code locations.

### 2. Publish alone is not enough — recompile is required

Changes to `Desktop.tsx` or `config.json` require THREE steps:
1. Edit the file
2. Publish (saves draft → live)
3. **Recompile** (regenerates the compiled bundle)
4. Hard refresh browser (clear site data via DevTools)

Without recompile, the old compiled bundle is still being served.

### 3. There's a pre-existing `apps/throughline/App.tsx` on the platform

An older app with "Dashboard, Guests, Voice, Studio, Settings" navigation and "Architecture Tests" diagnostics was already registered as the primary app. This is NOT our locally-developed app. Our local apps are `apps/briefing/`, `apps/setup/`, `apps/home/`.

**Implication**: the sidebar correctly shows our new apps (Briefing, Setup, etc.) but the "Throughline" default view is the old placeholder. We need to either replace `apps/throughline/App.tsx` with our new home app, or update Desktop.tsx to default to a different app.

### 4. The dock is Desktop.tsx's own sidebar — not a platform chrome bug

Earlier attempts to "remove the dock" were conflicting with Desktop.tsx re-rendering the sidebar. The sidebar IS part of our app layout (T logo, app icons). It is not baked into the platform's outer shell. If we want no sidebar, we remove lines 378-444 (desktop) and 513-547 (mobile) from Desktop.tsx.

### 5. Rendering hierarchy

```
Platform Shell (compiled, not customizable)
  └── Desktop.tsx (our customizable layout layer)
        └── apps/*/App.tsx (individual app components)
```

A platform-level compiled shell MAY exist above Desktop.tsx but this is unconfirmed. The visible sidebar is definitively from Desktop.tsx.

---

## What Changed in Code

- Desktop.tsx: default app logic updated to find `throughline` first; sidebar filter inverted to hide `home`, show all others

---

## What's Still Pending (as of this session)

- [ ] Replace `apps/throughline/App.tsx` old placeholder with a proper home/dashboard view
- [ ] Decide whether to keep sidebar or go full-canvas (remove Desktop.tsx sidebar JSX)
- [ ] Sync local `apps/` changes back to platform via GitHub sync after each dev session
