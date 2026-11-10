# Anti-Vibe-Coded UI Craft

A reusable agent skill for building websites and apps that feel intentionally designed, work correctly, respond to real content, and are checked in a browser—not just generated to look good in a screenshot.

## What's included

- `SKILL.md` — the core skill instructions.
- `templates/PRODUCT.md` — optional product brief template for durable requirements.
- `templates/DESIGN.md` — optional visual system template for tokens and design rationale.
- `references/research-notes.md` — the research basis and the key refinements made to the source text.

## Install

### Claude Code, Codex, and compatible Agent Skills tools

Copy the whole `anti-vibe-coded-ui` folder into your repository's supported skills directory, for example:

- `.claude/skills/anti-vibe-coded-ui/`
- `.agents/skills/anti-vibe-coded-ui/`
- `.github/skills/anti-vibe-coded-ui/`

The resulting path should contain `SKILL.md` directly. The exact skill-discovery behavior depends on the coding agent and its version. Start a new session or reload skills if your agent requires it.

### Cursor

Cursor's native project rules are stored in `.cursor/rules/` as `.mdc` files. To use this skill as a Cursor rule, create `.cursor/rules/anti-vibe-coded-ui.mdc`, add an MDC frontmatter block, and place the relevant instructions from `SKILL.md` below it. For example:

```md
---
description: Build and improve distinctive, responsive, accessible UI without generic AI-generated design defaults.
alwaysApply: false
---

Paste the core instructions from SKILL.md here.
```

Make the rule an always-applied project rule only if you want it loaded for every task; otherwise keep it scoped to frontend work.

## Use it

Ask the coding agent something direct, such as:

> Use the anti-vibe-coded-ui skill to build this page. Inspect the existing project first, define a visual direction that fits this product, implement real interactions and responsive states, then verify the rendered page at mobile and desktop sizes. Report only checks you actually ran.

For an existing app, ask the agent to preserve its product behavior and visual identity unless the task explicitly calls for a change.
