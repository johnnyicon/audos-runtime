# Throughline SDK - Debugging & Known Issues

> Last Updated: June 2025

---

## 🔴 Critical Bugs (Blockers)

### 1. Studio App - Blank White Screen

| Attribute | Value |
|-----------|-------|
| Severity | 🔴 Critical |
| Status | Open |
| Discovered | Browser test (June 2025) |
| URL | https://app.trythroughline.com (Studio app in dock) |

**Symptoms:**
- App renders as complete white/blank screen
- No visible UI elements
- No server-side errors logged
- Other apps (Signature, Home) work correctly

**Likely Causes:**
1. Runtime JavaScript error in component
2. Import/export issue in module bundling
3. Hook error during initial render (e.g. `useWorkspaceDB` throwing)
4. Missing or malformed data causing render failure

---

### 2. Briefing App - Blank White Screen

| Attribute | Value |
|-----------|-------|
| Severity | 🔴 Critical |
| Status | Open |
| Discovered | Browser test (June 2025) |
| URL | https://app.trythroughline.com (Briefing app in dock) |

**Symptoms:**
- Same as Studio app - complete blank white screen
- No UI, no server errors

**Likely Causes:**
- Same as Studio app

---

## 🔍 Debugging Strategy

### Step 1: Check Browser Console

1. Open https://app.trythroughline.com
2. Log in with test email
3. Open browser DevTools (F12)
4. Navigate to Studio app
5. Check Console tab for errors

**Common Errors to Look For:**
```
Uncaught TypeError: Cannot read properties of undefined
Uncaught ReferenceError: X is not defined
Chunk load error
Module not found
```

### Step 2: Verify Component Exports

Check that `config.json` has correct paths:

```json
{
  "apps": [
    {
      "id": "studio",
      "name": "Studio",
      "component": "Studio",
      "path": "apps/studio/App.tsx"
    }
  ]
}
```

Verify the component file exists and exports correctly:

```typescript
// apps/studio/App.tsx
// MUST have default export
const Studio = () => { ... };
export default Studio;
```

### Step 3: Add Error Boundary

Wrap the component in an error boundary to catch render errors:

```typescript
import React from 'react';

class ErrorBoundary extends React.Component {
  state = { hasError: false, error: null };

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="p-4 bg-red-50 border border-red-200 rounded">
          <h2>Something went wrong</h2>
          <pre>{this.state.error?.toString()}</pre>
        </div>
      );
    }
    return this.props.children;
  }
}

const Studio = () => {
  return (
    <ErrorBoundary>
      {/* Your actual component content */}
    </ErrorBoundary>
  );
};
```

### Step 4: Check Hook Usage

If using `useWorkspaceDB` or `useSpaceFiles`, ensure they handle loading/error states:

```typescript
const Studio = () => {
  const { data, isLoading, error } = useWorkspaceDB('reels');

  // ALWAYS handle loading state
  if (isLoading) {
    return <div>Loading...</div>;
  }

  // ALWAYS handle error state
  if (error) {
    return <div>Error: {error.message}</div>;
  }

  // ALWAYS handle empty data
  if (!data || data.length === 0) {
    return <div>No data found</div>;
  }

  return (
    <div>
      {/* Render data */}
    </div>
  );
};
```

### Step 5: Minimal Reproduction

Strip the component down to absolute minimum:

```typescript
const Studio = () => {
  return (
    <div className="p-4">
      <h1>Studio App</h1>
      <p>If you see this, basic rendering works.</p>
    </div>
  );
};

export default Studio;
```

If this renders, gradually add back features to isolate the breaking change.

---

## 🟡 Medium Priority Issues

### 3. Email Gate CTA is Generic

| Attribute | Value |
|-----------|-------|
| Severity | 🟡 Medium |
| Status | Open |
| Impact | Conversion rate (currently 2.1%) |

**Issue:**
The email gate at app.trythroughline.com shows:
- Generic CTA: "Get Instant Access"
- Feature-focused messaging

**Recommendation:**
Align with winning ad hooks. The ads use panic/relief messaging:
- "It's 11pm. Episode went live at 5pm. You still haven't posted."

Email gate could use:
- "Stop scrambling for captions at midnight"
- "Get all your captions in one click"

---

### 4. Landing Page Messaging Disconnect

| Attribute | Value |
|-----------|-------|
| Severity | 🟡 Medium |
| Status | Open |
| Impact | Visitor drop-off |

**Issue:**
Landing page at trythroughline.com is feature-focused:
- "Throughline is the operating system for podcast creators"
- Lists 3 apps: Signature, Studio, Briefing

But winning ads use emotional/panic hooks.

**Recommendation:**
- Hero should mirror ad messaging
- Lead with pain point, not features
- Move feature list below the fold

---

## 🟢 Low Priority / Enhancements

### 5. No Streaming Text Generation

The `ai-api` returns complete responses, not streamed tokens.

**Workaround:**
Use loading states with skeleton UI or progress indicators.

```typescript
const [isGenerating, setIsGenerating] = useState(false);

const generate = async () => {
  setIsGenerating(true);
  try {
    const result = await aiApi.generate({ ... });
    setContent(result.text);
  } finally {
    setIsGenerating(false);
  }
};

// In render:
{isGenerating && (
  <div className="animate-pulse bg-gray-200 h-20 rounded">
    Generating...
  </div>
)}
```

---

### 6. No Email Template System

The `email-api` doesn't support stored templates.

**Workaround:**
Build templates in code using a helper function:

```typescript
const emailTemplates = {
  guestConfirmation: (data: GuestData) => ({
    subject: `🎙 You're on So Good to Grow Good!`,
    html: `
      <div style="font-family: sans-serif;">
        <h1>Hey ${data.firstName}! 👋</h1>
        <p>We're stoked to have you on the show.</p>
        <!-- ... -->
      </div>
    `,
    text: `Hey ${data.firstName}! We're stoked to have you on the show.`
  })
};
```

---

## 📊 Platform Limitations Reference

| Feature | Status | Workaround |
|---------|--------|------------|
| Streaming AI responses | ❌ Not supported | Use loading states |
| Email templates | ❌ Not supported | Build in code |
| Email CC/BCC | ❌ Not supported | Send multiple emails |
| Custom sender address | ❌ Not supported | Use replyTo parameter |
| File picker UI | ❌ Not built-in | Build custom component |
| Model selection | ❌ Fixed (gpt-4o-mini) | None - model is sufficient |
| Doc primitive | ❌ Not built-in | Build custom component |
| Wizard/multi-step UI | ❌ Not built-in | Build with state machine |

---

## ✅ Platform Strengths

| Feature | Status | Notes |
|---------|--------|-------|
| Multi-voice AI | ✅ Works | `systemPrompt` parameter confirmed |
| Large context window | ✅ Works | 128k tokens - can handle full transcripts |
| File uploads | ✅ Works | storage-api → GCS |
| HTML emails | ✅ Works | Full HTML with styling |
| Web scraping | ✅ Works | web-api with extract/analyze |
| Database CRUD | ✅ Works | Full PostgreSQL access |
| Token tracking | ✅ Works | AI API returns usage data |

---

## 🔧 Fix Priority Order

1. **P1 - Critical**: Fix Studio app blank screen
2. **P1 - Critical**: Fix Briefing app blank screen
3. **P2 - Medium**: Update email gate messaging
4. **P3 - Low**: Update landing page hero messaging

Apps must be functional before implementing new features.