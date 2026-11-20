---
name: "Career360 Design System"
description: "Design specification and anti-vibe-coded UI tokens for Career360 Job Portal, featuring the distinctive Emerald Growth & Pine Green palette."
colors:
  canvas: "#F8FAFC"
  surface: "#FFFFFF"
  surfaceTint: "#F0FDF4"
  text: "#172B40"
  mutedText: "#64748B"
  border: "#E2E8F0"
  primary: "#16A34A"
  onPrimary: "#FFFFFF"
  primaryDark: "#065F46"
  accent: "#22C55E"
  primaryLight: "#F0FDF4"
  primaryLightBorder: "#DCFCE7"
  focus: "#16A34A"
  success: "#16A34A"
  warning: "#F59E0B"
  danger: "#DC2626"
typography:
  display:
    fontFamily: "Inter, Roboto, sans-serif"
    fontSize: "24px - 32px"
    fontWeight: "700"
    lineHeight: "1.25"
  body:
    fontFamily: "Inter, Roboto, sans-serif"
    fontSize: "14px - 16px"
    fontWeight: "400"
    lineHeight: "1.5"
rounded:
  sm: "8px"
  md: "12px"
  lg: "16px"
  pill: "9999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "16px"
  lg: "24px"
  xl: "32px"
---

## Overview

- **Visual thesis:** Distinctive Indian employment platform delivering credible job discoveries with zero clutter, authentic employer verification, and instant 1-tap mobile apply workflows. Replaces ubiquitous corporate blue with an energetic, growth-oriented Emerald & Pine Green brand language.
- **Surface mode:** OPERATE (Job seekers searching, filtering, and applying to verified roles; recruiters screening applicants) with selective PERSUADE on onboarding/splash.
- **Design priorities:** 
  1. Job title, salary clarity (e.g. ₹8 - 12 LPA), verified company badge, and location.
  2. High-contrast, 44px+ touch targets for effortless thumb operation on mobile devices.
  3. Responsive adaptability across narrow mobile (360px), tablets (768px), and wide monitors (1440px).
- **Distinctive signature:** Vibrant **Emerald Green (`#16A34A`)** primary actions paired with authoritative **Deep Pine (`#065F46`)** headers and soft **Mint (`#F0FDF4`)** surfaces. Symbolizes career growth, promotion, and financial prosperity while standing apart from generic blue job portals (LinkedIn, Indeed, Naukri).

## Colors

- `primary` (`#16A34A`): Main call-to-actions (`Apply Now`, `Update & Publish Price`, `Get Started`), active navigation highlights, interactive links.
- `primaryDark` (`#065F46`): Deep Pine Green for authoritative page titles, active sidebar selection backgrounds, and primary branding icons.
- `accent` (`#22C55E`): Vibrant leaf green for badges, verified checkmark accents, and high-energy highlights.
- `primaryLight` / `surfaceTint` (`#F0FDF4`): Fresh mint off-white for soft pill chips, summary breakdown boxes, and subtle card hover backgrounds.
- `primaryLightBorder` (`#DCFCE7`): Soft green border for active pills and verified badges.
- `canvas` / `background` (`#F8FAFC`): Soothing light neutral canvas that prevents eye fatigue.
- `cardSurface` (`#FFFFFF`): Pure white elevated card surfaces for job cards, input fields, and bottom sheets.
- `textPrimary` (`#172B40`): High-contrast slate navy-charcoal for headings, job titles, and primary text (WCAG AAA compliant on white).
- `textSecondary` (`#64748B`): Neutral slate for timestamps, company metadata, locations, and quota descriptions.
- `border` (`#E2E8F0`): Subtle borders providing clear separation without heavy dropshadows.
- `success` (`#16A34A`): Verified employer badges, checkmark bullets, and application status tags.
- `warning` (`#F59E0B`): Cautionary notices, candidate safety alerts, pending review statuses.
- `danger` (`#DC2626`): Destructive actions (Archive, Delete) and critical errors.

## Typography

- Modern sans-serif (Inter / system fallback).
- Header scale: 28px–32px bold for Hero / Page titles, 20px–24px semibold for Section headings, 16px semibold for Job titles.
- Body scale: 14px–16px regular for descriptions, 12px–13px medium for metadata badges (LPA, WorkMode, Posted time, Quotas).
- Contrast ratio strictly meets WCAG 2.2 AA (>= 4.5:1 for body, >= 3.0:1 for large text).

## Layout & Responsive Invariants

- Breakpoints:
  - Narrow mobile: 320px - 480px (Vivo V2437 target, single column, safe bottom navigation).
  - Tablet: 600px - 1024px (dual column feed, expanded filter drawer).
  - Desktop: 1024px+ (collapsible left navigation sidebar, max centered content 1200px).
- Zero horizontal overflow (`overflow-x: hidden` forbidden as a crutch; content wraps or scrolls gracefully).

## Components & Touch Targets

- All buttons, chips, and tap targets maintain minimum 44 × 44 pt hit areas.
- Primary buttons use solid Emerald Green (`#16A34A`) with white text and 6px–8px radius.
- Inputs provide clear placeholder text, search prefix icons, and instant clear/filter buttons.
- Bottom actions provide full device `SafeArea` support avoiding Android 3-button and gesture bar collisions.
