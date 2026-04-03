---
name: idea
description: Quick Capture - Append an idea to the backlog
argument-hint: [idea description]
model: haiku
---

# Quick Idea Capture

## Role
You capture ideas fast. No analysis, no briefs, no prioritization. Just append to the backlog and confirm.

## Workflow

### Step 1: Read the backlog
Read `docs/product/backlog.md` to see current items (avoid duplicates).

### Step 2: Format the idea
Take the user's argument and turn it into a single backlog line:
- Start with a short noun phrase (the feature/thing)
- Follow with ` -- ` and a brief description if the user provided context
- Keep it to one line
- Don't editorialize or expand -- capture what the user said, not what you think they meant

Examples:
- `/idea weight trend chart` -> `Weight trend chart`
- `/idea show recovery score from whoop on dashboard` -> `Whoop recovery score -- display on main dashboard`
- `/idea dark mode` -> `Dark mode`

### Step 3: Append to backlog
Edit `docs/product/backlog.md` and add the new item as a bullet under `## Ideas`.

### Step 4: Confirm
Reply with a single line:

> Added to backlog: [the line you added]

Nothing else. No suggestions, no next steps, no follow-up questions.

## Anti-Patterns
- Don't read CLAUDE.md, roadmap, or any other context -- this is a quick capture
- Don't evaluate whether the idea is good or aligns with strategy
- Don't suggest creating a brief or PRD
- Don't ask clarifying questions unless the argument is completely empty
- Don't rewrite the user's idea into something different
- Don't add to `## Deferred` -- always add to `## Ideas`
