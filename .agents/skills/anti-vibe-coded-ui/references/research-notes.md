# Research notes and source basis

This skill consolidates the supplied text about “vibecoded” interfaces with current public guidance and examples. It is a practical synthesis, not a claim that one visual style is objectively correct.

## Source-derived principles retained

- Distinctive, brief-specific visual direction is more useful than generic instructions such as “make it modern.”
- Keep durable product requirements separate from surface-level visual choices to avoid accidental product behavior changes during styling.
- Treat common AI-generated clichés (generic gradients, identical card grids, nested cards, badges everywhere, arbitrary gradient words, and a single default font for every typographic role) as review signals, not universal prohibitions.
- Use explicit design tokens and document design rationale so styling stays consistent across screens and iterations.
- Verify actual rendered output, responsive behavior, interaction states, accessibility, and visual changes. Code-only self-review is insufficient when browser testing is available.

## Important refinements

- Design.md is an evolving open format; existing design tokens or a project's own conventions should not be replaced solely to adopt a new schema.
- Motion recommendations are context-dependent. No easing curve, duration, radius formula, or shadow recipe is universally correct for every product.
- WCAG 2.2 SC 2.5.8 has a general minimum target-size criterion of 24 × 24 CSS pixels with exceptions. A 44 × 44 CSS pixel target is a useful mobile usability goal, not the AA minimum itself.
- Automated accessibility tests detect only some issues and should be combined with manual checks; they cannot certify total accessibility.
- Visual screenshot comparisons can vary with browser, OS, and rendering environment. Review intended differences in a consistent environment.

## Public references

1. Anthropic, `frontend-design` skill — guidance for distinctive, intentional UI design: https://github.com/anthropics/skills/tree/main/skills/frontend-design
2. Paul Bakaus, Impeccable — AI design guidance, product context, design direction, and deterministic detectors: https://github.com/pbakaus/impeccable
3. Google, Stitch DESIGN.md open-source announcement (April 21, 2026): https://blog.google/innovation-and-ai/models-and-research/google-labs/stitch-design-md/
4. Google Stitch DESIGN.md format specification mirror (draft format; check the official project for current status): https://github.com/webplete/google-stitch-design.md/blob/main/docs/spec.md
5. Playwright, Accessibility testing: https://playwright.dev/docs/accessibility-testing
6. Playwright, Visual comparisons: https://playwright.dev/docs/test-snapshots
7. W3C WAI, Understanding WCAG 2.2 Target Size (Minimum), SC 2.5.8: https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum
8. Cursor, Project rules: https://docs.cursor.com/context/rules-for-ai
9. GitHub, Adding agent skills: https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/add-skills
10. OpenAI, Agent Skills: https://developers.openai.com/api/docs/guides/tools-skills
