# Audos API Development Guide

> **A comprehensive guide to creating external API endpoints on the Audos platform**

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Creating Server Functions](#creating-server-functions)
4. [Available Runtime APIs](#available-runtime-apis)
5. [Calling Internal Platform APIs](#calling-internal-platform-apis)
6. [Runtime Limitations](#runtime-limitations)
7. [Testing & Debugging](#testing--debugging)
8. [Best Practices](#best-practices)

---

## Overview

### What Are Server Functions?

Server functions (also called "hooks") are JavaScript code blocks that run server-side on the Audos platform. They can be triggered via HTTP requests, making them perfect for creating external API endpoints.

### Why Create External APIs?

By default, Audos platform capabilities (database, AI, email, etc.) are only accessible from within the platform. Server functions let you:

- **Develop off-platform** — Use your local IDE, coding agents, or external tools
- **Integrate with external services** — Connect to third-party apps, webhooks, etc.
- **Build custom workflows** — Automate processes that span multiple systems
- **Create mobile/web app backends** — Use Audos as a backend for your apps

### What's NOT Included by Default

When you create a new Audos workspace, you get:

| Feature | Internal Access | External HTTP Access |
|---------|-----------------|---------------------|
| Database tables | ✅ Yes | ❌ No |
| AI generation | ✅ Yes | ❌ No |
| Email sending | ✅ Yes | ❌ No |
| CRM/Contacts | ✅ Yes | ❌ No |
| Analytics | ✅ Yes | ❌ No |
| File storage | ✅ Yes | ❌ No |

**Server functions are the bridge** — they expose internal capabilities as HTTP endpoints.

---

## Architecture

### How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                     EXTERNAL WORLD                               │
│  (Your local app, coding agent, mobile app, webhook, etc.)      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ HTTP POST
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  https://audos.com/api/hooks/execute/workspace-{NUMBER}/{NAME}  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    SERVER FUNCTION RUNTIME                       │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Your JavaScript Code                                    │    │
│  │  - request.body (incoming JSON)                          │    │
│  │  - db.query(), db.insert(), etc.                         │    │
│  │  - platform.generateText()                               │    │
│  │  - platform.sendEmail()                                  │    │
│  │  - fetch() for external/internal APIs                    │    │
│  │  - respond(statusCode, body)                             │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    AUDOS PLATFORM INTERNALS                      │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │
│  │ Database │ │ AI/LLM   │ │ Email    │ │ Storage  │           │
│  │ (Postgres)│ │ (GPT-4o) │ │ (SMTP)   │ │ (GCS)    │           │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

### URL Structure

```
https://audos.com/api/hooks/execute/workspace-{WORKSPACE_NUMBER}/{FUNCTION_NAME}
```

- **WORKSPACE_NUMBER**: Your workspace number (e.g., `351699`)
- **FUNCTION_NAME**: The name you gave your server function (e.g., `db-api`)

### Request Format

All server functions receive HTTP POST requests with JSON body:

```bash
curl -X POST "https://audos.com/api/hooks/execute/workspace-351699/my-api" \
  -H "Content-Type: application/json" \
  -d '{"action": "do-something", "data": "here"}'
```

---

## Creating Server Functions

### Method 1: Ask the AI Assistant

The easiest way is to ask the Audos AI assistant:

```
"Create a server function called 'my-api' that allows me to query my database externally"
```

The assistant will use the `manage_server_functions` tool to create it.

### Method 2: Using the Tool Directly

If you're building tools or automating, use the `manage_server_functions` MCP tool:

```json
{
  "operation": "create",
  "name": "my-api",
  "description": "Description of what this API does",
  "code": "const { action } = request.body; ..."
}
```

### Basic Template

```javascript
// Minimal server function template
const { action } = request.body || {};

if (!action) {
  return respond(400, {
    error: "Missing required field: action",
    availableActions: ["list", "create", "update", "delete"]
  });
}

try {
  if (action === "list") {
    // Your logic here
    return respond(200, { success: true, data: [] });
  }

  if (action === "create") {
    // Your logic here
    return respond(201, { success: true, message: "Created" });
  }

  return respond(400, { error: `Unknown action: ${action}` });

} catch (error) {
  console.error("API error:", error.message);
  return respond(500, { error: error.message });
}
```

---

## Available Runtime APIs

### Global Objects

| Object | Description |
|--------|-------------|
| `request` | Incoming HTTP request |
| `request.body` | Parsed JSON body |
| `request.method` | HTTP method (usually POST) |
| `request.query` | Query string parameters |
| `db` | Database helper object |
| `platform` | Platform services (AI, email) |
| `fetch` | HTTP client for external requests |
| `respond` | Function to send response |
| `console` | Logging (log, error, warn) |
| `JSON` | JSON parse/stringify |
| `Date` | Date object |
| `Math` | Math object |

### Database (`db`)

```javascript
// List all workspace tables
const tables = await db.listTables();

// Query a table
const result = await db.query('SELECT * FROM my_table WHERE status = $1', ['active']);
// result.rows contains the data

// Insert a row
await db.insert('my_table', {
  name: 'Test',
  status: 'active'
});

// Update rows
await db.update('my_table',
  { status: 'inactive' },  // SET
  { id: 123 }              // WHERE
);

// Delete rows
await db.delete('my_table', { id: 123 });
```

**Important**: `db` can only access **workspace tables** (tables you created), not system tables like `funnel_contacts`. For system data, use internal APIs via `fetch`.

### Platform Services (`platform`)

```javascript
// Generate AI text
const result = await platform.generateText({
  userPrompt: "Write a LinkedIn post about podcasting",
  systemPrompt: "You are a social media expert. Be concise."
});
const generatedText = result.text;

// Send an email
await platform.sendEmail({
  to: "user@example.com",
  subject: "Hello from my API",
  text: "This is the plain text body",
  html: "<h1>Hello!</h1><p>This is the HTML body</p>"
});
```

### HTTP Requests (`fetch`)

```javascript
// Fetch external URL
const response = await fetch("https://api.example.com/data");
const data = await response.json();

// Fetch internal Audos API
const workspaceId = "8f1ad824-832f-4af8-b77e-ab931a250625";
const response = await fetch(`https://audos.com/api/crm/contacts/${workspaceId}?limit=10`);
const contacts = await response.json();
```

### Response (`respond`)

```javascript
// Success response
return respond(200, {
  success: true,
  data: myData
});

// Created response
return respond(201, {
  success: true,
  id: newId
});

// Bad request
return respond(400, {
  error: "Missing required field: name"
});

// Server error
return respond(500, {
  error: "Something went wrong"
});
```

---

## Calling Internal Platform APIs

For data that's not in your workspace tables (contacts, analytics, etc.), use the internal APIs via fetch.

### Known Internal API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/crm/contacts/{workspaceId}` | GET | List contacts |
| `/api/crm/contacts/{workspaceId}` | POST | Create contact |
| `/api/crm/contacts/{workspaceId}/{contactId}` | PATCH | Update contact |

### Example: Fetching Contacts

```javascript
const workspaceId = "YOUR-WORKSPACE-ID";
const baseUrl = "https://audos.com";

// Build query string manually (URLSearchParams not available!)
function buildQuery(params) {
  const parts = [];
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== null) {
      parts.push(encodeURIComponent(key) + "=" + encodeURIComponent(value));
    }
  }
  return parts.length > 0 ? "?" + parts.join("&") : "";
}

const url = `${baseUrl}/api/crm/contacts/${workspaceId}${buildQuery({ limit: 50, days: 30 })}`;
const response = await fetch(url);
const data = await response.json();
// data.contacts contains the contact list
```

---

## Runtime Limitations

The server function runtime is NOT a full Node.js environment. Some things don't work:

| Feature | Available? | Workaround |
|---------|------------|------------|
| `URLSearchParams` | ❌ No | Manual query string building |
| `response.headers.get()` | ❌ No | Read full response as text |
| `Buffer` | ❌ No | Use base64 strings |
| `require()` / `import` | ❌ No | All code must be inline |
| `process.env` | ❌ No | Hardcode config or use db |
| `setTimeout` | ❌ No | Not available |
| `db.query` on system tables | ❌ No | Use internal APIs via fetch |
| `fetch` | ✅ Yes | — |
| `JSON` | ✅ Yes | — |
| `Date` | ✅ Yes | — |
| `Math` | ✅ Yes | — |
| `console.log/error` | ✅ Yes | — |
| `platform.generateText` | ✅ Yes | — |
| `platform.sendEmail` | ✅ Yes | — |

### Common Pitfalls

**1. URLSearchParams not defined**
```javascript
// ❌ Won't work
const params = new URLSearchParams({ limit: 10 });

// ✅ Do this instead
function buildQuery(params) {
  const parts = [];
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== null) {
      parts.push(encodeURIComponent(key) + "=" + encodeURIComponent(value));
    }
  }
  return parts.length > 0 ? "?" + parts.join("&") : "";
}
```

**2. Response headers not accessible**
```javascript
// ❌ Won't work
const contentType = response.headers.get('content-type');

// ✅ Do this instead
const text = await response.text();
// Parse as needed
```

**3. Querying system tables**
```javascript
// ❌ Won't work - system tables not accessible via db
await db.query('SELECT * FROM funnel_contacts WHERE ...');

// ✅ Do this instead - use internal API
const response = await fetch(`https://audos.com/api/crm/contacts/${workspaceId}`);
const data = await response.json();
```

---

## Testing & Debugging

### Using the Test Tool

After creating or updating a server function, test it:

```
"Test the my-api server function with body { action: 'list' }"
```

The assistant will use `test_server_function` and show you:
- HTTP status code
- Response body
- Console logs
- Execution time

### Viewing Logs

To see recent executions and errors:

```
"Show me the logs for my-api"
```

The assistant will use `get_hook_logs` to show recent executions with any console output or errors.

### Manual Testing with cURL

```bash
curl -X POST "https://audos.com/api/hooks/execute/workspace-XXXXX/my-api" \
  -H "Content-Type: application/json" \
  -d '{"action": "list"}' | jq
```

---

## Best Practices

### 1. Always Validate Input

```javascript
const { action, data } = request.body || {};

if (!action) {
  return respond(400, {
    error: "Missing required field: action",
    availableActions: ["list", "create"]
  });
}
```

### 2. Use Try-Catch for Error Handling

```javascript
try {
  // Your logic
} catch (error) {
  console.error("API error:", error.message);
  return respond(500, { error: error.message });
}
```

### 3. Return Consistent Response Shapes

```javascript
// Success
{ success: true, data: [...] }

// Error
{ error: "Description of what went wrong" }
```

### 4. Log Important Operations

```javascript
console.log(`Processing ${action} with data:`, JSON.stringify(data));
```

### 5. Document Your API

Include available actions in error responses:

```javascript
return respond(400, {
  error: `Unknown action: ${action}`,
  availableActions: ["list", "create", "update", "delete"]
});
```

### 6. Hardcode Your Workspace ID

Since environment variables aren't available, hardcode your workspace ID:

```javascript
const workspaceId = "8f1ad824-832f-4af8-b77e-ab931a250625"; // Your workspace ID
```

---

## Quick Reference

### Creating an API

```javascript
// Template for a new API
const { action, ...params } = request.body || {};

if (!action) {
  return respond(400, { error: "Missing action" });
}

try {
  switch (action) {
    case "list":
      const items = await db.query('SELECT * FROM my_table');
      return respond(200, { success: true, items: items.rows });

    case "create":
      await db.insert('my_table', params);
      return respond(201, { success: true });

    default:
      return respond(400, { error: `Unknown action: ${action}` });
  }
} catch (error) {
  console.error("Error:", error.message);
  return respond(500, { error: error.message });
}
```

### Calling Your API

```bash
# List items
curl -X POST "https://audos.com/api/hooks/execute/workspace-XXXXX/my-api" \
  -H "Content-Type: application/json" \
  -d '{"action": "list"}'

# Create item
curl -X POST "https://audos.com/api/hooks/execute/workspace-XXXXX/my-api" \
  -H "Content-Type: application/json" \
  -d '{"action": "create", "name": "Test", "value": 123}'
```

---

*See also:*
- [Server Function Templates](./02-audos-server-function-templates.md)
- [Runtime Reference](./03-audos-runtime-reference.md)
- [Throughline API Reference](./04-throughline-api-reference.md)
