# Audos Server Function Templates

> **Copy-paste templates for common API patterns**

---

## Table of Contents

1. [Database CRUD API](#database-crud-api)
2. [AI Generation API](#ai-generation-api)
3. [Email API](#email-api)
4. [CRM/Contacts API](#crmcontacts-api)
5. [Analytics API](#analytics-api)
6. [File Storage API](#file-storage-api)
7. [Task Scheduler API](#task-scheduler-api)
8. [Web Fetch API](#web-fetch-api)

---

## Database CRUD API

Full create, read, update, delete operations for workspace tables.

```javascript
const { action, table, data, filters, columns, orderBy, limit = 50, offset = 0 } = request.body || {};

if (!action) {
  return respond(400, {
    error: "Missing required field: action",
    actions: ["list-tables", "describe", "query", "insert", "update", "delete"]
  });
}

try {
  // List all tables
  if (action === "list-tables") {
    const tables = await db.listTables();
    return respond(200, {
      success: true,
      tables,
      count: tables.length
    });
  }

  // Describe table schema
  if (action === "describe") {
    if (!table) {
      return respond(400, { error: "Missing required field: table" });
    }
    const schema = await db.describeTable(table);
    return respond(200, {
      success: true,
      table,
      schema
    });
  }

  // Query table
  if (action === "query") {
    if (!table) {
      return respond(400, { error: "Missing required field: table" });
    }

    const result = await db.query(table, {
      columns,
      filters,
      orderBy,
      limit,
      offset
    });

    return respond(200, {
      success: true,
      table,
      rows: result.rows || result,
      count: (result.rows || result).length
    });
  }

  // Insert row(s)
  if (action === "insert") {
    if (!table) {
      return respond(400, { error: "Missing required field: table" });
    }
    if (!data) {
      return respond(400, { error: "Missing required field: data" });
    }

    const result = await db.insert(table, data);

    return respond(201, {
      success: true,
      table,
      inserted: Array.isArray(data) ? data.length : 1,
      rows: result.rows || result
    });
  }

  // Update row(s)
  if (action === "update") {
    if (!table) {
      return respond(400, { error: "Missing required field: table" });
    }
    if (!filters || filters.length === 0) {
      return respond(400, { error: "Missing required field: filters (required to prevent accidental mass updates)" });
    }
    if (!data) {
      return respond(400, { error: "Missing required field: data" });
    }

    const result = await db.update(table, data, filters);

    return respond(200, {
      success: true,
      table,
      updated: result.rowCount || 0
    });
  }

  // Delete row(s)
  if (action === "delete") {
    if (!table) {
      return respond(400, { error: "Missing required field: table" });
    }
    if (!filters || filters.length === 0) {
      return respond(400, { error: "Missing required field: filters (required to prevent accidental mass deletes)" });
    }

    const result = await db.delete(table, filters);

    return respond(200, {
      success: true,
      table,
      deleted: result.rowCount || 0
    });
  }

  return respond(400, {
    error: `Unknown action: ${action}`,
    actions: ["list-tables", "describe", "query", "insert", "update", "delete"]
  });

} catch (error) {
  console.error("Database API error:", error.message);
  return respond(500, { error: error.message });
}
```

---

## AI Generation API

Generate text content using the platform's AI capabilities.

```javascript
const { action, prompt, systemPrompt, messages, maxTokens = 1000 } = request.body || {};

if (!action) {
  return respond(400, {
    error: "Missing required field: action",
    actions: ["generate"]
  });
}

try {
  if (action === "generate") {
    if (!prompt) {
      return respond(400, { error: "Missing required field: prompt" });
    }

    const options = {
      userPrompt: prompt
    };

    if (systemPrompt) {
      options.systemPrompt = systemPrompt;
    }

    if (maxTokens) {
      options.maxTokens = maxTokens;
    }

    const result = await platform.generateText(options);

    return respond(200, {
      success: true,
      text: result.text,
      usage: result.usage
    });
  }

  return respond(400, { error: `Unknown action: ${action}` });

} catch (error) {
  console.error("AI API error:", error.message);
  return respond(500, { error: error.message });
}
```

---

## Email API

Send transactional emails.

```javascript
const { action, to, subject, text, html, from } = request.body || {};

if (!action) {
  return respond(400, {
    error: "Missing required field: action",
    actions: ["send"]
  });
}

try {
  if (action === "send") {
    if (!to) {
      return respond(400, { error: "Missing required field: to" });
    }
    if (!subject) {
      return respond(400, { error: "Missing required field: subject" });
    }
    if (!text && !html) {
      return respond(400, { error: "Missing required field: text or html" });
    }

    const emailOptions = { to, subject };
    if (text) emailOptions.text = text;
    if (html) emailOptions.html = html;
    if (from) emailOptions.from = from;

    await platform.sendEmail(emailOptions);

    return respond(200, {
      success: true,
      message: `Email sent to ${to}`
    });
  }

  return respond(400, { error: `Unknown action: ${action}` });

} catch (error) {
  console.error("Email API error:", error.message);
  return respond(500, { error: error.message });
}
```

---

## CRM/Contacts API

Manage contacts and leads via the internal CRM API.

```javascript
const { action, limit = 50, days, hasEmail, contactId, email, name, phone, instagram, source, addTags, removeTags, tags, filter } = request.body || {};

if (!action) {
  return respond(400, {
    error: "Missing required field: action",
    actions: ["list", "create", "update", "add-tags", "remove-tags"]
  });
}

// IMPORTANT: Replace with your workspace ID
const workspaceId = "YOUR-WORKSPACE-ID-HERE";
const baseUrl = "https://audos.com";

// Helper to build query strings (URLSearchParams not available in runtime)
function buildQuery(params) {
  const parts = [];
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== null) {
      parts.push(encodeURIComponent(key) + "=" + encodeURIComponent(value));
    }
  }
  return parts.length > 0 ? "?" + parts.join("&") : "";
}

try {
  if (action === "list") {
    const params = { limit };
    if (days) params.days = days;
    if (hasEmail !== undefined) params.hasEmail = hasEmail;

    const url = `${baseUrl}/api/crm/contacts/${workspaceId}${buildQuery(params)}`;
    const response = await fetch(url);
    const data = await response.json();

    return respond(200, {
      success: true,
      contacts: data.contacts || [],
      total: data.total,
      count: (data.contacts || []).length
    });
  }

  if (action === "create") {
    if (!email) {
      return respond(400, { error: "Missing required field: email" });
    }

    const url = `${baseUrl}/api/crm/contacts/${workspaceId}`;
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, name, phone, instagram, source })
    });
    const data = await response.json();

    return respond(201, {
      success: true,
      contact: data.contact || data,
      message: "Contact created successfully"
    });
  }

  if (action === "update") {
    if (!contactId) {
      return respond(400, { error: "Missing required field: contactId" });
    }

    const url = `${baseUrl}/api/crm/contacts/${workspaceId}/${contactId}`;
    const body = {};
    if (name) body.name = name;
    if (email) body.email = email;
    if (phone) body.phone = phone;
    if (instagram) body.instagram = instagram;
    if (addTags) body.addTags = addTags;
    if (removeTags) body.removeTags = removeTags;

    const response = await fetch(url, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body)
    });
    const data = await response.json();

    return respond(200, {
      success: true,
      contact: data.contact || data,
      message: "Contact updated successfully"
    });
  }

  if (action === "add-tags" || action === "remove-tags") {
    if (!tags || tags.length === 0) {
      return respond(400, { error: "Missing required field: tags" });
    }
    if (!filter) {
      return respond(400, { error: "Missing required field: filter" });
    }

    const url = `${baseUrl}/api/crm/contacts/${workspaceId}/bulk-tag`;
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        action: action === "add-tags" ? "add" : "remove",
        tags,
        filter
      })
    });
    const data = await response.json();

    return respond(200, {
      success: true,
      updated: data.updated || 0,
      message: data.message
    });
  }

  return respond(400, { error: `Unknown action: ${action}` });

} catch (error) {
  console.error("CRM API error:", error.message);
  return respond(500, { error: error.message });
}
```

---

## Analytics API

Access visitor metrics and funnel data.

```javascript
const { action, days = 30, startDate, endDate, eventType, limit = 50, hasEmail } = request.body || {};

if (!action) {
  return respond(400, {
    error: "Missing required field: action",
    actions: ["overview", "funnel", "events", "sessions"]
  });
}

// IMPORTANT: Replace with your workspace ID
const workspaceId = "YOUR-WORKSPACE-ID-HERE";
const baseUrl = "https://audos.com";

function buildQuery(params) {
  const parts = [];
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== null) {
      parts.push(encodeURIComponent(key) + "=" + encodeURIComponent(value));
    }
  }
  return parts.length > 0 ? "?" + parts.join("&") : "";
}

try {
  if (action === "overview" || action === "funnel") {
    const contactsUrl = `${baseUrl}/api/crm/contacts/${workspaceId}${buildQuery({ limit: 1000, days })}`;
    const contactsResp = await fetch(contactsUrl);
    const contactsData = await contactsResp.json();

    const contacts = contactsData.contacts || [];
    const totalContacts = contactsData.total || contacts.length;
    const emailCount = contactsData.emailCount || contacts.filter(c => c.email).length;

    const eventCounts = {};
    contacts.forEach(contact => {
      (contact.actions || []).forEach(action => {
        eventCounts[action] = (eventCounts[action] || 0) + 1;
      });
    });

    if (action === "overview") {
      return respond(200, {
        success: true,
        period: { days, startDate, endDate },
        metrics: {
          totalContacts,
          emailCount,
          recentCount: contactsData.recentCount || 0,
          conversionRate: totalContacts > 0
            ? ((emailCount / totalContacts) * 100).toFixed(1) + '%'
            : '0%',
          eventsByType: eventCounts
        }
      });
    } else {
      return respond(200, {
        success: true,
        period: { days, startDate, endDate },
        funnel: eventCounts,
        totalContacts,
        emailCount
      });
    }
  }

  if (action === "events") {
    const contactsUrl = `${baseUrl}/api/crm/contacts/${workspaceId}${buildQuery({ limit, days, includeJourney: true })}`;
    const contactsResp = await fetch(contactsUrl);
    const contactsData = await contactsResp.json();

    const allEvents = [];
    (contactsData.contacts || []).forEach(contact => {
      (contact.journey || []).forEach(event => {
        if (!eventType || eventType === 'all' || event.eventType === eventType) {
          allEvents.push({
            id: event.id,
            eventType: event.eventType,
            contactId: contact.id,
            contactEmail: contact.email,
            createdAt: event.createdAt
          });
        }
      });
    });

    allEvents.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

    return respond(200, {
      success: true,
      eventType: eventType || 'all',
      events: allEvents.slice(0, limit),
      count: allEvents.length
    });
  }

  if (action === "sessions") {
    const params = { limit, days };
    if (hasEmail !== undefined) params.hasEmail = hasEmail;

    const contactsUrl = `${baseUrl}/api/crm/contacts/${workspaceId}${buildQuery(params)}`;
    const contactsResp = await fetch(contactsUrl);
    const contactsData = await contactsResp.json();

    const sessions = (contactsData.contacts || []).map(c => ({
      id: c.id,
      email: c.email,
      name: c.name,
      firstSeen: c.firstSeen,
      lastSeen: c.lastSeen,
      source: c.sourceCategory,
      actions: c.actions,
      eventCount: c.eventCount
    }));

    return respond(200, {
      success: true,
      sessions,
      count: sessions.length,
      total: contactsData.total
    });
  }

  return respond(400, { error: `Unknown action: ${action}` });

} catch (error) {
  console.error("Analytics API error:", error.message);
  return respond(500, { error: error.message });
}
```

---

## File Storage API

Upload and manage files.

```javascript
const { action, filename, contentType, base64, url, category = "attachment", description, limit = 20 } = request.body || {};

if (!action) {
  return respond(400, {
    error: "Missing required field: action",
    actions: ["upload", "list"]
  });
}

// IMPORTANT: Replace with your workspace ID
const workspaceId = "YOUR-WORKSPACE-ID-HERE";
const baseUrl = "https://audos.com";

try {
  if (action === "upload") {
    if (!filename) {
      return respond(400, { error: "Missing required field: filename" });
    }
    if (!contentType) {
      return respond(400, { error: "Missing required field: contentType" });
    }
    if (!base64 && !url) {
      return respond(400, { error: "Missing required field: base64 or url" });
    }

    const uploadUrl = `${baseUrl}/api/workspace-media/${workspaceId}/upload`;
    const body = { filename, contentType, category };
    if (description) body.description = description;
    if (base64) body.base64 = base64;
    if (url) body.url = url;

    const response = await fetch(uploadUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body)
    });
    const data = await response.json();

    return respond(201, {
      success: true,
      url: data.url,
      mediaId: data.mediaId,
      message: "File uploaded successfully"
    });
  }

  if (action === "list") {
    const listUrl = `${baseUrl}/api/workspace-media/${workspaceId}?limit=${limit}`;
    if (category !== "all") {
      listUrl += `&category=${category}`;
    }

    const response = await fetch(listUrl);
    const data = await response.json();

    return respond(200, {
      success: true,
      files: data.media || data,
      count: (data.media || data).length
    });
  }

  return respond(400, { error: `Unknown action: ${action}` });

} catch (error) {
  console.error("Storage API error:", error.message);
  return respond(500, { error: error.message });
}
```

---

## Task Scheduler API

Schedule tasks, cron jobs, and delayed emails.

```javascript
const { action, name, schedule, taskType, payload, taskId } = request.body || {};

if (!action) {
  return respond(400, {
    error: "Missing required field: action",
    actions: ["create", "list", "cancel", "pause", "resume"]
  });
}

// IMPORTANT: Replace with your workspace ID
const workspaceId = "YOUR-WORKSPACE-ID-HERE";
const baseUrl = "https://audos.com";

try {
  if (action === "create") {
    if (!name) {
      return respond(400, { error: "Missing required field: name" });
    }
    if (!schedule) {
      return respond(400, { error: "Missing required field: schedule" });
    }
    if (!taskType) {
      return respond(400, { error: "Missing required field: taskType (cron, once, email)" });
    }

    const createUrl = `${baseUrl}/api/scheduler/${workspaceId}/tasks`;
    const response = await fetch(createUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name, schedule, taskType, payload })
    });
    const data = await response.json();

    return respond(201, {
      success: true,
      task: data.task || data,
      message: "Task created successfully"
    });
  }

  if (action === "list") {
    const listUrl = `${baseUrl}/api/scheduler/${workspaceId}/tasks`;
    const response = await fetch(listUrl);
    const data = await response.json();

    return respond(200, {
      success: true,
      tasks: data.tasks || data,
      count: (data.tasks || data).length
    });
  }

  if (action === "cancel" || action === "pause" || action === "resume") {
    if (!taskId) {
      return respond(400, { error: "Missing required field: taskId" });
    }

    const updateUrl = `${baseUrl}/api/scheduler/${workspaceId}/tasks/${taskId}`;
    const response = await fetch(updateUrl, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ status: action === "cancel" ? "cancelled" : (action === "pause" ? "paused" : "active") })
    });
    const data = await response.json();

    return respond(200, {
      success: true,
      task: data.task || data,
      message: `Task ${action}d successfully`
    });
  }

  return respond(400, { error: `Unknown action: ${action}` });

} catch (error) {
  console.error("Scheduler API error:", error.message);
  return respond(500, { error: error.message });
}
```

---

## Web Fetch API

Fetch web pages and extract content.

```javascript
const { action, url } = request.body || {};

if (!action) {
  return respond(400, {
    error: "Missing required field: action",
    actions: ["fetch"]
  });
}

try {
  if (action === "fetch") {
    if (!url) {
      return respond(400, { error: "Missing required field: url" });
    }

    const response = await fetch(url);
    const text = await response.text();

    // Extract title from HTML
    let title = url;
    const titleMatch = text.match(/<title[^>]*>([^<]+)<\/title>/i);
    if (titleMatch) {
      title = titleMatch[1].trim();
    }

    // Strip HTML tags
    const content = text
      .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
      .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '')
      .replace(/<[^>]+>/g, ' ')
      .replace(/\s+/g, ' ')
      .trim()
      .substring(0, 50000);

    return respond(200, {
      success: true,
      url,
      title,
      content,
      contentLength: content.length,
      rawLength: text.length
    });
  }

  return respond(400, { error: `Unknown action: ${action}` });

} catch (error) {
  console.error("Web API error:", error.message);
  return respond(500, { error: error.message });
}
```

---

## Usage Examples

### Creating a Server Function

Ask the AI assistant:

```
Create a server function called "my-api" using the Database CRUD API template
```

Or specify the code directly:

```
Create a server function called "my-api" with this code:
[paste template here]
```

### Testing

```
Test the my-api server function with body { "action": "list-tables" }
```

### Calling from External Code

```python
import requests

response = requests.post(
    "https://audos.com/api/hooks/execute/workspace-XXXXX/my-api",
    json={"action": "list-tables"}
)
print(response.json())
```

---

*See also:*
- [API Development Guide](./01-audos-api-development-guide.md)
- [Runtime Reference](./03-audos-runtime-reference.md)
