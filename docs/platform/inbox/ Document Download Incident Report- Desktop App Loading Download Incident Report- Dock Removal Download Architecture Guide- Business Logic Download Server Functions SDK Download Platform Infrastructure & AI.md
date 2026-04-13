# Audos Platform: Infrastructure & AI Capabilities

**Date:** March 6, 2025
**Document Type:** Technical Reference

---

## Table of Contents

1. [Infrastructure Overview](#1-infrastructure-overview)
2. [Server Functions Runtime](#2-server-functions-runtime)
3. [Database Technology](#3-database-technology)
4. [Frontend Hosting & CDN](#4-frontend-hosting--cdn)
5. [AI Capabilities](#5-ai-capabilities)
6. [Built-in Agent Chat](#6-built-in-agent-chat)
7. [Media & Video Services](#7-media--video-services)
8. [Integration Capabilities](#8-integration-capabilities)
9. [What Audos Handles vs What You Handle](#9-what-audos-handles-vs-what-you-handle)

---

## 1. Infrastructure Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        AUDOS PLATFORM STACK                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐             │
│  │   CLOUDFLARE    │  │  GOOGLE CLOUD   │  │   ELEVENLABS    │             │
│  │   CDN & SSL     │  │   PLATFORM      │  │   VOICE AI      │             │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘             │
│           │                    │                    │                       │
│           ▼                    ▼                    ▼                       │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                      AUDOS APPLICATION LAYER                         │  │
│  │                                                                      │  │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌────────────┐  │  │
│  │  │   Frontend   │ │   Server     │ │   Agent      │ │   Video    │  │  │
│  │  │   Hosting    │ │   Functions  │ │   Chat AI    │ │   Render   │  │  │
│  │  │  (React/TS)  │ │   (Hooks)    │ │  (Claude)    │ │ (Remotion) │  │  │
│  │  └──────────────┘ └──────────────┘ └──────────────┘ └────────────┘  │  │
│  │                                                                      │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                    │                                        │
│                                    ▼                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                        DATA LAYER                                    │  │
│  │                                                                      │  │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐                 │  │
│  │  │  PostgreSQL  │ │   Google     │ │   DNSimple   │                 │  │
│  │  │   Database   │ │   Cloud      │ │   Domain     │                 │  │
│  │  │              │ │   Storage    │ │   Registry   │                 │  │
│  │  └──────────────┘ └──────────────┘ └──────────────┘                 │  │
│  │                                                                      │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Server Functions Runtime

### Technology Stack

| Component | Technology | Details |
|-----------|------------|---------|
| **Runtime** | Node.js (serverless) | Likely Google Cloud Run or Cloud Functions |
| **Execution Model** | Isolated per-request | No persistent state between calls |
| **Timeout** | ~30-60 seconds | Long enough for AI generation |
| **Cold Start** | Minimal | Container-based, pre-warmed |

### NOT Cloudflare Workers

The server functions are **not** Cloudflare Workers because:
- They support `fetch()` with full Node.js APIs
- They have longer execution timeouts (Workers limit to 30s on paid plans)
- They have access to platform databases directly
- Video rendering runs on Cloud Run (confirmed in tools)

### Available in Server Functions

```javascript
// Request handling
request.body          // Parsed JSON body
request.query         // URL query params
request.method        // HTTP method
request.headers       // Request headers

// Database (PostgreSQL)
db.query(table, { filters, limit, orderBy })
db.insert(table, data)
db.update(table, filters, data)
db.delete(table, filters)
db.listTables()

// AI Services
platform.generateText({ prompt, maxTokens })  // Text generation (Claude/GPT)

// Communication
platform.sendEmail({ to, subject, text, html })

// HTTP (for calling your daemon)
fetch(url, options)   // Full fetch API

// Response
respond(statusCode, body)

// Standard JS
JSON, Date, Math, console, setTimeout, Promise
```

---

## 3. Database Technology

### PostgreSQL

| Aspect | Details |
|--------|---------|
| **Engine** | PostgreSQL (confirmed via SQL syntax support) |
| **Hosting** | Managed PostgreSQL (likely Google Cloud SQL or Supabase) |
| **Isolation** | Each workspace has its own schema |
| **Access Methods** | Platform APIs, `db.*` in hooks, direct SQL via `execute_sql` |

### Database Capabilities

```sql
-- Supported SQL features (read-only via execute_sql)
SELECT * FROM voice_profiles WHERE user_id = 'abc' ORDER BY created_at DESC;
SELECT COUNT(*) FROM reels GROUP BY status;
SELECT p.*, v.name as voice_name
FROM podcast_profiles p
JOIN voice_profiles v ON p.voice_id = v.id;

-- Workspace tables you can create:
CREATE TABLE via db_create_table tool:
- TEXT, INTEGER, BIGINT, DECIMAL
- BOOLEAN, TIMESTAMP, DATE
- JSON, UUID
- PRIMARY KEY, FOREIGN KEY, UNIQUE, NOT NULL
- Indexes (automatic and custom)
```

### System Tables (Platform-Managed)

| Table | Purpose |
|-------|---------|
| `funnel_contacts` | CRM contacts/leads |
| `funnel_events` | Analytics events (page views, clicks, etc.) |
| `ad_campaigns` | Meta ad campaign data |
| `ad_creatives` | Ad creative assets |
| `carousel_posts` | Social media carousel content |
| `community_posts` | User-generated community content |
| `boosters` | Automated message rules |

---

## 4. Frontend Hosting & CDN

### Technology Stack

| Component | Technology | Details |
|-----------|------------|---------|
| **Framework** | React + TypeScript | Compiled to JS bundle |
| **Build** | Platform compiler | Bundled with platform runtime |
| **CDN** | Cloudflare | Global edge distribution |
| **SSL** | Cloudflare (auto-provisioned) | Free SSL for custom domains |
| **Domains** | DNSimple (registration) + Cloudflare (DNS/CDN) | Full domain management |

### How Frontend Deployment Works

```
1. You edit React code (via Otto or GitHub sync)
          │
          ▼
2. Platform compiles TypeScript → JavaScript bundle
          │
          ▼
3. Bundle uploaded to Cloudflare CDN
          │
          ▼
4. Served globally with edge caching
          │
          ▼
5. Custom domain SSL auto-provisioned
```

### What Gets Hosted

- `Desktop.tsx` → Main layout shell
- `apps/*/App.tsx` → Your app components
- `components/*.tsx` → Shared components (EmailGate, AgentChat, etc.)
- `landing-pages/*.tsx` → Landing page(s)
- Static assets (images, fonts)

---

## 5. AI Capabilities

### Built-in AI Services

The platform provides several AI capabilities out of the box:

#### 1. Text Generation (Claude/GPT)

Available in server functions via `platform.generateText()`:

```javascript
// In a server function (hook)
const response = await platform.generateText({
  prompt: `Generate 3 interview questions for a podcast guest who is an expert in ${topic}`,
  maxTokens: 500
});

return respond(200, { questions: response });
```

#### 2. AI Image Generation (GPT-Image / Gemini)

Available via MCP tool `generate_image`:

```javascript
// Otto can generate images for you
// Prompt: "Generate an image of a podcast studio with warm lighting"
// Returns: GCS URL to the generated image
```

#### 3. AI Video Generation (Google Veo3)

Available via MCP tool `generate_video`:

- Generates 8-second video clips
- 16:9 or 9:16 aspect ratios
- Takes 1-2 minutes
- Auto-saves to workspace media

#### 4. Voice Synthesis (ElevenLabs)

Available via MCP tools for voiceover generation:

```javascript
// Available voices include:
// - Sarah: Mature, Reassuring, Confident (young female)
// - Roger: Laid-Back, Casual, Resonant (middle-aged male)
// - George: Warm, Captivating Storyteller (British, middle-aged male)
// - Laura: Enthusiast, Quirky Attitude (young female)
// - Charlie: Deep, Confident, Energetic (Australian, young male)
// ... and 50+ more voices

// Generates audio files that can be used in Remotion videos
```

#### 5. Background Music Generation (ElevenLabs Music)

Available presets:
- `corporate` - Professional, modern
- `tech` - Electronic, innovative
- `uplifting` - Inspirational, positive
- `calm` - Relaxed, peaceful
- `energetic` - High-energy, exciting
- `playful` - Fun, lighthearted
- `cinematic` - Dramatic, epic
- `lofi` - Chill, lo-fi beats

#### 6. Web Search & Research

```javascript
// Platform can search the web
// - Google search for research
// - Fetch and parse web pages
// - Stock photo search (Unsplash)
```

---

## 6. Built-in Agent Chat

The platform includes a **built-in AI agent chat** component (`AgentChat`) that you can leverage:

### What It Provides

```
┌─────────────────────────────────────────────────────────────────┐
│                     AGENT CHAT COMPONENT                        │
│                                                                 │
│  • Conversational AI interface (Claude-powered)                │
│  • Context-aware (knows about user's workspace)                │
│  • Can open apps via deep links                                │
│  • File access logging                                         │
│  • Session-aware (tracks conversation per user)                │
│                                                                 │
│  Props:                                                        │
│  - spaceId: string                                             │
│  - onFileAccess: (log) => void                                 │
│  - pendingMessage: string | null                               │
│  - onPendingMessageConsumed: () => void                        │
└─────────────────────────────────────────────────────────────────┘
```

### Using Agent Chat in Your App

The current `Desktop.tsx` already includes AgentChat. Users can:
1. Ask questions about the workspace
2. Get help navigating
3. Request actions (that Otto can perform)

### For Throughline: Custom AI Assistant

You could create a **custom AI assistant** specific to podcast creators by:

1. **Using Server Functions** to wrap AI calls with podcast-specific context
2. **Creating a custom chat UI** in your Throughline app that calls your hooks
3. **Leveraging `platform.generateText()`** with custom prompts

Example:

```javascript
// Hook: throughline-assistant
const { userMessage, context } = request.body;

const systemPrompt = `You are Throughline AI, an assistant for podcast creators.
You help with:
- Guest research and interview prep
- Voice profile analysis
- Caption generation for social media clips
- Show notes and timestamps

Current podcast: ${context.podcastName}
User's voice style: ${context.voiceStyle}
`;

const response = await platform.generateText({
  prompt: `${systemPrompt}\n\nUser: ${userMessage}\n\nAssistant:`,
  maxTokens: 1000
});

return respond(200, { reply: response });
```

---

## 7. Media & Video Services

### Storage (Google Cloud Storage)

| Feature | Details |
|---------|---------|
| **Provider** | Google Cloud Storage (GCS) |
| **URL Pattern** | `storage.googleapis.com/audos-images/...` |
| **Formats** | Images, videos, audio, documents |
| **Persistence** | Permanent (until deleted) |

### Video Rendering (Remotion on Cloud Run)

| Feature | Details |
|---------|---------|
| **Framework** | Remotion (React-based video) |
| **Runtime** | Google Cloud Run |
| **Output** | MP4 video files |
| **Duration** | Up to 60+ seconds |
| **Resolution** | 1920x1080 (landscape) or 1080x1920 (portrait) |

### Demo Video Pipeline

```
1. Design video composition (React/TSX)
          │
          ▼
2. Upload composition to GCS
          │
          ▼
3. Trigger Cloud Run render job
          │
          ▼
4. Remotion renders frames → video
          │
          ▼
5. Final video uploaded to GCS
          │
          ▼
6. Video URL returned (permanent)
```

---

## 8. Integration Capabilities

### Email (Transactional)

```javascript
// From server functions
await platform.sendEmail({
  to: 'user@example.com',
  subject: 'Your podcast is ready!',
  text: 'Plain text content',
  html: '<h1>HTML content</h1>'
});

// From frontend (via app skills API)
await fetch('/api/app-skills/email/send', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'x-workspace-id': 'workspace-id-here'
  },
  body: JSON.stringify({ to, subject, text, html })
});
```

### Scheduling (Cron & One-Time)

```javascript
// Schedule a recurring task
await fetch('/api/workspaces/{workspaceId}/schedules', {
  method: 'POST',
  body: JSON.stringify({
    name: 'Daily digest',
    frequency: 'daily',
    time: '09:00',
    timezone: 'America/New_York',
    actionType: 'hook',
    hookName: 'send-daily-digest'
  })
});

// Schedule a one-time email
await fetch('/api/workspaces/{workspaceId}/schedules/email', {
  method: 'POST',
  body: JSON.stringify({
    name: 'Welcome email',
    scheduledAt: '2025-03-10T14:00:00Z',
    email: { to, subject, text }
  })
});
```

### Payments (Stripe)

- Checkout sessions
- Subscriptions
- Invoices
- Coupons/promo codes

### Social Media

- Instagram/Facebook posting (via connected pages)
- Carousel generation
- Post scheduling

### Outreach

- Lead scouting
- Email drafting
- Contact management

---

## 9. What Audos Handles vs What You Handle

### Audos Handles (You Don't Need To)

| Capability | Audos Provides |
|------------|----------------|
| **Hosting** | Frontend (React) hosting on Cloudflare CDN |
| **SSL** | Automatic SSL for all domains |
| **Database** | Managed PostgreSQL with backups |
| **Authentication** | Email Gate (email-based auth) |
| **AI** | Text generation, image generation, voice synthesis |
| **Email** | Transactional email sending |
| **Payments** | Stripe integration |
| **Analytics** | Funnel tracking, session recording |
| **CRM** | Contact management |
| **Scheduling** | Cron jobs and one-time tasks |
| **Media** | Image/video storage on GCS |
| **Domains** | Registration, DNS, SSL provisioning |

### You Handle (Bring Your Own)

| Capability | Your Responsibility |
|------------|---------------------|
| **Complex Business Logic** | Host your own daemon (Go, Python, etc.) |
| **Custom ML/AI Models** | Run on your infrastructure |
| **Real-time Features** | WebSocket servers (if needed) |
| **Heavy Compute** | Long-running jobs on your servers |
| **Specialized Integrations** | APIs not built into Audos |

### Hybrid Architecture (Recommended for Throughline)

```
┌─────────────────────────────────────────────────────────────────┐
│                    AUDOS PLATFORM                               │
│  • Frontend hosting (React)                                     │
│  • Email Gate authentication                                    │
│  • Database (PostgreSQL)                                        │
│  • AI text generation                                           │
│  • Voiceover synthesis                                          │
│  • Email sending                                                │
│  • Wrapper hooks (thin)                                         │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               │ API calls via wrapper hooks
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                YOUR DAEMON (Railway/Fly.io/AWS)                 │
│  • Voice analysis algorithms                                    │
│  • Transcript processing                                        │
│  • Custom AI prompts with your fine-tuned models               │
│  • Integration with podcast hosting APIs                        │
│  • Anything requiring heavy compute                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## Summary: Platform Capabilities at a Glance

| Category | Technology | Available To |
|----------|------------|--------------|
| **Compute** | Node.js serverless (Cloud Run/Functions) | Server functions |
| **Database** | PostgreSQL (managed) | Server functions, Platform APIs |
| **CDN** | Cloudflare | Frontend hosting |
| **Storage** | Google Cloud Storage | Media, attachments |
| **AI Text** | Claude/GPT | Server functions via `platform.generateText()` |
| **AI Images** | GPT-Image, Gemini | Otto tools |
| **AI Video** | Google Veo3 | Otto tools |
| **AI Voice** | ElevenLabs | Otto tools (voiceover, music) |
| **Email** | Platform email service | Server functions, App skills API |
| **Payments** | Stripe | Platform APIs |
| **Domains** | DNSimple + Cloudflare | Platform tools |

---

*Document generated by Otto (Audos AI Assistant)*
*Last Updated: March 6, 2025*
