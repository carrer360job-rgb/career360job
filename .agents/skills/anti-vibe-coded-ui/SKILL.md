---
name: anti-vibe-coded-ui
description: This skill should be used when a user asks to build, design, redesign, polish, critique, or audit a website, web app, dashboard, landing page, product UI, component, or native app screen and wants distinctive, production-ready work rather than generic AI-generated templates. It guides product-context discovery, art direction, design systems, responsive implementation, interaction states, accessibility, and real-browser verification.
version: 1.0.0
---

# Anti-Vibe-Coded UI Craft

## Mission

Create interfaces that feel deliberately designed for this specific product, audience, and task—not like a template assembled from fashionable effects. Visual quality must be supported by real interaction, resilient layout, accessible behavior, and maintainable code.

Treat “anti-vibe-coded” as a quality goal, not a fixed visual style. Do not replace one formula with another. A gradient, glass effect, card, animation, dark theme, or popular font is acceptable when it has a clear purpose and fits the brief. Reject unexamined defaults, not entire design techniques.

## 1. Inspect before changing anything

For an existing project:

1. Inspect the repository instructions, framework, routes, current page, package scripts, design tokens, component library, assets, and relevant business logic before editing.
2. Identify what is already working. Preserve established brand language, useful interaction patterns, API contracts, forms, route behavior, and accessibility semantics unless the task explicitly calls for changing them.
3. Reuse existing dependencies and components when they fit. Do not migrate frameworks, introduce a new design system, or install packages just to make the interface look more impressive.
4. Separate product behavior from visual presentation. A styling task must not silently change validation, copy with legal/business meaning, data shape, authentication, payment flow, or API payloads.

For a new project, establish the product context before writing components. If crucial context is missing, ask only the smallest question that materially changes the result. Otherwise, state a reasonable assumption briefly and proceed.

Capture the following in working notes; for a substantial project, create or update `PRODUCT.md`:

- **Audience and situation:** who uses it, on what device, and in what environment.
- **Primary job:** what the user must accomplish and the most important action on the screen.
- **Product truth:** essential functionality, content, trust requirements, constraints, and things that must not change.
- **Brand character:** three to five useful adjectives plus what the design should not feel like.
- **Content and data:** likely real labels, names, quantities, lengths, empty states, errors, and edge cases.

Do not confuse missing context with permission to invent business facts, customer testimonials, metrics, logos, or product capabilities.

## 2. Select the interface mode

Choose the dominant mode before choosing visual treatments. A product can mix modes, but each screen needs a clear priority.

- **PERSUADE — marketing, landing, campaign, pricing:** make the offer understandable, distinctive, credible, and easy to act on. Use deliberate storytelling, authentic visuals where helpful, and a clear conversion path.
- **OPERATE — app, dashboard, admin, workflow, editor:** optimize task completion, scanability, information density, predictable controls, keyboard use, and calm feedback. Express brand through precise details rather than distracting decoration.
- **READ — documentation, editorial, guides, help:** optimize comprehension and reading rhythm. Use a clear heading ladder, readable measure (often around 65–75 characters per line for long-form prose), comfortable line height, and restrained motion.
- **EXPERIENCE — portfolio, interactive exhibit, creative tool, immersive demo:** let the main artifact lead. Give immersive media enough room and keep controls clear, accessible, and unobtrusive.

Do not use the same centered hero, feature-card grid, pricing layout, or dashboard arrangement automatically for every project. Choose structure based on the content and user's mental model.

## 3. Establish a clear visual thesis

Before building the full page, make a compact set of explicit design decisions:

1. **One-sentence concept:** describe the visual idea in terms connected to the actual product or audience, not generic words like “modern” or “premium.”
2. **Composition:** choose the content hierarchy, alignment, density, whitespace, grid, and page rhythm. Decide what should dominate the first viewport and what the user should notice next.
3. **Typography:** choose typefaces and roles intentionally. Specify display, body, UI, and data styles where needed; define scale, weights, line heights, and tracking. Use one family if it genuinely suits the product, but do not default to the same ubiquitous font for every role without considering alternatives.
4. **Color:** create a coherent palette with semantic roles such as canvas, surface, text, muted text, border, primary action, focus, success, warning, and error. Validate the colors on the actual surfaces where they appear.
5. **Shape and depth:** define a small radius scale, border strategy, and elevation approach. Use spacing and typography to group information before adding another container. Avoid cards-within-cards unless the information hierarchy genuinely needs separate surfaces.
6. **Signature detail:** choose one or two memorable, brief-specific details—such as a distinctive grid, data visualization, image treatment, diagram, typographic gesture, or interaction—not a collection of unrelated effects.
7. **Assets:** use real project assets or credible, subject-relevant imagery when it helps explain the product. Preserve aspect ratios, provide suitable crops and alt text, and avoid decorative placeholders that look like finished content. Never invent a brand asset and present it as supplied by the user.

For a substantial site or multi-screen app, record durable visual decisions in `DESIGN.md` and reusable product requirements in `PRODUCT.md`. Use tokens as the source of truth; avoid ad hoc values for every component. The exact file format is a project choice, not a reason to force a new tool or schema onto an existing codebase.

## 4. Avoid generic AI design patterns—without banning useful techniques

Before finalizing, check whether any of these patterns appeared without a product-specific reason:

- purple/blue/cyan glow gradients used only because they look “AI”; pure black/dark gray surfaces with no consideration of contrast or tone;
- a centered hero and identical three-card feature grid applied by habit;
- the same font, weight, size, and alignment used for headings, body, data, and labels;
- isolated gradient or italic treatment on one headline word with no typographic rationale;
- numbered eyebrow labels such as `01 / FEATURES` on every section when numbering communicates nothing;
- a pill, badge, icon tile, or border around every small item;
- several nested panels with redundant padding, borders, and shadows;
- large, blurred shadows or glass blur used instead of clear hierarchy;
- stock-looking imagery, random abstract blobs, fake charts, fake testimonials, or placeholder copy left in a production-facing UI;
- repeated section layouts, overly uniform spacing, or animation added only to make the page appear expensive.

These are review signals, not automatic violations. Keep a pattern when it serves a clear purpose and improves the design. If multiple clichés appear together, reconsider the underlying composition instead of merely changing their colors.

## 5. Build the real interface, not a screenshot imitation

- Follow the project's framework, architecture, naming, formatting, and existing design conventions.
- Use semantic elements and native browser behavior where appropriate. Use buttons for actions and links for navigation; do not make a `div` interactive unless there is a compelling reason and complete keyboard semantics.
- Implement every visible control's promised behavior. Menus open, links go somewhere meaningful, forms validate and submit to the intended flow, filters alter results, and tabs switch content. Do not leave decorative controls that imply functionality but do nothing.
- Keep data and content believable. Include realistic labels and representative values; make long strings, empty arrays, missing images, large numbers, and error responses safe.
- Build reusable components when they reduce inconsistency, not as an excuse to abstract every element. Keep the component tree and styling understandable.
- Prefer design tokens and named component variants over repeated one-off styles. Use CSS custom properties, theme configuration, or the project's existing equivalent.
- When nesting rounded surfaces, check the relationship among parent radius, padding, and child radius visually. A formula such as `outer radius ≈ inner radius + padding` can be a helpful starting point, not a universal law.
- Avoid `transition: all`; name the properties that should animate. Do not animate layout properties for decorative effect when transforms or opacity can communicate the state without layout shifts.
- Make loading feedback stable: preserve button and container dimensions, prevent duplicate submissions where relevant, and communicate when an action is in progress.

## 6. Design for responsive and imperfect reality

At minimum, consider narrow mobile, standard mobile, tablet, and desktop layouts. Use the project's established breakpoints where available; useful verification widths include 320/375, 768, 1024, and 1440 CSS pixels.

- Reflow the information hierarchy, not only the column count. Navigation, tables, filters, media, and primary actions may require different layouts on small screens.
- Prevent unintended horizontal page overflow. Allow long headings, user names, filenames, URLs, translated strings, and numbers to wrap, truncate, or scroll within an appropriate component.
- Use fluid sizing (for example `clamp()`), responsive images, flexible grids, and container queries when they solve an actual constraint. Do not use these techniques merely for novelty.
- Check content at 200% zoom where practical, and make sure sticky headers, dialogs, dropdowns, and mobile keyboards do not obscure critical controls.
- Include empty, loading, success, validation, and error states for the flows that need them. Do not fill every screen with skeletons or status badges by default.

## 7. Interaction states and motion

For each interactive component, implement the states relevant to its behavior:

- default;
- hover where a hover-capable input is present;
- keyboard focus, clearly visible with `:focus-visible`;
- active/pressed where a press action occurs;
- loading or pending where work takes time;
- disabled where the action truly cannot be used;
- empty, error, success, or selected states when relevant to the component.

Do not force every component to have eight decorative variants. Cover the states the user can actually encounter.

Motion must clarify cause, hierarchy, continuity, or feedback. Keep frequent productivity actions immediate or nearly immediate. Use short, purposeful transitions for lightweight overlays and more considered motion only when the task benefits from it. Easing and duration are design choices; avoid rigid global timing rules. Never use animation as a substitute for clear state changes.

- Prefer transform and opacity for simple transitions; pin popovers to their trigger and preserve spatial context.
- Do not make essential information depend on animation.
- Honor `prefers-reduced-motion`; reduce or remove nonessential movement when requested by the operating system.
- Avoid scaling elements from zero or shifting controls on hover by default. If a physical press effect is used, keep it subtle and test for jitter and layout stability.

## 8. Accessibility and physical usability

Treat accessibility as part of the implementation, not a cleanup pass.

- Use semantic landmarks, correctly nested headings, descriptive link names, explicit form labels, useful validation messages, and accessible announcements for dynamic results where needed.
- Ensure all features work with a keyboard. Keep focus order understandable, use visible focus indicators, and manage focus correctly in dialogs and menus.
- Do not rely on color alone to communicate status. Check text and control contrast against their actual backgrounds. Aim for WCAG 2.2 AA requirements where applicable.
- WCAG 2.2 AA's minimum target-size criterion is generally 24 × 24 CSS pixels, subject to defined exceptions. Prefer approximately 44 × 44 CSS pixels for common touch controls on mobile when space allows; treat 44 px as a usability target, not the WCAG AA minimum.
- Give meaningful images appropriate alternative text and decorative images empty alt text. Label icon-only controls accessibly.
- Respect reduced-motion preferences and browser zoom. Use native input types and autocomplete attributes where they improve form usability.
- Use automated accessibility scans when available (for example, axe with Playwright), then manually test keyboard navigation, focus, names/labels, contrast, reading order, and realistic task flows. Automated scans cannot prove full accessibility.

## 9. Verify in the browser, not only in source code

After implementation, run the checks that the repository and environment support:

1. **Project checks:** inspect package scripts and run relevant lint, typecheck, tests, and production build commands. Fix failures caused by the changes; do not conceal existing failures.
2. **Functional smoke test:** exercise the primary user journey, navigation, forms, menu controls, validation, loading, empty, and error states as applicable.
3. **Rendered review:** use the available browser or Playwright tooling to inspect actual output at a narrow mobile width and a desktop width; add tablet or other widths when the layout demands them. Wait for fonts and images before judging layout.
4. **Responsive invariant:** detect unintended horizontal overflow at target viewports, then inspect and fix its cause rather than hiding it with `overflow-x: hidden` on the page.
5. **Accessibility scan:** run the available automated checker and report remaining findings. Perform manual keyboard checks when the environment permits.
6. **Visual regression:** when the repository has Playwright screenshot baselines or another visual test setup, update them only after inspecting intentional changes. Screenshot diffs can vary across operating systems and browser environments, so compare in a consistent environment.
7. **Bounded polish:** batch visual defects, fix them together, and perform a final confirmation pass. Do not endlessly regenerate or polish after the important issues are resolved.

If browser or test tooling is unavailable, complete the strongest checks possible and explicitly state which checks were not run. Never claim a visual inspection, accessibility pass, test, or build succeeded unless it actually ran.

## 10. Definition of done

Before handing off, confirm or explicitly disclose any gap in each category:

- **Purpose:** the primary user task and call to action are obvious.
- **Distinctiveness:** the direction fits this particular product and avoids unexplained template clichés.
- **Hierarchy:** typography, spacing, alignment, and contrast communicate importance.
- **Content:** realistic data and copy fit without collisions or misleading placeholders.
- **Functionality:** visible controls behave as expected and the primary journey works.
- **Responsiveness:** key layouts work at narrow mobile and desktop sizes with no unintended page overflow.
- **Accessibility:** semantic structure, labels, keyboard operation, visible focus, and relevant contrast checks are addressed.
- **Stability:** project checks pass or failures are recorded honestly; no obvious console errors or broken assets remain.
- **Maintainability:** existing stack and conventions are respected; tokens and components are consistent.

## Delivery note

End with a brief handoff stating what changed, the main design decisions, the validation actually performed, and any known limitation. Do not call the result “production-ready” merely because it renders or looks polished in one screenshot.
