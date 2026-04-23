# EmailGate OTP Configuration

> **SDK-Level Documentation** for developers building on the Audos platform

EmailGate is Audos's visitor identification layer. By default it accepts any email address with no verification — this is intentional for lead-capture use cases. For apps that store real user data, this default is a security gap. OTP (one-time passcode) email verification must be **explicitly enabled per workspace**.

This document covers: what OTP is, why it's off by default, how to enable it, how to verify it works, and what the UX looks like.

---

## Table of Contents

1. [Security Model — Why OTP Is Off By Default](#security-model)
2. [Checking Current OTP Status](#checking-current-otp-status)
3. [Enabling OTP](#enabling-otp)
4. [Verifying It Works](#verifying-it-works)
5. [What Changes After Enabling](#what-changes-after-enabling)
6. [Configuration Options](#configuration-options)
7. [OAuth Alternative](#oauth-alternative)
8. [Workspace Reference](#workspace-reference)

---

## Security Model

EmailGate is a **lead-capture mechanism, not a security boundary**. The default design optimizes for conversion: a visitor enters their email and immediately gets access. No verification, no friction.

**The consequence:** anyone who knows a user's email address can enter it and access that user's data. For apps that store org-scoped production data (episodes, guests, configurations), this is a meaningful risk.

**OTP closes this gap.** With OTP enabled, entering an email triggers a 4-digit verification code sent to that inbox. Only the person who controls the inbox can complete the flow.

**OTP is disabled on every new workspace by default.** It is not turned on automatically, even for apps that store sensitive data. You must enable it explicitly.

---

## Checking Current OTP Status

Run this from a browser console on any audos.io page while logged in:

```javascript
fetch('/api/auth/otp/space/config/YOUR_WORKSPACE_UUID', {
  credentials: 'include'
}).then(r => r.json()).then(console.log)
```

A disabled workspace returns:
```json
{ "config": { "enabled": false } }
```

An enabled workspace returns:
```json
{
  "config": {
    "enabled": true,
    "trigger": "always",
    "triggerActions": [],
    "triggerRoutes": []
  }
}
```

---

## Enabling OTP

### Why the browser console?

Audos does not expose OTP configuration in any settings UI. The only interface is the API directly. The API requires authentication via your existing Audos session — which means the call must be made from a browser where you are already logged into audos.io.

A curl command with a bearer token would also work, but Audos does not expose a token management UI either. The browser console is the practical path.

### Steps

1. Open [audos.io](https://audos.io) in your browser and ensure you are logged in
2. Open DevTools → Console tab (F12 → Console)
3. Paste and run:

```javascript
fetch('/api/auth/otp/space/config/YOUR_WORKSPACE_UUID', {
  method: 'PUT',
  headers: { 'Content-Type': 'application/json' },
  credentials: 'include',
  body: JSON.stringify({ enabled: true, trigger: "always" })
}).then(r => r.json()).then(console.log)
```

4. Confirm the response:

```json
{
  "success": true,
  "config": {
    "enabled": true,
    "trigger": "always",
    "triggerActions": [],
    "triggerRoutes": []
  }
}
```

This is a one-time setup. The configuration persists permanently until explicitly changed.

### Finding your workspace UUID

Your workspace has two identifiers:
- **Space ID**: the human-readable slug (e.g. `workspace-351699`)
- **Workspace UUID**: the UUID used in API calls (e.g. `8f1ad824-832f-4af8-b77e-ab931a250625`)

The OTP config endpoint uses the **UUID**. You can find it in your workspace settings or by inspecting the `EmailGate.tsx` component in your audos-workspace — it appears in the `workspaceId` prop or in network requests when the EmailGate loads.

---

## Verifying It Works

1. Open your app URL in an **incognito window** (to ensure no existing session)
2. Enter your email in the EmailGate form
3. You should see a new screen prompting for a 4-digit code
4. Check your inbox — the code arrives from Audos's email system within ~30 seconds
5. Enter the code → session established

If the code screen does not appear, OTP was not successfully enabled. Re-run the enable command and confirm the response shows `"enabled": true`.

---

## What Changes After Enabling

### Session structure

The session written to `localStorage.space_session_{spaceId}` gains a `verified` field:

**Before OTP:**
```json
{
  "id": "session_abc",
  "workspaceSessionId": "wses_xyz",
  "email": "user@example.com",
  "timestamp": 1713500000000
}
```

**After OTP (verified):**
```json
{
  "id": "session_abc",
  "workspaceSessionId": "wses_xyz",
  "email": "user@example.com",
  "timestamp": 1713500000000,
  "verified": true
}
```

Your app code can check `session.verified === true` as an additional guard, though the Audos gate itself enforces verification before writing the session.

### Code expiry and resend

- Codes expire after **5 minutes**
- There is a **60-second cooldown** before requesting a new code
- Codes are always 4 digits (0000–9999)

### Returning visitors

A returning visitor with a valid session in localStorage skips the OTP flow entirely — the gate sees the existing session and passes them through. OTP is only triggered when no valid session exists.

### Session expiry

Audos sessions **do not expire automatically** — they persist in localStorage indefinitely. If you want sessions to time out, implement a TTL check in your app:

```typescript
function isSessionExpired(session: AudosSession): boolean {
  const MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000; // 7 days
  return Date.now() - session.timestamp > MAX_AGE_MS;
}
```

### Sign out

EmailGate has no built-in sign out. Implement it by clearing the session key and reloading:

```typescript
function signOut(): void {
  localStorage.removeItem('space_session_workspace-351699');
  window.location.reload();
}
```

After reload, EmailGate will render and require OTP verification on the next sign-in.

---

## Configuration Options

The `trigger` field controls when OTP is required:

| Config | Behavior |
|--------|----------|
| `{ "enabled": true, "trigger": "always" }` | Every new session requires OTP (recommended) |
| `{ "enabled": true, "trigger": "on_route", "triggerRoutes": ["/settings/*"] }` | OTP only on specific routes |
| `{ "enabled": true, "trigger": "on_action", "triggerActions": ["checkout"] }` | OTP only on specific actions |
| `{ "enabled": false }` | No verification (default) |

For most apps storing user data: use `trigger: "always"`.

---

## OAuth Alternative

Audos does not natively support Google OAuth or any OAuth 2.0 provider. OTP is the only Audos-native security enhancement available.

A custom OAuth implementation is technically possible — implement the OAuth flow in your app, then write the resulting verified email to `localStorage.space_session_{spaceId}` with `verified: true` and call `/api/space/{spaceId}/register` to create the CRM contact. This is undocumented and carries no stability guarantee. See the research doc at `docs/platform/inbox/AUDOS-EMAILGATE-SECURITY-OAUTH-GUIDE.md` for implementation details.

**For single-user or small-team workspaces: OTP is the right choice.** OAuth adds complexity without meaningful security improvement in that context.

---

## Workspace Reference

Values for workspace-351699 (Throughline):

| Field | Value |
|-------|-------|
| Space ID | `workspace-351699` |
| Workspace UUID | `8f1ad824-832f-4af8-b77e-ab931a250625` |
| Session key | `space_session_workspace-351699` |
| OTP status | Enabled (`trigger: "always"`) as of 2026-04-23 |

**Enable command (Throughline):**
```javascript
fetch('/api/auth/otp/space/config/8f1ad824-832f-4af8-b77e-ab931a250625', {
  method: 'PUT',
  headers: { 'Content-Type': 'application/json' },
  credentials: 'include',
  body: JSON.stringify({ enabled: true, trigger: "always" })
}).then(r => r.json()).then(console.log)
```

**Check status command (Throughline):**
```javascript
fetch('/api/auth/otp/space/config/8f1ad824-832f-4af8-b77e-ab931a250625', {
  credentials: 'include'
}).then(r => r.json()).then(console.log)
```
