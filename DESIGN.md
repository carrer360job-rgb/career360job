---
name: "Career360 Design System"
description: "Design specification and anti-vibe-coded UI tokens for Career360 Job Portal."
colors:
  canvas: "#F8FAFC"
  surface: "#FFFFFF"
  text: "#172B4D"
  mutedText: "#64748B"
  border: "#E2E8F0"
  primary: "#155EEF"
  onPrimary: "#FFFFFF"
  primaryDark: "#0B1F3A"
  accent: "#38BDF8"
  primaryLight: "#EFF8FF"
  focus: "#155EEF"
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

- **Visual thesis:** Clean, corporate Indian employment platform delivering credible job discoveries with zero clutter, authentic employer verification, and instant 1-tap mobile apply workflows.
- **Surface mode:** OPERATE (Job seekers quickly searching, filtering, and applying to verified roles; recruiters screening applicants) with selective PERSUADE on onboarding/splash.
- **Design priorities:** 
  1. Job title, salary clarity (e.g. ₹8 - 12 LPA), verified company badge, and location.
  2. High-contrast, 44px+ touch targets for effortless thumb operation on mobile devices.
  3. Responsive adaptability across narrow mobile (360px), tablets (768px), and wide monitors (1440px).
- **Distinctive signature:** Crisp Corporate Blue (`#155EEF`) accents with Midnight Navy (`#0B1F3A`) structure, clean curved category chips, and verified checkmarks providing high trust without generic glowing gradient clichés.

## Colors

- `primary` (`#155EEF`): Main call-to-actions, active navigation states, interactive links, brand accents.
- `primaryDark` (`#0B1F3A`): High-authority headers, desktop sidebar backgrounds, role selection card headers.
- `accent` (`#38BDF8`): Subtle sky-blue highlights, secondary status highlights.
- `background` (`#F8FAFC`): Soothing light grey-blue canvas that prevents eye fatigue.
- `cardSurface` (`#FFFFFF`): Pure white elevated card surfaces for job cards, input bars, bottom sheets.
- `textPrimary` (`#172B4D`): High contrast deep slate navy for headings, job titles, primary text.
- `textSecondary` (`#64748B`): Neutral slate for timestamps, company metadata, locations.
- `border` (`#E2E8F0`): Subtle borders providing clear separation without heavy dropshadows.
- `success` (`#16A34A`): Verified employer badges and application submitted tags.
- `warning` (`#F59E0B`): Cautionary notices, candidate safety alerts, pending review statuses.

## Typography

- Modern sans-serif (Inter / system fallback).
- Header scale: 28px bold for Hero, 20px semibold for Section headings, 16px semibold for Job titles.
- Body scale: 14px regular for descriptions, 12px medium for metadata badges (LPA, WorkMode, Posted time).
- Contrast ratio strictly meets WCAG 2.2 AA (>= 4.5:1 for body, >= 3.0:1 for large text).

## Layout & Responsive Invariants

- Breakpoints:
  - Narrow mobile: 320px - 480px (Vivo V2437 target, single column, safe bottom navigation).
  - Tablet: 600px - 1024px (dual column feed, expanded filter drawer).
  - Desktop: 1024px+ (collapsible left navigation sidebar, max centered content 1200px).
- Zero horizontal overflow (`overflow-x: hidden` forbidden as a crutch; content wraps or scrolls gracefully).

## Components & Touch Targets

- All buttons, chips, and tap targets maintain minimum 44 × 44 pt hit areas.
- Inputs provide clear placeholder text, search prefix icons, and instant clear/filter buttons.
- Bottom actions provide full device `SafeArea` support avoiding Android 3-button and gesture bar collisions.
