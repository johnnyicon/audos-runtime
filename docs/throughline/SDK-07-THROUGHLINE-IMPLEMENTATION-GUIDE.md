# Throughline Implementation Guide

> Practical patterns for building the three core feature areas

---

## Feature 1: Caption Generation (Studio App)

Generate platform-specific social captions from a reel/clip in two distinct voices.

### Database Schema

```sql
-- Already exists
reels (id, title, transcript, episode_number, created_at)
captions (id, reel_id, platform, voice_type, content, status, created_at)
voice_profiles (id, name, type, description, voice_preview)
```

### Workflow Steps

```
1. User enters/uploads reel transcript
↓ Save to `reels` table

2. User selects platforms (Instagram, LinkedIn, Twitter)
↓ Store selection in component state

3. Click "Generate Captions"
↓ For each platform × each voice (brand, personal)
↓ Call ai-api with voice profile as systemPrompt
↓ Save to `captions` table

4. Display results in side-by-side cards
── ──────────────────────────
Studio App

┌─────────────────┐ ┌─────────────────┐
│ SG2GG Brand         │ │ Kane Personal      │
│ (Instagram)       │ │ (Instagram)       │
│─────────────────┤ │─────────────────┤
│ "Listen to our..." │ │ "I sat down with." │
│
│ [Copy] [Edit]     │ │ [Copy] [Edit]     │
└─────────────────┘ └─────────────────┘
```

### Implementation Code

```typescript
// Studio.tsx - Caption Generation

interface GenerationRequest {
  reelId: number;
  transcript: string;
  platforms: ('instagram' | 'linkedin' | 'twitter')[];
  voices: ('brand' | 'personal')[];
}

// 1. Fetch voice profiles on mount
const fetchVoiceProfiles = async () => {
  const response = await fetch(`${API_BASE}/db-api`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      action: 'query',
      table: 'voice_profiles'
    })
  });
  return response.json();
};

// 2. Generate caption for specific platform + voice
const generateCaption = async (
  transcript: string,
  platform: string,
  voiceProfile: VoiceProfile
) => {
  // Platform-specific guidelines
  const platformGuides = {
    instagram: 'Keep under 2200 chars. Use emojis sparingly. Start with a hook.',
    linkedin: 'Professional tone. Lead with insight. Under 3000 chars.',
    twitter: 'Concise. Under 280 chars. Sharp, punchy hook.'
  };

  const response = await fetch(`${API_BASE}/ai-api`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      action: 'generate',
      systemPrompt: `You are writing in the voice of "${voiceProfile.name}".
  
Characteristics: ${voiceProfile.description}

Sample of this voice:
"${voiceProfile.voice_preview}"

Platform guidelines: ${platformGuides[platform]}`,
      prompt: `Write a ${platform} caption for this podcast clip:

${transcript}`
    })
  });

  const data = await response.json();
  return data.text;
};

// 3. Save generated caption to database
const saveCaption = async (
  reelId: number,
  platform: string,
  voiceType: string,
  content: string
) => {
  await fetch(`${API_BASE}/db-api`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      action: 'insert',
      table: 'captions',
      data: {
        reel_id: reelId,
        platform,
        voice_type: voiceType,
        content,
        status: 'draft'
      }
    })
  });
};
```

---

## Feature 2: Guest Research & Briefing (Briefing App)

Research a guest, generate a briefing document, and send follow-up email.

### Workflow State Machine

```
┌────────────┐     ┌──────────────┐     ┌─────────────┐     ┌─────────────┐
│   Step 1    │ ─────│    Step 2      │ ────• │   Step 3      │ ────│   Step 4     │
│  Guest Info  │      │  Research       │      │  Gen Briefing  │     │  Send Email  │
└────────────┘     └──────────────┘     └─────────────┘     └─────────────┘

Persist state in `guest_briefings` table with `status` field
```

### Database Schema

```sql
-- Needs to be created
guest_briefings (
  id serial PRIMARY KEY,
  guest_name text NOT NULL,
  guest_email text,
  guest_linkedin text,
  guest_bio text,
  episode_title text,
  recording_date timestamp,
  
  -- Workflow state
  status text DEFAULT 'draft',  -- draft, researching, briefing, sent, complete
  
  -- Research data
  research_data jsonb,  -- { articles: [], social: [], keyTopics: [] }
  
  -- Generated content
  briefing_content text,  -- Markdown briefing document
  prep_questions text[],
  
  -- Email tracking
  email_sent_at timestamp,
  
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now()
)
```

### Implementation Code

```typescript
// Briefing.tsx - Guest Research Workflow

type BriefingStatus = 'draft' | 'researching' | 'briefing' | 'sent' | 'complete';

// Step 2: Research guest using web-api
const researchGuest = async (
  guestName: string,
  linkedInUrl: string
) => {
  // Fetch LinkedIn profile data
  const profileResponse = await fetch(`${API_BASE}/web-api`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      action: 'extract',
      url: linkedInUrl,
      selectors: {
        headline: '.top-card-layout__headline',
        about: '.about-section',
        experience: '.experience-section'
      }
    })
  });

  // Analyze with AI to extract key topics
  const analysisResponse = await fetch(`${API_BASE}/web-api`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      action: 'analyze',
      url: linkedInUrl,
      questions: [
        'What are this persons main areas of expertise?',
        'What recent projects have they been involved in?',
        'What topics would make for an engaging podcast conversation?'
      ]
    })
  });

  return {
    profile: await profileResponse.json(),
    analysis: await analysisResponse.json()
  };
};

// Step 3: Generate briefing document
const generateBriefing = async (briefingData: BriefingData) => {
  const response = await fetch(`${API_BASE}/ai-api`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      action: 'generate',
      systemPrompt: `You are a podcast research assistant for "So Good to Grow Good" podcast.
Create a comprehensive briefing document in Markdown format with these sections:

1. **Guest Overview** - Bio, background, current role
2. **Key Topics** - 3-5 topics to explore
3. **Conversation Starters** - Engaging opening questions
4. **Deep Dive Questions** - Thoughtful questions for meaty discussion
5. **Avoid** - Topics or approaches to steer clear of
6. **Logistics** - Recording details, time, tech requirements`,
      prompt: `Create a briefing for:

Guest: ${briefingData.guestName}
Episode: ${briefingData.episodeTitle}
Recording Date: ${briefingData.recordingDate}

Research Data:
${JSON.stringify(briefingData.researchData, null, 2)}`
    })
  });

  const data = await response.json();
  return data.text;
};

// Step 4: Send confirmation email
const sendConfirmationEmail = async (briefing: Briefing) => {
  const emailHtml = `
    <div style="font-family: sans-serif; max-width: 600px;">
      <h1>Hey ${briefing.guestName.split(' ')[0]}! 👋 </h1>
      
      <p>Stella and I are stoked to have you on <strong>So Good to Grow Good</strong>.</p>
      
      <h2>📅 Recording Details</h2>
      <ul>
        <li><strong>Date:</strong> ${new Date(briefing.recordingDate).toLocaleDateString()}</li>
        <li><strong>Time:</strong> ${new Date(briefing.recordingDate).toLocaleTimeString()}</li>
        <li><strong>Platform:</strong> Riverside.fm (link sent 24 hours before)</li>
      </ul>
      
      <h2>💡 What We'll Cover</h2>
      <ul>
        ${briefing.prepQuestions.map(q => `<li>${q}</li>`).join('\n')}
      </ul>
      
      <p>Just be yourself and bring that energy. We handle the rest. 🚌</p>
      
      <p>— Kane & Stella</p>
    </div>
  `;

  await fetch(`${API_BASE}/email-api`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      action: 'send',
      to: briefing.guestEmail,
      subject: `🎙 You're on So Good to Grow Good! (Recording ${new Date(briefing.recordingDate).toLocaleDateString()})`,
      html: emailHtml,
      text: `Guest confirmation for ${briefing.guestName}`,
      replyTo: 'kane@sg2gg.com'
    })
  });
};
```

---

## Feature 3: Voice Fingerprint (Signature App)

Upload transcripts/captions, train a voice model, refine via corrections.

### Voice Training Data Structure

```typescript
interface VoiceTrainingData {
  // Raw training inputs
  transcripts: string[];          // Full episode transcripts
  approved_captions: string[];    // Captions marked as "good"
  correction_notes: string[];     // "More casual", "Too formal", etc.
  
  // Generated profile
  description: string;            // AI-generated voice description
  voice_preview: string;          // Sample output in this voice
}
```

### File Upload Implementation

```typescript
// Signature.tsx - Voice Fingerprint Training

// File upload component handler
const handleFileUpload = async (file: File, profileId: number) => {
  // 1. Convert file to base64
  const base64 = await new Promise<string>((resolve) => {
    const reader = new FileReader();
    reader.onload = () => {
      const result = reader.result as string;
      resolve(result.split(',')[1]); // Remove data:url prefix
    };
    reader.readAsDataURL(file);
  });

  // 2. Upload to storage
  const uploadResponse = await fetch(`${API_BASE}/storage-api`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      action: 'upload',
      filename: `${profileId}-${Date.now()}-${file.name}`,
      contentType: file.type,
      base64
    })
  });

  const { url } = await uploadResponse.json();

  // 3. Read file contents and save to database
  const textContent = await file.text();
  
  await fetch(`${API_BASE}/db-api`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      action: 'insert',
      table: 'transcripts',
      data: {
        voice_profile_id: profileId,
        filename: file.name,
        file_url: url,
        content: textContent,
        word_count: textContent.split(/\s+/).length
      }
    })
  });

  return url;
};

// Retrain voice profile with all training data
const retrainVoice = async (profileId: number) => {
  // 1. Fetch all training data
  const [transcripts, captions, corrections] = await Promise.all([
    fetch(`${API_BASE}/db-api`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        action: 'query',
        table: 'transcripts',
        filters: [{ column: 'voice_profile_id', op: 'eq', value: profileId }]
      })
    }).then(r => r.json()),
    
    fetch(`${API_BASE}/db-api`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        action: 'query',
        table: 'approved_captions',
        filters: [{ column: 'voice_profile_id', op: 'eq', value: profileId }]
      })
    }).then(r => r.json()),
    
    fetch(`${API_BASE}/db-api`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        action: 'query',
        table: 'correction_notes',
        filters: [{ column: 'voice_profile_id', op: 'eq', value: profileId }]
      })
    }).then(r => r.json())
  ]);

  // 2. Generate new voice description
  const analysisResponse = await fetch(`${API_BASE}/ai-api`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      action: 'generate',
      systemPrompt: `You are a voice analyst. Analyze the provided writing samples and create a detailed voice profile.

Your output should include:
1. Tone (professional, casual, energetic, etc)
2. Sentence structure preferences
3. Common phrases or patterns
4. Emoji usage patterns
5. Punctuation style
6. What to avoid`,
      prompt: `Analyze these writing samples and create a voice profile:

TRANSCRIPT EXTRACTS:
${transcripts.rows?.slice(0, 5).map(t => t.content?.slice(0, 1000)).join('\n\n')}

APPROVED CAPTIONS:
${captions.rows?.map(c => c.content).join('\n\n')}

USER CORRECTION FEEDBACK:
${corrections.rows?.map(c => c.note).join('\n')}`
    })
  });

  const voiceDescription = await analysisResponse.json();

  // 3. Generate a sample output in this voice
  const sampleResponse = await fetch(`${API_BASE}/ai-api`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      action: 'generate',
      systemPrompt: voiceDescription.text,
      prompt: 'Write a short Instagram caption about the importance of showing up authentically.'
    })
  });

  const sampleOutput = await sampleResponse.json();

  // 4. Update voice profile
  await fetch(`${API_BASE}/db-api`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      action: 'update',
      table: 'voice_profiles',
      filters: [{ column: 'id', op: 'eq', value: profileId }],
      data: {
        description: voiceDescription.text,
        voice_preview: sampleOutput.text,
        is_trained: true,
        sample_count: transcripts.rows?.length + captions.rows?.length
      }
    })
  });

  return {
    description: voiceDescription.text,
    preview: sampleOutput.text
  };
};
```

---

## UI Component Patterns

### Document Display Component

```typescript
// SectionedDocument.tsx - Reusable document display

interface DocumentSection {
  id: string;
  title: string;
  content: string;
  editable?: boolean;
  regeneratable?: boolean;
}

interface SectionedDocumentProps {
  sections: DocumentSection[];
  onEdit?: (id: string, content: string) => void;
  onRegenerate?: (id: string) => void;
  onCopy?: (content: string) => void;
}

const SectionedDocument: React.FC<SectionedDocumentProps> = ({
  sections,
  onEdit,
  onRegenerate,
  onCopy
}) => {
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editContent, setEditContent] = useState('');

  return (
    <div className="space-y-6">
      {sections.map((section) => (
        <div key={section.id} className="border rounded-lg p-4">
          <div className="flex justify-between items-center mb-2">
            <h2 className="text-lg font-semibold">{section.title}</h2>
            <div className="flex gap-2">
              <button
                onClick={() => {
                  navigator.clipboard.writeText(section.content);
                  onCopy?.(section.content);
                }}
                className="px-3 py-1 text-sm bg-gray-100 hover:bg-gray-200 rounded"
              >
                Copy
              </button>
              {section.editable && (
                <button
                  onClick={() => {
                    setEditingId(section.id);
                    setEditContent(section.content);
                  }}
                  className="px-3 py-1 text-sm bg-blue-100 hover:bg-blue-200 rounded"
                >
                  Edit
                </button>
              )}
              {section.regeneratable && (
                <button
                  onClick={() => onRegenerate?.(section.id)}
                  className="px-3 py-1 text-sm bg-purple-100 hover:bg-purple-200 rounded"
                >
                  🔄 Regenerate
                </button>
              )}
            </div>
          </div>
          
          {editingId === section.id ? (
            <div>
              <textarea
                value={editContent}
                onChange={(e) => setEditContent(e.target.value)}
                className="w-full h-32 p-2 border rounded"
              />
              <div className="flex gap-2 mt-2">
                <button
                  onClick={() => {
                    onEdit?.(section.id, editContent);
                    setEditingId(null);
                  }}
                  className="px-4 py-2 bg-green-500 text-white rounded"
                >
                  Save
                </button>
                <button
                  onClick={() => setEditingId(null)}
                  className="px-4 py-2 bg-gray-300 rounded"
                >
                  Cancel
                </button>
              </div>
            </div>
          ) : (
            <div className="prose prose-sm max-w-none">
              <ReactMarkdown>{section.content}</ReactMarkdown>
            </div>
          )}
        </div>
      ))}
    </div>
  );
};
```

### Multi-Step Workflow Component

```typescript
// WorkflowSteps.tsx - Reusable step indicator

interface WorkflowStep {
  id: string;
  label: string;
  status: 'pending' | 'active' | 'complete' | 'error';
}

const WorkflowSteps: React.FC<{ steps: WorkflowStep[] }> = ({ steps }) => {
  return (
    <div className="flex items-center gap-2">
      {steps.map((step, index) => (
        <React.Fragment key={step.id}>
          <div className={`
            flex items-center gap-2 px-3 py-2 rounded-full
            ${step.status === 'complete' ? 'bg-green-100 text-green-700' : ''}
            ${step.status === 'active' ? 'bg-blue-100 text-blue-700' : ''}
            ${step.status === 'pending' ? 'bg-gray-100 text-gray-500' : ''}
            ${step.status === 'error' ? 'bg-red-100 text-red-700' : ''}
          `}>
            <span className="font-medium">{index + 1}. {step.label}</span>
            {step.status === 'complete' && <span>✓</span>}
            {step.status === 'active' && <span className="animate-spin">※</span>}
          </div>
          {index < steps.length - 1 && (
            <div className="w-8 h-0.5 bg-gray-200" />
          )}
        </React.Fragment>
      ))}
    </div>
  );
};
```

---

## API Constants

```typescript
// constants.ts

export const WORKSPACE_ID = '8f1ad824-832f-4af8-b77e-ab931a250625';

export const API_BASE = `https://platform.audos.com/api/hooks/execute/workspace-${WORKSPACE_ID}`;

export const API_ENDPOINTS = {
  db: `${API_BASE}/db-api`,
  ai: `${API_BASE}/ai-api`,
  email: `${API_BASE}/email-api`,
  storage: `${API_BASE}/storage-api`,
  web: `${API_BASE}/web-api`,
  scheduler: `${API_BASE}/scheduler-api`,
  analytics: `${API_BASE}/analytics-api`,
  crm: `${API_BASE}/crm-api`
};

export const VOICE_TYPES = {
  BRAND: 'brand',      // SG2GG podcast brand voice
  PERSONAL: 'personal' // Kane's personal voice
} as const;

export const PLATFORMS = {
  INSTAGRAM: 'instagram',
  LINKEDIN: 'linkedin',
  TWITTER: 'twitter'
} as const;
```

---

## Critical Bugs: Studio & Briefing Apps

Both apps currently render as blank white screens. This needs to be fixed before implementing new features.

### Debugging Steps

1. Check browser console for JavaScript errors
2. Verify component exports are correct in config.json
3. Ensure no runtime errors in component rendering
4. Test that database hooks aren't throwing on mount

---

## Next Steps for Implementation

1. ❌ Fix Studio and Briefing app blank screen bugs
2. ❌ Create `guest_briefings` table for Briefing app workflow
3. ❌ Implement caption generation UI in Studio
4. ❌ Build multi-step workflow for Briefing app
5. ❌ Add file upload UI to Signature app
6. ❌ Implement voice retraining function