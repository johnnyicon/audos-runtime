# Throughline API Documentation

This folder contains documentation for all external APIs available for the Throughline workspace.

## Available APIs

| API | Endpoint | Purpose |
|-----|----------|---------|
| [Database API](./database-api.md) | `/db-api` | Store and retrieve app data — episodes, guests, generated content, activity |
| [AI API](./ai-generation-api.md) | `/ai-api` | Generate text content — social posts, captions, summaries, interview questions |
| [Email API](./email-api.md) | `/email-api` | Send transactional emails — guest briefings, notifications, reminders |
| [CRM API](./crm-api.md) | `/crm-api` | Manage contacts and leads — potential guests, subscribers, outreach tracking |
| [Analytics API](./analytics-api.md) | `/analytics-api` | Track visitor behavior and conversions — traffic, signups, app usage |
| [Storage API](./storage-api.md) | `/storage-api` | Upload and manage files — audio clips, images, documents, exports |
| [Scheduler API](./scheduler-api.md) | `/scheduler-api` | Schedule tasks — social post timing, recurring jobs, reminder emails |
| [Web API](./web-api.md) | `/web-api` | Fetch content from the web — guest research, bios, trending topics |

## Base URL

All APIs use the same base URL pattern:

```
https://audos.com/api/hooks/execute/workspace-351699/{endpoint}
```

## Authentication

Currently, these endpoints are open (no API key required). They are scoped to the Throughline workspace.

## Quick Start

```bash
# List all database tables
curl -X POST "https://audos.com/api/hooks/execute/workspace-351699/db-api" \
  -H "Content-Type: application/json" \
  -d '{"action": "list-tables"}'

# Generate AI content
curl -X POST "https://audos.com/api/hooks/execute/workspace-351699/ai-api" \
  -H "Content-Type: application/json" \
  -d '{"action": "generate", "prompt": "Write a LinkedIn post about podcasting"}'

# List contacts
curl -X POST "https://audos.com/api/hooks/execute/workspace-351699/crm-api" \
  -H "Content-Type: application/json" \
  -d '{"action": "list", "limit": 10}'
```

## How the APIs Work Together

Here's a real end-to-end workflow a local app might run:

```
[Guest Research & Prep]
1. WEB API       → Fetch guest's LinkedIn, website, past interviews
2. AI API        → Generate suggested interview questions from research
3. DATABASE API  → Save research session to `guest_prep_research_sessions`
4. EMAIL API     → Send briefing doc to yourself and the guest
5. SCHEDULER API → Schedule a reminder email 24h before recording

[After Recording]
6. DATABASE API  → Save episode transcript to `studio_episodes`
7. AI API        → Generate social posts for LinkedIn, Twitter, Instagram
8. DATABASE API  → Save generated content to `studio_generated_content`
9. STORAGE API   → Upload audiogram images, get back a URL
10. ANALYTICS API → Check how the last episode's posts performed
```

## Quick Test

Run [`test-apis.py`](./test-apis.py) to verify all 6 APIs are reachable and returning expected responses:

```bash
python3 docs/audos-api/test-apis.py
```

## Quick Start

- **Workspace ID:** `8f1ad824-832f-4af8-b77e-ab931a250625`
- **Workspace Number:** `351699`
- **Live URLs:**
  - Landing Page: https://www.trythroughline.com
  - App/Space: https://app.trythroughline.com

---

*Last updated: 2026-03-31*

