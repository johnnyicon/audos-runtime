# Audos Platform — Pre-Build Questions for Throughline

Questions to ask Audos / Otto before implementing the next set of Throughline features.
Answers should be captured back into this file for reference.

---

## Context

We're building three active feature areas in Throughline:

1. **Caption generation** (Studio app) — generate platform-specific social captions from a reel/clip, in two distinct voices (SG2GG brand voice + Kane personal voice)
2. **Guest research and briefing** (Briefing app) — research a guest, generate a briefing document, send a follow-up/confirmation email
3. **Voice fingerprint** (Signature app) — upload transcripts/captions, train a voice model, refine via corrections

---

## Question 1 — The "Doc" Primitive

We've heard there's a "doc" component or primitive in the platform. What is it exactly?

- Is it a built-in content type, a view type, or a UI component?
- When should we use it vs. building a custom component?
- Can it render structured content (sections, lists, metadata)?
- Is it editable by the user at runtime?
- Where in the Audos workspace does it live — inside an app, as a separate page type?

---

## Question 2 — Long-Form Generated Content Display

For caption generation and briefing documents, we need to display multi-section AI-generated content that the user can:
- Read and review
- Edit inline or in sections
- Copy to clipboard per section or in full
- Potentially regenerate a specific section

What's the recommended pattern for this in Audos?
- Is there a component pattern for "AI-generated content with edit/copy actions"?
- Should this live in `useSpaceFiles()` (transient) or `useWorkspaceDB()` (persistent)?
- Any platform-level support for streaming text generation (so the user sees the output building)?

---

## Question 3 — Multi-Voice / Persona Support

We need to generate content in two distinct voices from the same source material:
- Voice A: SG2GG brand voice (for branded social accounts)
- Voice B: Kane personal voice (for personal reposts)

Both voices are defined by training data (transcripts, approved captions, correction notes).

- What's the best way to store and pass a voice profile to `platform.generateText()`?
- Is there a way to attach a system prompt or persona to the AI generation call?
- Can we store multiple named voice profiles per workspace?
- Does `platform.generateText()` support system prompt + user prompt separation, or just a single prompt string?

---

## Question 4 — File Upload for Training Data

The Signature app needs to accept uploaded transcripts and caption files as training data for the voice fingerprint.

- What's the recommended file upload pattern in Audos apps?
- Is Google Cloud Storage the right target for uploaded files?
- Can we reference uploaded file content in a server function (to read the text and process it)?
- What file types and sizes are supported?
- Is there a platform-level file picker component, or do we build our own?

---

## Question 5 — Sending Emails with Dynamic Content

For guest follow-up and confirmation emails, we need to send structured emails that include:
- Guest name and episode details
- Recording time/logistics
- Prep questions and briefing link

- What does `platform.sendEmail()` support? (HTML vs plain text, templates, dynamic fields)
- Can we define reusable email templates, or is each call fully custom?
- Is there a "from" address we control, or does it send from an Audos address?
- Can we CC or BCC?
- Is there a send log we can query?

---

## Question 6 — Multi-Step Workflow UX

Several Throughline features are multi-step processes (e.g. guest briefing: search → research → generate brief → send email). 

- Is there a platform pattern for multi-step workflows or wizard-style UX?
- Should each step be a separate app, or handled within one app with state management?
- Any guidance on managing in-progress state across steps (user closes app and returns)?

---

## Question 7 — Platform AI Model

We're using `platform.generateText()` for AI generation.

- What model is this calling? (GPT-4o-mini was mentioned in docs — is this current?)
- Is there a way to call a more capable model for complex generation tasks?
- Are there rate limits or cost implications per call we should know about?
- Can we pass large context (e.g. a full transcript as part of the prompt)?
