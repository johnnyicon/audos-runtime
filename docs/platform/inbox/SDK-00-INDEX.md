# Throughline SDK Documentation Index

> Last Updated: June 2025

This index contains all SDK documentation files for building Throughline on the Audos platform.

---

## 📄 Complete File List

| # | File | Purpose | Download |
|---|------|---------|----------|
| 01 | **SDK-01-PLATFORM-ARCHITECTURE.md** | Core architecture, hook vs API comparison | [Download](https://storage.googleapis.com/audos-images/workspace-media/8f1ad824-832f-4af8-b77e-ab931a250625/1774987454783_0mou6i3y.md) |
| 02 | **SDK-02-REST-API-REFERENCE.md** | Full REST API documentation for all 8 server functions | [Download](https://storage.googleapis.com/audos-images/workspace-media/8f1ad824-832f-4af8-b77e-ab931a250625/1774987599901_6ve4ib0z.md) |
| 03 | **SDK-03-LOCAL-MOCK-LAYER.md** | Full mock implementation for local development | [Download](https://storage.googleapis.com/audos-images/workspace-media/8f1ad824-832f-4af8-b77e-ab931a250625/1774987929771_8347fp0t.md) |
| 04 | **SDK-04-DEVELOPMENT-WORKFLOW.md** | Complete workflow guide combining local + platform | [Download](https://storage.googleapis.com/audos-images/workspace-media/8f1ad824-832f-4af8-b77e-ab931a250625/1774988028098_quwvzrxx.md) |
| 05 | **SDK-05-PRE-BUILD-ANSWERS.md** | Answers to 7 pre-build questions for Throughline | [Download](https://storage.googleapis.com/audos-images/workspace-media/8f1ad824-832f-4af8-b77e-ab931a250625/1775139847883_v0hgwuw4.md) |
| 06 | **SDK-06-API-QUICK-REFERENCE.md** | API quick reference card with all endpoints | [Download](https://storage.googleapis.com/audos-images/workspace-media/8f1ad824-832f-4af8-b77e-ab931a250625/1775140047649_2u0yga2p.md) |

---

## 🔑 Quick Reference Summary

### Platform Stack

| Layer | Technology |
|-------|------------|
| Frontend | React 18 + TypeScript + Tailwind CSS |
| Database | PostgreSQL (via useWorkspaceDB hook or db-api) |
| AI | gpt-4o-mini-2024-07-18 (128k context) |
| Storage | Google Cloud Storage |
| Email | Platform email service (HTML + plain text) |

---

### 8 Server Functions (REST APIs)

All APIs are accessible at:
```
https://platform.audos.com/api/hooks/execute/workspace-8f1ad824-832f-4af8-b77e-ab931a250625/{hook-name}
```

| API Name | Purpose | Key Actions |
|----------|---------|-------------|
| `db-api` | Database CRUD | query, insert, update, delete, list-tables |
| `ai-api` | AI text generation | generate (supports `systemPrompt` ✅) |
| `email-api` | Send emails | send (HTML, text, replyTo) |
| `storage-api` | File uploads | upload, list, upload-from-url |
| `web-api` | Web scraping | fetch, extract, metadata, analyze |
| `scheduler-api` | Cron jobs | schedule, list, cancel |
| `analytics-api` | Visitor metrics | get-stats, get-events |
| `crm-api` | Contact management | create, query, update |

---

### Key Findings from Pre-Build Q&A

| Question | Answer |
|----------|--------|
| **Doc primitive exists?** | ❌ No — build custom React components |
| **Multi-voice AI?** | ✅ Yes — use `systemPrompt` parameter |
| **File uploads?** | ✅ Yes — `storage-api` to GCS (build own UI) |
| **HTML emails?** | ✅ Yes — `email-api` supports HTML |
| **Streaming text?** | ❌ No — use loading states |
| **Email templates?** | ❌ No — build in code |
| **Wizard component??** | ❌ No — build with state machine pattern |

---

### AI Generation with Voice Profile

```typescript
// TESTED AND CONFIRMED WORKING
const response = await fetch(`${API_BASE}/ai-api`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'x-workspace-id': WORKSPACE_ID
  },
  body: JSON.stringify({
    action: 'generate',
    systemPrompt: `You are Kane, a podcast host. 
      Your voice is: casual, insightful, conversational.
      Sample output: ${voiceProfile.voice_preview}`,
    prompt: `Write an Instagram caption for: ${reelContent}`
  })
});

const data = await response.json();
// data.text = generated content
// data.usage = { promptTokens, completionTokens }
```

---

### Existing Database Tables

The workspace already has these tables set up:

| Table | Purpose |
|-------|---------|
| `voice_profiles` | Store voice fingerprints (Kane, SG2GG brand) |
| `transcripts` | Uploaded transcript training data |
| `approved_captions` | Approved captions for voice training |
| `correction_notes` | Voice refinement feedback |
| `speakers` | Guest/speaker info |
| `reels` | Podcast reels/clips |
| `captions` | Generated captions by platform |
| `dashboard_activity` | User activity logging |

---

## ⚠️ Known Issues

Discovered during browser testing (June 2025):

| Issue | Severity | Status |
|-------|----------|--------|
| **Studio app blank white screen** | 🔴 Critical | Open |
| **Briefing app blank white screen** | 🔴 Critical | Open |
| Email gate CTA is generic | Low | Open |
| Landing page messaging disconnect from ads | Medium | Open |

---

## Workspace Details

| Key | Value |
|-----|-------|
| Workspace ID | `8f1ad824-832f-4af8-b77e-ab931a250625` |
| Brand Name | Throughline |
| Domain | trythroughline.com |
| App Space | app.trythroughline.com |
| API Base | `https://platform.audos.com/api/hooks/execute/workspace-8f1ad824-832f-4af8-b77e-ab931a250625` |
