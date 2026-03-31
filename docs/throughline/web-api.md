# Web API

> **Endpoint:** `https://audos.com/api/hooks/execute/workspace-351699/web-api`
>
> **Method:** `POST`
>
> **Content-Type:** `application/json`

Fetch and analyze web pages for podcast research workflows.

---

## Actions

| Action | Purpose | Best For |
|--------|---------|----------|
| `fetch` | Full page text extraction | Static/server-rendered pages |
| `metadata` | Open Graph & meta tags only | JS-rendered SPAs, fast lookups |
| `extract` | Structured data: headings, links, meta, content | Understanding page structure |
| `analyze` | Full research summary | Podcast guest prep |

> **Note:** `search` was removed. It returned a 501 — the underlying endpoint doesn't exist. Use `fetch`/`analyze` with specific URLs instead.

---

### fetch

Fetch and extract full text content from a URL. Now includes JS-rendered page detection.

**Request:**
```json
{
  "action": "fetch",
  "url": "https://example.com/article"
}
```

**Response (static page):**
```json
{
  "success": true,
  "url": "https://example.com/article",
  "title": "Article Title",
  "content": "The extracted text content of the page...",
  "contentLength": 5432,
  "rawLength": 28248,
  "isJsRendered": false
}
```

**Response (JS-rendered SPA):**
```json
{
  "success": true,
  "url": "https://www.trythroughline.com",
  "title": "Throughline",
  "content": "Throughline",
  "contentLength": 11,
  "rawLength": 28248,
  "isJsRendered": true,
  "warning": "This page appears to be JavaScript-rendered (SPA). The content is loaded dynamically and cannot be extracted via server-side fetch. Try the 'metadata' action to get Open Graph tags instead."
}
```

> When `isJsRendered: true`, switch to the `metadata` or `analyze` action instead.

---

### metadata

Extracts Open Graph and meta tags only. Fast and works on JS-rendered pages because OG tags are in the initial HTML.

**Request:**
```json
{
  "action": "metadata",
  "url": "https://example.com"
}
```

**Response:**
```json
{
  "success": true,
  "url": "https://example.com",
  "title": "Example Page",
  "openGraph": {
    "og:title": "Example Page",
    "og:description": "A description",
    "og:image": "https://example.com/image.jpg"
  },
  "meta": {
    "description": "Page description",
    "author": "John Doe"
  }
}
```

---

### extract

Extracts structured data including headings, links, meta tags, and stripped text content.

**Request:**
```json
{
  "action": "extract",
  "url": "https://example.com"
}
```

**Response:**
```json
{
  "success": true,
  "url": "https://example.com",
  "title": "Example Page",
  "headings": ["Welcome", "About Us", "Contact"],
  "links": [
    { "href": "/about", "text": "About" },
    { "href": "/contact", "text": "Contact Us" }
  ],
  "openGraph": { "og:title": "...", "og:description": "..." },
  "meta": { "description": "..." },
  "content": "stripped text content...",
  "contentLength": 12345
}
```

---

### analyze

Full research summary optimized for podcast guest prep. Combines metadata, key topics, and a content preview.

**Request:**
```json
{
  "action": "analyze",
  "url": "https://guest-example.com/about"
}
```

**Response:**
```json
{
  "success": true,
  "url": "https://guest-example.com/about",
  "research": {
    "title": "Jane Expert - About",
    "description": "Jane is a leading expert in...",
    "image": "https://guest-example.com/photo.jpg",
    "keyTopics": ["AI", "Machine Learning", "Startups"],
    "contentPreview": "First 1000 chars of stripped content..."
  },
  "isJsRendered": false
}
```

---

## JS-Rendered Page Detection

Server-side fetch cannot execute JavaScript. When a page is a SPA (React, Vue, etc.), the raw HTML contains almost no visible content.

**Detection logic:** if `rawLength > 5000` and `contentLength < 500` → `isJsRendered: true`

**Workarounds:**
1. Use `metadata` — OG tags are always in the initial HTML
2. Try a blog or press page URL on the same domain (often server-rendered)
3. For LinkedIn/Twitter/Instagram, use their official APIs

---

## Use Cases

1. **Guest research** — `analyze` a guest's website or bio page before recording
2. **Show prep** — `fetch` articles to summarize with the AI API
3. **Competitive analysis** — `extract` headings and structure from competitor sites
4. **Fast lookups** — `metadata` for OG image, title, description on any URL
5. **Link verification** — `fetch` to confirm show note links are live

---

*Part of the [Throughline API](./README.md)*
