# Throughline API Reference

> **Complete reference for all custom API endpoints in the Throughline workspace**

---

## Workspace Information

| Property | Value |
|----------|-------|
| Workspace ID | `8f1ad824-832f-4af8-b77e-ab931a250625` |
| Workspace Number | `351699` |
| Base URL | `https://audos.com/api/hooks/execute/workspace-351699` |
| Landing Page | https://www.trythroughline.com |
| App/Space | https://app.trythroughline.com |

---

## Available APIs

| API | Endpoint | Description |
|-----|----------|-------------|
| [Database API](#database-api) | `/db-api` | Full CRUD for all workspace tables |
| [AI API](#ai-api) | `/ai-api` | AI text generation |
| [Email API](#email-api) | `/email-api` | Send transactional emails |
| [CRM API](#crm-api) | `/crm-api` | Contact management |
| [Analytics API](#analytics-api) | `/analytics-api` | Visitor metrics |
| [Storage API](#storage-api) | `/storage-api` | File upload/management |
| [Scheduler API](#scheduler-api) | `/scheduler-api` | Task scheduling |
| [Web API](#web-api) | `/web-api` | Web page fetching |

---

## Database API

**Endpoint:** `POST /db-api`

### Actions

#### list-tables
```json
{ "action": "list-tables" }
```
Returns all workspace tables with row counts.

#### describe
```json
{ "action": "describe", "table": "voice_profiles" }
```
Returns schema for a specific table.

#### query
```json
{
  "action": "query",
  "table": "voice_profiles",
  "columns": ["id", "name", "type"],
  "filters": [{ "column": "type", "operator": "eq", "value": "host" }],
  "orderBy": { "column": "created_at", "direction": "desc" },
  "limit": 10,
  "offset": 0
}
```

#### insert
```json
{
  "action": "insert",
  "table": "dashboard_activity",
  "data": {
    "activity_type": "api_test",
    "title": "Test Activity",
    "description": "Test from API"
  }
}
```

#### update
```json
{
  "action": "update",
  "table": "voice_profiles",
  "filters": [{ "column": "id", "operator": "eq", "value": 1 }],
  "data": { "description": "Updated description" }
}
```

#### delete
```json
{
  "action": "delete",
  "table": "voice_profiles",
  "filters": [{ "column": "id", "operator": "eq", "value": 99 }]
}
```

### Available Tables

| Table | Description |
|-------|-------------|
| `voice_profiles` | Voice fingerprints for hosts and brand |
| `speakers` | Speaker registry for transcript parsing |
| `voice_refinements` | Training data for voice model refinement |
| `studio_episodes` | Episode drops for content generation |
| `studio_generated_content` | Generated content for each platform |
| `studio_time_tracking` | Time saved through automation |
| `reels` | Content pieces for social posting |
| `reel_captions` | Generated captions per platform |
| `guest_prep_podcast_profiles` | Podcast identity configuration |
| `guest_prep_research_sessions` | Guest research data |
| `guest_prep_ros_versions` | Run of show version history |
| `briefing_podcast_profiles` | Briefing app podcast profiles |
| `briefing_research_sessions` | Briefing research sessions |
| `dashboard_activity` | Activity feed for the dashboard |
| `outreach_leads` | Discovered podcast creator leads |

---

## AI API

**Endpoint:** `POST /ai-api`

### generate
```json
{
  "action": "generate",
  "prompt": "Write a LinkedIn post about podcasting",
  "systemPrompt": "You are a social media expert. Be concise."
}
```

**Response:**
```json
{
  "success": true,
  "text": "Generated content here..."
}
```

---

## Email API

**Endpoint:** `POST /email-api`

### send
```json
{
  "action": "send",
  "to": "user@example.com",
  "subject": "Hello from Throughline",
  "text": "Plain text body",
  "html": "<h1>HTML body</h1>"
}
```

---

## CRM API

**Endpoint:** `POST /crm-api`

### list
```json
{
  "action": "list",
  "limit": 50,
  "hasEmail": true
}
```

### create
```json
{
  "action": "create",
  "email": "guest@example.com",
  "name": "John Doe",
  "source": "manual"
}
```

### update
```json
{
  "action": "update",
  "contactId": "contact_abc123",
  "name": "Jane Doe",
  "addTags": ["vip", "guest"]
}
```

### add-tags / remove-tags
```json
{
  "action": "add-tags",
  "tags": ["newsletter"],
  "filter": { "sourceCategory": "organic" }
}
```

---

## Analytics API

**Endpoint:** `POST /analytics-api`

### overview
```json
{
  "action": "overview",
  "days": 30
}
```

**Response:**
```json
{
  "success": true,
  "period": { "days": 30 },
  "metrics": {
    "totalContacts": 5,
    "emailCount": 5,
    "conversionRate": "100.0%",
    "eventsByType": { "email_captured": 5 }
  }
}
```

### funnel
```json
{ "action": "funnel", "days": 30 }
```

### events
```json
{
  "action": "events",
  "eventType": "email_submit",
  "days": 7,
  "limit": 50
}
```

### sessions
```json
{
  "action": "sessions",
  "limit": 20,
  "hasEmail": true
}
```

---

## Storage API

**Endpoint:** `POST /storage-api`

### upload (base64)
```json
{
  "action": "upload",
  "filename": "image.png",
  "contentType": "image/png",
  "base64": "iVBORw0KGgo...",
  "category": "attachment"
}
```

### upload (URL)
```json
{
  "action": "upload",
  "filename": "image.png",
  "contentType": "image/png",
  "url": "https://example.com/image.png"
}
```

### list
```json
{
  "action": "list",
  "limit": 20,
  "category": "attachment"
}
```

---

## Scheduler API

**Endpoint:** `POST /scheduler-api`

### create
```json
{
  "action": "create",
  "name": "daily-report",
  "taskType": "cron",
  "schedule": "0 9 * * *",
  "payload": { "report": "daily" }
}
```

### list
```json
{ "action": "list" }
```

### cancel / pause / resume
```json
{
  "action": "pause",
  "taskId": "task_abc123"
}
```

---

## Web API

**Endpoint:** `POST /web-api`

### fetch
```json
{
  "action": "fetch",
  "url": "https://example.com/page"
}
```

**Response:**
```json
{
  "success": true,
  "url": "https://example.com/page",
  "title": "Page Title",
  "content": "Extracted text content...",
  "contentLength": 12345,
  "rawLength": 28248
}
```

---

## Code Examples

### Python
```python
import requests

BASE = "https://audos.com/api/hooks/execute/workspace-351699"

# List tables
response = requests.post(f"{BASE}/db-api", json={"action": "list-tables"})
print(response.json())

# Generate AI content
response = requests.post(f"{BASE}/ai-api", json={
    "action": "generate",
    "prompt": "Write a podcast intro"
})
print(response.json()["text"])

# Get analytics
response = requests.post(f"{BASE}/analytics-api", json={
    "action": "overview",
    "days": 7
})
print(response.json()["metrics"])
```

### JavaScript/TypeScript
```typescript
const BASE = "https://audos.com/api/hooks/execute/workspace-351699";

async function callApi(endpoint: string, body: object) {
  const response = await fetch(`${BASE}/${endpoint}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body)
  });
  return response.json();
}

// List tables
const tables = await callApi("db-api", { action: "list-tables" });

// Generate AI content
const ai = await callApi("ai-api", {
  action: "generate",
  prompt: "Write a podcast intro"
});
console.log(ai.text);

// Get contacts
const crm = await callApi("crm-api", { action: "list", limit: 10 });
console.log(crm.contacts);
```

### cURL
```bash
# List tables
curl -X POST "https://audos.com/api/hooks/execute/workspace-351699/db-api" \
  -H "Content-Type: application/json" \
  -d '{"action": "list-tables"}'

# Generate AI content
curl -X POST "https://audos.com/api/hooks/execute/workspace-351699/ai-api" \
  -H "Content-Type: application/json" \
  -d '{"action": "generate", "prompt": "Write a podcast intro"}'

# Get analytics
curl -X POST "https://audos.com/api/hooks/execute/workspace-351699/analytics-api" \
  -H "Content-Type: application/json" \
  -d '{"action": "overview", "days": 7"}'
```

---

## Authentication

Currently, these endpoints are **open** (no API key required). They are scoped to the Throughline workspace by the workspace number in the URL.

If you need to add authentication in the future, you could:
1. Add an API key check at the start of each server function
2. Use the platform's built-in auth if/when available

---

## Rate Limits

There are no explicit rate limits documented, but:
- Each request has a ~30 second timeout
- Avoid making hundreds of requests per second
- Be mindful of AI generation costs (tokens)

---

## Error Handling

All APIs return consistent error responses:

```json
{
  "error": "Description of what went wrong"
}
```

Common HTTP status codes:
- `200` - Success
- `201` - Created
- `400` - Bad request (missing/invalid input)
- `500` - Server error (check logs)
- `501` - Not implemented

---

*These APIs are custom-built for Throughline. If you create a new Audos workspace, you'll need to recreate them using the templates in [Server Function Templates](./02-audos-server-function-templates.md).*
