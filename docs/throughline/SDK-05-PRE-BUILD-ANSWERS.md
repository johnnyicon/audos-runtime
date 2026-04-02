# Audos Platform — Pre-Build Answers for Throughline

Answers to the pre-build questions for implementing Throughline features.

---

## Context

We're building three active feature areas in Throughline:

1. **Caption generation** (Studio app) — generate platform-specific social captions from a reel/clip, in two distinct voices
2. **Guest research and briefing** (Briefing app) — research a guest, generate a briefing document, send a follow-up/confirmation email
3. **Voice fingerprint** (Signature app) — upload transcripts/captions, train a voice model, refine via corrections

---

## Question 1 — The "Doc" Primitive

> **Q.** We've heard there's a "doc" component or primitive in the platform. What is it exactly?

### Answer

**There is no built-in "doc" primitive in the Audos platform.**

What you may have heard about is likely one of these:

| Concept | What it actually is |
|---------|---------------------|
| `useSpaceFiles()` | Hook for transient JSON data stored per-session |
| `useWorkspaceDB()` | Hook for persistent database tables (PostgreSQL) |
| Custom React components | You build your own document viewers/editors |

### Recommendation for Throughline

For briefing documents and generated content, **build a custom React component** that:
- Renders structured content (sections, lists, metadata)
- Supports inline editing via `contentEditable` or a rich text library
- Stores data in `useWorkspaceDB()` for persistence

```typescript
// Example: Briefing document structure stored in DB
interface BriefingDocument {
  id: number;
  guest_name: string;
  sections: {\n    title: string;
    content: string;
    editable: boolean;
  }[];
  created_at: string;
}
```

---

## Question 2 — Long-Form Generated Content Display

> **Q.** What's the recommended pattern for displaying AI-generated content with edit/copy actions?

### Answer

#### Storage Recommendation

| Use Case | Storage Method | Why |
|----------|----------------|-----|
| Draft content being edited | `useSpaceFiles()` | Transient, per-session, no DB overhead |
| Finalized captions/briefs | `useWorkspaceDB()` | Persistent, queryable, shared across sessions |
| Voice training samples | `useWorkspaceDB()` | Needs to persist across user sessions |

#### Recommended UI Pattern

```tsx
// Component pattern for AI-generated content with actions
function GeneratedSection({ title, content, onEdit, onRegenerate }) {
  const [isEditing, setIsEditing] = useState(false);
  const [localContent, setLocalContent] = useState(content);

  const handleCopy = () => {
    navigator.clipboard.writeText(localContent);
  };

  return (
    <div className="section">
      <div className="section-header">
        <h3>{title}</h3>
        <div className="actions">
          <button onClick={handleCopy}>Ⓜ Copy</button>
          <button onClick={() => setIsEditing(true)}>✏ Edit</button>
          <button onClick={onRegenerate}>🔊 Run</button>
        </div>
      </div>
      {isEditing ? (
        <textarea
          value={localContent}
          onChange={(e) => setLocalContent(e.target.value)}
          onBlur={() => {
            onEdit(localContent);
            setIsEditing(false);
          }}
        />
      ) : (
        <div className="content">{localContent}</div>
      )}
    </div>
  );
}
```

#### Streaming Text Generation

⁉ **Not currently supported.** The `platform.generateText()` API returns the complete response after generation finishes.

**Workaround:** Show a loading/generating state with a progress indicator while waiting for the response.

---

## Question 3 — Multi-Voice / Persona Support

> **Q.** How do we store and pass voice profiles to AI generation?

### Answer

#### ✅ System Prompt Support Confirmed

The `ai-api` hook **supports `systemPrompt`** as a separate parameter from `prompt`:

```typescript
// AI API request with system prompt + user prompt
const response = await fetch('/api/hooks/execute/workspace-{id}/ai-api', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    action: 'generate',
    systemPrompt: 'You are Kane, a podcast host...',  // ✅ Supported!
    prompt: 'Write an Instagram caption for this episode...'
  })
});
```

**Test result:** Passing `systemPrompt: "You are a pirate. Always respond in pirate speak."` returned correctly styled output: *"Ahoy there, matey! Greetings to ye across the seven seas!"*

#### Voice Profile Storage (Already Implemented)

Your workspace already has a `voice_profiles` table:

```sql
voice_profiles
├── id: serial (PK)
├── name: text                 -- "John Gonzales" or "So Good to Grow Good"
├── type: text                 -- "host" or "brand"
├── description: text         -- Voice style description
├── sample_count: integer     -- Number of training samples
├── is_trained: boolean       -- Whether model is ready
├── long_form_samples: json   -- Array of writing samples
└── voice_preview: text       -- Sample quote for preview
```

Current profiles:
- **John Gonzales** (host) — Personal voice for LinkedIn/Instagram
- **So Good to Grow Good** (brand) — Show brand voice

#### Recommended Pattern

```typescript
// 1. Fetch voice profile from DB
const profile = await db.query('voice_profiles', { filters: [{ column: 'name', operator: 'eq', value: 'John Gonzales' }] });

// 2. Build system prompt from profile data
const systemPrompt = `
You are writing as ${profile.name}.
Voice style: ${profile.description}

Examples of this voice:
${profile.long_form_samples?.map(s => s.text).join('\n\n')}
`;

// 3. Generate content with voice
const result = await aiApi.generate({
  systemPrompt,
  prompt: `Write an Instagram caption for: ${episodeSummary}`
});
```

---

## Question 4 — File Upload for Training Data

> **Q.** What's the recommended file upload pattern in Audos apps?

### Answer

#### Storage API Capabilities

The `storage-api` hook supports:

| Action | Description |
|--------|-------------|
| `upload` | Upload file from base64 data |
| `upload-from-url` | Upload file from URL |
| `list` | List all uploaded files |

**Storage target:** Google Cloud Storage (`gs://audos-images/workspace-media/{workspaceId}/`)

#### Upload Pattern

```typescript
// In your React app - file input handler
async function handleFileUpload(file: File) {
  // Convert to base64
  const base64 = await new Promise<string>((resolve) => {
    const reader = new FileReader();
    reader.onload = () => resolve((reader.result as string).split(',')[1]);
    reader.readAsDataURL(file);
  });

  // Upload via storage-api
  const response = await fetch('/api/hooks/execute/workspace-{id}/storage-api', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      action: 'upload',
      filename: file.name,
      contentType: file.type,
      base64
    })
  });

  const { url } = await response.json();
  return url; // GCS URL to store in DB
}
```

#### File Types Supported

| Category | Types |
|----------|------|
| Text | `.txt`, `.md`, `.csv`, `.json` |
| Documents | `.pdf`, `.docx` (requires parsing) |
| Audio | `.mp3`, `.wav`, `.m4a` |
| Video | `.mp4`, `.mov` |
| Images | `.png`, `.jpg`, `.gif` |

**Size limit:** 500MB per file

#### No Built-in File Picker

You need to build your own file input component:

```tsx
function FileUploader({ onUpload }) {
  return (
    <input
      type="file"
      accept=".txt,.md,.csv,.json"
      onChange={(e) => {
        const file = e.target.files?.[0];
        if (file) onUpload(file);
      }}
    />
  );
}
```

---

## Question 5 — Sending Emails with Dynamic Content

> **Q.** What does `platform.sendEmail()` support?

### Answer

#### Email API Capabilities

| Feature | Supported | Notes |
|---------|:---------:|-------|
| Plain text body | ✅ | `text` parameter |
| HTML body | ✅ | `html` parameter |
| Dynamic fields | ✅ | Build HTML with template literals |
| Custom From address | ❌ | Sends from Audos domain |
| Reply-To | ✅ | `replyTo` parameter |
| CC/BCC | ❌ | Not supported yet |
| Attachments | ❌ | Not supported yet |
| Send log | ❌ | No queryable log |

#### Example: Guest Follow-Up Email

```typescript
async function sendGuestConfirmation(guest: Guest, episode: Episode) {
  const html = `
    <h1>Confirmation: ${episode.title}</h1>
    <p>Hi ${guest.name},</p>
    <p>Thanks for confirming your appearance on <strong>${episode.showName}</strong>.</p>
    <h2>Recording Details</h2>
    <ul>
      <li><strong>Date:</strong> ${episode.recordingDate}</li>
      <li><strong>Time:</strong> ${episode.recordingTime} ${episode.timezone}</li>
      <li><strong>Platform:</strong> ${episode.platform}</li>
    </ul>
    <h2>Prep Materials</h2>
    <p><a href="${guest.briefingUrl}">View your briefing document</a></p>
    <h3>Discussion Topics</h3>
    <ol>
      ${episode.topics.map(t => `<li>${t}</li>`).join('')}
    </ol>
  ;

  await fetch('/api/hooks/execute/workspace-{id}/email-api', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      action: 'send',
      to: guest.email,
      subject: `Confirmed: ${episode.title} — ${episode.recordingDate}`,
      text: `Hi ${guest.name}, Thanks for confirming...`, // Plain text fallback
      html,
      replyTo: 'kane@sg2gg.com' // Your reply address
    })
  });
}
```

#### No Built-in Templates

Templates must be built in your app code. Consider creating a `email_templates` table in the DB if you want reusable, editable templates.

---

## Question 6 — Multi-Step Workflow UX

> **Q.** Is there a platform pattern for multi-step workflows?

### Answer

**No built-in wizard/workflow component.** You build this in your app.

#### Recommended Approach

| Option | Pros | Cons | When to use |
|--------|------|------|-------------|
| **Single app with state** | Simpler, shared context | Can get complex | Most cases |
| **Multiple apps** | Clear separation | Loses context between apps | Truly independent features |

#### State Persistence Pattern

```typescript
// Store workflow state in DB so user can resume
interface BriefingWorkflow {
  id: number;
  guest_name: string;
  current_step: 'search' | 'research' | 'brief' | 'email' | 'complete';
  search_results?: any;
  research_data?: any;
  brief_content?: any;
  email_sent?: boolean;
  updated_at: string;
}

// In your app
function BriefingApp() {
  const [workflow, setWorkflow] = useState<BriefingWorkflow | null>(null);
  
  // Load in-progress workflow on mount
  useEffect(() => {
    const incomplete = await db.query('briefing_workflows', {
      filters: [{ column: 'current_step', operator: 'neq', value: 'complete' }],
      orderBy: { column: 'updated_at', direction: 'desc' },
      limit: 1
    });
    if (incomplete[0]) setWorkflow(incomplete[0]);
  }, []);

  // Render current step
  switch (workflow?.current_step) {
    case 'search': return <SearchStep ... />;
    case 'research': return <ResearchStep ... />;
    case 'brief': return <BriefStep ... />;
    case 'email': return <EmailStep ... />;
    default: return <StartNewWorkflow ... />;
  }
}
```

---

## Question 7 — Platform AI Model

> **Q.** What model is `platform.generateText()` calling?

### Answer

#### Confirmed Via Testing

```json
{
  "success": true,
  "text": "Hello! How are you today?",
  "model": "gpt-4o-mini-2024-07-18",  // ← Current model
  "usage": {
    "promptTokens": 14,
    "completionTokens": 7,
    "totalTokens": 21
  }
}
```

| Question | Answer |
|----------|--------|
| **Model** | `gpt-4o-mini-2024-07-18` (OpenAI) |
| **More capable model?** | Not currently exposed via the API |
| **Rate limits?** | None documented — assume reasonable usage |
| **Cost implications?** | Included in platform — no per-call charge |
| **Large context?** | Yes — GPT-4o-mini supports 128k token context |

#### Large Context Example

```typescript
// You can pass a full transcript as part of the prompt
const transcript = await fetchTranscript(episodeId); // Could be 10000+ words

const result = await aiApi.generate({
  systemPrompt: 'You are a podcast content writer...',
  prompt: `
    Based on this episode transcript, write an Instagram caption:
    
    <transcript>
    ${transcript}
    </transcript>
    
    Focus on the most engaging moment...
  `
});
```

---

## Summary Table

| Question | Short Answer |
|----------|--------------|
| "Doc" primitive? | Doesn't exist — build custom components |
| Long-form content display? | Build sectioned components with edit/copy/regenerate actions |
| Multi-voice support? | ✅ `systemPrompt` supported — pass voice profile as system prompt |
| File upload? | Use `storage-api` → GCS — build own file picker UI |
| Email with dynamic content? | ✅ HTML supported — build templates in code |
| Multi-step workflow UX? | Build in single app with state persistence |
| AI model? | `gpt-4o-mini` with 128k context — can handle full transcripts |

---

## Next Steps for Implementation

1. **Signature App**: Build file upload UI → store samples in `voice_profiles.long_form_samples`
2. **Studio App**: Build voice profile selector → generate with `systemPrompt` → sectioned output with edit/copy actions
3. **Briefing App**: Build workflow state machine → use `web-api` for research → generate brief → send email with `email-api`

---

*Generated for Throughline SDK — April 2026*