# Audos Platform — API Quick Reference Card

A concise reference for all available API endpoints in the Throughline workspace.

---

## Base URL

```
/api/hooks/execute/workspace-8f1ad824-832f-4af8-b77e-ab931a250625/{hookName}
```

All requests are `POST` with `Content-Type: application/json`.

---

## 1 ✖ AI Generation `ai-api`

### Generate Text

```json
{
  "action": "generate",
  "prompt": "Write an Instagram caption for...",
  "systemPrompt": "You are Kane, a podcast host..."  // Optional
}
```

**Response:**
```json
{
  "success": true,
  "text": "Generated content...",
  "model": "gpt-4o-mini-2024-07-18",
  "usage": { "promptTokens": 14, "completionTokens": 7, "totalTokens": 21 }
}
```

---

## 2 📧 Database `db-api`

### Query Records

```json
{
  "action": "query",
  "table": "voice_profiles",
  "filters": [{ "column": "type", "operator": "eq", "value": "host" }],
  "limit": 10
}
```

### Insert Record

```json
{
  "action": "insert",
  "table": "reels",
  "data": { "title": "Episode 42 Clip", "status": "draft" }
}
```

### Update Record

```json
{
  "action": "update",
  "table": "reels",
  "filters": [{ "column": "id", "operator": "eq", "value": 1 }],
  "data": { "status": "published" }
}
```

### Delete Record

```json
{
  "action": "delete",
  "table": "reels",
  "filters": [{ "column": "id", "operator": "eq", "value": 1 }]
}
```

### List Tables

```json
{ "action": "list-tables" }
```

### Describe Table

```json
{ "action": "describe", "table": "voice_profiles" }
```

---

## 3 📧 Email `email-api`

### Send Email

```json
{
  "action": "send",
  "to": "guest@example.com",
  "subject": "Confirmation: Your Podcast Appearance",
  "text": "Plain text version...",
  "html": "<h1>Confirmation</h1><p>HTML version...</p>",
  "replyTo": "kane@sg2gg.com"  // Optional
}
```

---

## 4 📁 Storage `storage-api`

### Upload File (Base64)

```json
{
  "action": "upload",
  "filename": "transcript.txt",
  "contentType": "text/plain",
  "base64": "SGVsbG8m..."
}
```

### Upload from URL

```json
{
  "action": "upload-from-url",
  "url": "https://example.com/file.pdf",
  "filename": "downloaded.pdf"
}
```

### List Files

```json
{ "action": "list" }
```

---

## 5 🌐 Web Fetch `web-api`

### Fetch Page Content

```json
{
  "action": "fetch",
  "url": "https://example.com/article"
}
```

**Response:**
```json
{
  "success": true,
  "url": "https://example.com/article",
  "title": "Page Title",
  "content": "Extracted text content...",
  "contentLength": 142,
  "rawLength": 528
}
```

### Other Actions

- `extract` — Extract structured data
- `metadata` — Get page metadata only
- `analyze` — AI-powered analysis

---

## 6 ⏰ Scheduler `scheduler-api`

### Create Scheduled Task

```json
{
  "action": "create",
  "name": "Daily Content Reminder",
  "frequency": "daily",
  "time": "09:00",
  "timezone": "America/Los_Angeles",
  "hookName": "my-custom-hook",
  "actionPayload": { "message": "Hello" }
}
```

---

## 7 📊 Analytics `analytics-api`

### Get Visitor Metrics

```json
{
  "action": "overview",
  "days": 30
}
```

---

## 8 👥 CRM `crm-api`

### Query Contacts

```json
{
  "action": "query",
  "limit": 50,
  "hasEmail": true
}
```

### Create Contact

```json
{
  "action": "create",
  "email": "newlead@example.com",
  "name": "John Doe",
  "source": "briefing-app"
}
```

---

## TypeScript Helper Class

```typescript
const WORKSPACE_ID = '8f1ad824-832f-4af8-b77e-ab931a250625';
const BASE_URL = `/api/hooks/execute/workspace-${WORKSPACE_ID}`;

async function callApi(hook: string, body: object) {
  const response = await fetch(`${BASE_URL}/${hook}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  });
  return response.json();
}

// Examples
const aiApi = {
  generate: (prompt: string, systemPrompt?: string) => 
    callApi('ai-api', { action: 'generate', prompt, systemPrompt })
};

const dbApi = {
  query: (table: string, filters?: any[]) => 
    callApi('db-api', { action: 'query', table, filters }),
  insert: (table: string, data: object) => 
    callApi('db-api', { action: 'insert', table, data }),
  update: (table: string, filters: any[], data: object) => 
    callApi('db-api', { action: 'update', table, filters, data }),
  delete: (table: string, filters: any[]) => 
    callApi('db-api', { action: 'delete', table, filters })
};

const emailApi = {
  send: (to: string, subject: string, text: string, html?: string) => 
    callApi('email-api', { action: 'send', to, subject, text, html })
};

const storageApi = {
  upload: (filename: string, contentType: string, base64: string) => 
    callApi('storage-api', { action: 'upload', filename, contentType, base64 }),
  list: () => 
    callApi('storage-api', { action: 'list' })
};

const webApi = {
  fetch: (url: string) => 
    callApi('web-api', { action: 'fetch', url })
};
```

---

## Filter Operators (for `db-api`)

| Operator | Description | Example |
|----------|-------------|---------|
| `eq` | Equals | `{ "column": "status", "operator": "eq", "value": "active" }` |
| `neq` | Not equals | `{ "column": "status", "operator": "neq", "value": "deleted" }` |
| `gt` | Greater than | `{ "column": "count", "operator": "gt", "value": 5 }` |
| `gte` | Greater than or equal | `{ "column": "count", "operator": "gte", "value": 5 }` |
| `lt` | Less than | `{ "column": "count", "operator": "lt", "value": 10 }` |
| `lte` | Less than or equal | `{ "column": "count", "operator": "lte", "value": 10 }` |
| `like` | Pattern match (case-sensitive) | `{ "column": "name", "operator": "like", "value": "%John%" }` |
| `ilike` | Pattern match (case-insensitive) | `{ "column": "name", "operator": "ilike", "value": "%john%" }` |
| `in` | In array | `{ "column": "status", "operator": "in", "value": ["active", "pending"] }` |
| `is_null` | Is null | `{ "column": "deleted_at", "operator": "is_null" }` |
| `not_null` | Is not null | `{ "column": "email", "operator": "not_null" }` |

---

## Existing Database Tables

| Table | Purpose | Rows |
|-------|--------|------|
| `voice_profiles` | Voice fingerprints for hosts/brands | 2 |
| `speakers` | Speaker registry for transcript parsing | 3 |
| `reels` | Content pieces for social media | 1 |
| `reel_captions` | Generated captions per platform/voice | 0 |
| `voice_refinements` | Voice model training conversations | 0 |
| `studio_episodes` | Episode drops that trigger content generation | 0 |
| `studio_generated_content` | Generated content per platform | 0 |
| `briefing_research_sessions` | Guest briefing sessions | 0 |
| `guest_prep_research_sessions` | Guest research data | 0 |
| `linked_references` | Cached web pages | 2 |

---

*Generated for Throughline SDK — April 2026*