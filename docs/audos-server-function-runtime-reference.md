# Audos Server Function Runtime Reference

> **Complete reference for the server function JavaScript runtime environment**

---

## Runtime Overview

Server functions run in a sandboxed JavaScript environment on the Audos platform. This is **not** a full Node.js environment — it's a custom runtime with specific capabilities and limitations.

---

## Global Objects

### `request`

The incoming HTTP request object.

| Property | Type | Description |
|----------|------|-------------|
| `request.body` | Object | Parsed JSON body from POST request |
| `request.method` | String | HTTP method (usually "POST") |
| `request.query` | Object | Query string parameters |
| `request.headers` | Object | HTTP headers (limited access) |

**Example:**
```javascript
const { action, data } = request.body || {};
const queryParam = request.query.foo;
```

---

### `respond(statusCode, body)`

Send an HTTP response back to the caller.

| Parameter | Type | Description |
|-----------|------|-------------|
| `statusCode` | Number | HTTP status code (200, 201, 400, 500, etc.) |
| `body` | Object | Response body (will be JSON serialized) |

**Example:**
```javascript
// Success
return respond(200, { success: true, data: myData });

// Created
return respond(201, { success: true, id: newId });

// Bad request
return respond(400, { error: "Missing required field" });

// Server error
return respond(500, { error: "Something went wrong" });
```

**Common Status Codes:**
| Code | Meaning | When to Use |
|------|---------|-------------|
| 200 | OK | Successful GET/query |
| 201 | Created | Successful POST/insert |
| 400 | Bad Request | Invalid input |
| 401 | Unauthorized | Auth required |
| 404 | Not Found | Resource doesn't exist |
| 500 | Server Error | Unexpected error |
| 501 | Not Implemented | Feature not available |

---

### `db`

Database helper for workspace tables.

#### `db.listTables()`

List all tables in the workspace.

```javascript
const tables = await db.listTables();
// Returns: [{ name: "my_table", rowCount: 10, ... }, ...]
```

#### `db.query(sql, params)` or `db.query(table, options)`

Query data from a table.

```javascript
// SQL style
const result = await db.query(
  'SELECT * FROM my_table WHERE status = $1 ORDER BY created_at DESC LIMIT $2',
  ['active', 10]
);
const rows = result.rows;

// Options style
const result = await db.query('my_table', {
  columns: ['id', 'name', 'status'],
  filters: [{ column: 'status', operator: 'eq', value: 'active' }],
  orderBy: { column: 'created_at', direction: 'desc' },
  limit: 10,
  offset: 0
});
```

**Filter Operators:**
| Operator | SQL | Example |
|----------|-----|---------|
| `eq` | `=` | `{ column: 'status', operator: 'eq', value: 'active' }` |
| `neq` | `!=` | `{ column: 'status', operator: 'neq', value: 'deleted' }` |
| `gt` | `>` | `{ column: 'count', operator: 'gt', value: 10 }` |
| `gte` | `>=` | `{ column: 'count', operator: 'gte', value: 10 }` |
| `lt` | `<` | `{ column: 'count', operator: 'lt', value: 100 }` |
| `lte` | `<=` | `{ column: 'count', operator: 'lte', value: 100 }` |
| `like` | `LIKE` | `{ column: 'name', operator: 'like', value: '%test%' }` |
| `ilike` | `ILIKE` | `{ column: 'name', operator: 'ilike', value: '%TEST%' }` |
| `in` | `IN` | `{ column: 'status', operator: 'in', value: ['a', 'b'] }` |
| `is_null` | `IS NULL` | `{ column: 'deleted_at', operator: 'is_null' }` |
| `not_null` | `IS NOT NULL` | `{ column: 'email', operator: 'not_null' }` |

#### `db.insert(table, data)`

Insert one or more rows.

```javascript
// Single row
const result = await db.insert('my_table', {
  name: 'Test',
  status: 'active'
});

// Multiple rows
const result = await db.insert('my_table', [
  { name: 'Test 1', status: 'active' },
  { name: 'Test 2', status: 'draft' }
]);

// result.rows contains inserted rows with IDs
```

#### `db.update(table, data, filters)`

Update rows matching filters.

```javascript
const result = await db.update(
  'my_table',
  { status: 'inactive', updated_at: new Date().toISOString() },  // SET
  { id: 123 }  // WHERE (simple object)
);

// Or with filter array
const result = await db.update(
  'my_table',
  { status: 'inactive' },
  [{ column: 'status', operator: 'eq', value: 'active' }]
);

// result.rowCount = number of updated rows
```

#### `db.delete(table, filters)`

Delete rows matching filters.

```javascript
const result = await db.delete('my_table', { id: 123 });

// Or with filter array
const result = await db.delete('my_table', [
  { column: 'status', operator: 'eq', value: 'deleted' },
  { column: 'created_at', operator: 'lt', value: '2026-01-01' }
]);

// result.rowCount = number of deleted rows
```

**⚠️ Important:** `db` can only access **workspace tables** (tables you created). It cannot access system tables like `funnel_contacts`, `funnel_events`, etc. For system data, use internal APIs via `fetch`.

---

### `platform`

Platform services for AI and email.

#### `platform.generateText(options)`

Generate text using AI (GPT-4o-mini).

```javascript
const result = await platform.generateText({
  userPrompt: "Write a LinkedIn post about podcasting",
  systemPrompt: "You are a social media expert. Be concise.",
  maxTokens: 500
});

const generatedText = result.text;
const usage = result.usage; // Token usage info
```

**Options:**
| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `userPrompt` | String | Yes* | The user's prompt |
| `systemPrompt` | String | No | System instructions |
| `messages` | Array | Yes* | Chat messages (alternative to userPrompt) |
| `maxTokens` | Number | No | Max tokens to generate |

*Either `userPrompt` or `messages` is required.

#### `platform.sendEmail(options)`

Send a transactional email.

```javascript
await platform.sendEmail({
  to: "user@example.com",
  subject: "Hello from my API",
  text: "This is the plain text version",
  html: "<h1>Hello!</h1><p>This is the HTML version</p>",
  from: "Custom Sender Name"  // Optional
});
```

**Options:**
| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `to` | String | Yes | Recipient email |
| `subject` | String | Yes | Email subject |
| `text` | String | Yes* | Plain text body |
| `html` | String | Yes* | HTML body |
| `from` | String | No | Sender name |

*At least one of `text` or `html` is required.

---

### `fetch(url, options)`

Make HTTP requests to external or internal URLs.

```javascript
// GET request
const response = await fetch("https://api.example.com/data");
const data = await response.json();

// POST request
const response = await fetch("https://api.example.com/create", {
  method: "POST",
  headers: {
    "Content-Type": "application/json"
  },
  body: JSON.stringify({ name: "Test" })
});
const result = await response.json();
```

**Response Methods:**
| Method | Description |
|--------|-------------|
| `response.json()` | Parse response as JSON |
| `response.text()` | Get response as text |
| `response.ok` | Boolean, true if status 200-299 |
| `response.status` | HTTP status code |

**⚠️ Limitation:** `response.headers.get()` is NOT available. If you need headers, you'll need to work around this.

---

### `console`

Logging functions. Output appears in hook execution logs.

```javascript
console.log("Info message", data);
console.error("Error message", error);
console.warn("Warning message");
```

---

### `JSON`

Standard JSON object.

```javascript
const obj = JSON.parse('{"key": "value"}');
const str = JSON.stringify({ key: "value" });
```

---

### `Date`

Standard Date object.

```javascript
const now = new Date();
const iso = now.toISOString();
const timestamp = Date.now();
```

---

### `Math`

Standard Math object.

```javascript
const random = Math.random();
const rounded = Math.round(3.7);
```

---

## What's NOT Available

| Feature | Status | Workaround |
|---------|--------|------------|
| `URLSearchParams` | ❌ | Manual query string building |
| `Buffer` | ❌ | Use base64 strings |
| `require()` | ❌ | All code must be inline |
| `import` | ❌ | All code must be inline |
| `process` | ❌ | Hardcode config values |
| `setTimeout` | ❌ | Not available |
| `setInterval` | ❌ | Not available |
| `__dirname` | ❌ | Not available |
| `fs` | ❌ | Use platform storage APIs |
| `path` | ❌ | Not available |
| `crypto` | ❌ | Not available |
| `response.headers.get()` | ❌ | Parse response as text |

---

## Helper Functions

Since some standard APIs aren't available, here are helper functions you can include in your server functions:

### Query String Builder

```javascript
// Replaces URLSearchParams
function buildQuery(params) {
  const parts = [];
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== null) {
      parts.push(encodeURIComponent(key) + "=" + encodeURIComponent(value));
    }
  }
  return parts.length > 0 ? "?" + parts.join("&") : "";
}

// Usage
const url = `https://api.example.com/data${buildQuery({ limit: 10, offset: 20 })}`;
// Result: https://api.example.com/data?limit=10&offset=20
```

### Safe JSON Parse

```javascript
function safeJsonParse(str, fallback = null) {
  try {
    return JSON.parse(str);
  } catch {
    return fallback;
  }
}
```

### Date Formatting

```javascript
function formatDate(date) {
  return new Date(date).toISOString().split('T')[0];
}

function daysAgo(days) {
  const date = new Date();
  date.setDate(date.getDate() - days);
  return date.toISOString();
}
```

---

## Error Handling

Always wrap your code in try-catch:

```javascript
try {
  // Your logic here
  const result = await riskyOperation();
  return respond(200, { success: true, data: result });

} catch (error) {
  // Log the error (appears in hook logs)
  console.error("API error:", error.message);

  // Return a clean error response
  return respond(500, {
    error: error.message,
    // Don't expose stack traces in production!
  });
}
```

---

## Execution Limits

| Limit | Value |
|-------|-------|
| Execution timeout | ~30 seconds |
| Memory | Limited (avoid large arrays) |
| Response size | ~1MB |
| Code size | ~64KB |

---

## Debugging

### View Logs

Ask the AI assistant:
```
Show me the logs for my-api
```

Or use the `get_hook_logs` tool.

### Test Execution

Ask the AI assistant:
```
Test the my-api server function with body { "action": "list" }
```

Or use the `test_server_function` tool.

### Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `URLSearchParams is not defined` | Using browser API | Use `buildQuery()` helper |
| `response.headers.get is not a function` | Using browser API | Parse response as text |
| `Table name must start with...` | Querying system table | Use internal API via fetch |
| `Cannot read property of undefined` | Missing null check | Add `|| {}` or `|| []` |

---

*See also:*
- [API Development Guide](./01-audos-api-development-guide.md)
- [Server Function Templates](./02-audos-server-function-templates.md)
