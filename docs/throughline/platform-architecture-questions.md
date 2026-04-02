# Audos Platform — Architecture Questions (Round 2)

Follow-up questions for Auto, based on active development and codebase review.
The goal: understand what's convention vs. what's constraint, so we can make deliberate architecture decisions before building further.

---

## Context

We've reviewed the SDK docs (SDK-00 through SDK-08) and done a codebase audit of the current Throughline implementation. We found:

1. The workspace currently has 5 separate "apps" (Home, Signature, Studio, Briefing, Setup)
2. There are two separate codebases — `audos-workspace/apps/` (platform) and `src/pages/apps/` (local dev stubs)
3. The two codebases are drifting apart

Before we build further, we want to understand whether the multi-app structure is a requirement or just a scaffold default.

---

## Question 1 — Single App vs. Multi-App

Can we consolidate all of Throughline into a **single Audos app** with internal routing and sub-components, instead of 5 separate apps?

Specifically:
- Is there any platform-level reason to split into multiple apps (permissions, isolation, performance)?
- Or are "apps" just a scaffolding convention — and one app with its own router is equally valid?
- If we build as one app: what does the entry point look like? Does the workspace dock navigation still work, or do we manage our own nav entirely?
- Is there a working example of a single-app workspace in Audos?

**Why this matters:** If apps are just pages, we'd rather have one React module with full internal routing (React Router, hash-based) than 5 separate modules we have to keep in sync. Less maintenance surface, cleaner data flow, standard web app mental model.

---

## Question 2 — Eliminating the Two-Codebase Problem

The current repo has two implementations: `audos-workspace/apps/` for the platform and `src/pages/apps/` for local dev. These are drifting apart.

SDK-03 (Local Mock Layer) documents a mock approach, but the current repo isn't using it correctly.

- What is the **intended** relationship between the `audos-workspace/` code and local dev?
- Is `src/` meant to be a local dev environment that mirrors `audos-workspace/`, or is `audos-workspace/` the only source of truth?
- What's the correct way to develop locally so that one codebase works both locally and on the platform?
- Does the mock layer in SDK-03 fully cover `useWorkspaceDB`, `useBranding`, `useSession`, and the REST APIs — so local dev and platform behavior are identical except for the data source?

**What we want:** One codebase. Local dev uses mocks/stubs for platform services. The platform uses real implementations. No separate stub components to maintain.

---

## Question 3 — Using Platform Capabilities Without Platform UI Conventions

We want to use the platform's capabilities (database, AI generation, email, file storage, auth) but build the UI entirely our way — our own component library, our own layout, our own routing.

- Can we build a React app that uses the platform hooks (`useWorkspaceDB`, `useBranding`, `useSession`, REST APIs) but has **no dependency on Audos UI components or conventions**?
- Is there a minimal "shell" requirement — things the app must include to work on the platform (e.g., a specific root component, a required config, a workspace context provider)?
- Can we bring in ShadCN components (copy-pasted) and use them freely alongside platform hooks? Any conflicts to be aware of?
- Can we use any React routing library (React Router, TanStack Router) inside a single Audos app? Or are we constrained to hash-based routing?

**What we want:** Use Audos as the backend runtime (DB, AI, storage, email, auth). Build the frontend as a standard React + TypeScript + Tailwind + ShadCN application with no Audos-specific UI constraints.

---

## Question 4 — Auth and Branding Hooks

We want to understand what `useSession` and `useBranding` actually expose so we can use them intentionally.

- `useSession`: What user/auth data is available? Is there a user ID, email, workspace role? Can we store user-specific preferences or settings keyed off the session?
- `useBranding`: What does this expose — colors, logo URL, workspace name? Can we override it per-app or per-component? Or does it only read platform-defined branding?
- Is there a way to define a custom theme (colors, fonts, spacing) that overrides the platform's branding defaults — so our app looks like Throughline, not like a generic Audos workspace?

---

## Question 5 — The "Doc" Primitive (Revisited)

SDK-05 confirmed there's no built-in doc primitive. But there's a follow-up:

- In the current `audos-workspace/` folder, there are references to what appear to be "doc" type apps or components. Is there a `doc` app type in the Audos workspace config that we should know about?
- If not, and we're building custom document views (briefing docs, show notes, etc.) — is `useWorkspaceDB` the right persistence layer, or should we use `useSpaceFiles` for transient document drafts?

---

## What We're Trying to Decide

Based on your answers, we want to make one architectural decision:

> **Build Throughline as a single Audos app with our own internal routing and component library, using platform hooks only for backend services (DB, AI, storage, email).**

Tell us if this is viable, what the constraints are, and what the minimal setup looks like to make it work.
