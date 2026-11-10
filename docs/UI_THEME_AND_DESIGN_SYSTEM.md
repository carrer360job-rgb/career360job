# Career360 — UI Theme & Brand System

> **Platform Brand:** **Career360**  
> **Brand Tagline:** *Job Portal — Find Your Next Career Move*  
> **Target Platform:** Universal Flutter (Android Mobile App + Responsive Web Dashboard)  
> **Language:** Full English  
> **Design Style:** Corporate Blue — Modern, Clean, Enterprise Grade  
> **Design Philosophy:** Trust, High Contrast, Speed, and Seamless Professional UX.

---

## 1. Brand Identity & Name

* **Official Brand Name:** **Career360**
* **Sub-branding:** **JOB PORTAL**
* **Primary Slogan:** *Find Your Next Career Move*
* **Secondary Slogan:** *Better Career, Brighter Future*
* **App Icon:** Stylized vibrant corporate blue **"C"** with orbital motion arrow, briefcase center mark, and degree accent on a pure white canvas.

---

## 2. Color Palette: "Corporate Blue — Job Portal"

| Role | Color Name | Hex Code | Flutter `Color(0xFF...)` | Usage |
| :--- | :--- | :--- | :--- | :--- |
| **Primary** | Corporate Blue | `#155EEF` | `Color(0xFF155EEF)` | Primary buttons, active states, brand titles, key links |
| **Dark** | Midnight Navy | `#0B1F3A` | `Color(0xFF0B1F3A)` | Desktop sidebar, employer buttons, dark headers |
| **Accent** | Sky Blue / Cyan | `#38BDF8` | `Color(0xFF38BDF8)` | Highlights, badges, promotional banners |
| **Background** | Slate Light | `#F8FAFC` | `Color(0xFFF8FAFC)` | Canvas background |
| **Cards & Text**| Pure White | `#FFFFFF` | `Color(0xFFFFFFFF)` | Job listing cards, modal dialogs, button text |
| **Text Primary**| Deep Slate | `#172B4D` | `Color(0xFF172B4D)` | Main headings, job titles, primary content |
| **Text Muted** | Slate Gray | `#64748B` | `Color(0xFF64748B)` | Subtitles, location tags, date stamps |
| **Border** | Slate Light | `#E2E8F0` | `Color(0xFFE2E8F0)` | Card outlines, dividers |
| **Light Tint** | Soft Blue | `#EFF8FF` | `Color(0xFFEFF8FF)` | Icon containers, category chip backgrounds |
| **Success** | Emerald | `#16A34A` | `Color(0xFF16A34A)` | Verified badge, hired state |

---

## 3. Typography: Inter (Modern • Clean • Readable)

* **Display / Hero:** 28–32sp Bold (`#172B4D`)
* **Section Titles:** 20–24sp Semibold (`#172B4D`)
* **Job Titles:** 16–18sp Bold (`#172B4D`)
* **Body Text:** 14–16sp Regular (`#64748B`)
* **Button Labels:** 14–16sp Semibold (`#FFFFFF`)
* **Captions / Badges:** 12–13sp Regular / Semibold
| **Button Text** | 15sp | 1.2x | SemiBold (600) | விண்ணப்பிக்க (Apply Now) |

> [!TIP]
> **Line Height Rule:** Always set `height: 1.4` to `1.5` for Tamil text in Flutter `TextStyle` to prevent clipped ascenders or descenders on budget smartphone displays.

---

## 3. Component Design System

### A. Job Listing Card
* **Background:** `#FFFFFF`
* **Border:** 1px solid `#E2E8F0` (with 8px corner radius)
* **Shadow:** Soft drop shadow (`color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: Offset(0, 2)`)
* **Badges:**
  * *Verified Badge:* Pill shape with `#DCFCE7` (Light green bg) + `#16A34A` (Text) + Checkmark icon.
  * *Location Badge:* Location pin icon + District name (e.g., `சென்னை / Coimbatore`).
  * *Salary Highlight:* Bold `#0F172A` with rupee symbol (`₹15,000 - ₹25,000 / மாதம்`).

### B. Action Buttons
* **Primary "Apply Now":** Filled background `#F97316` with pure white text and bold typography.
* **Secondary "Save / Share":** Outlined button with `#1A56DB` border and text.

### C. Responsive Desktop vs. Mobile Layouts
* **Mobile (< 768px):** Bottom navigation bar (`[வேலைகள் | விண்ணப்பங்கள் | சுயவிவரம்]`), vertical card stack.
* **Desktop / Web (> 768px):** Left sidebar with deep navy background (`#0F3D99`), dual-column view (job list on left, full job detail preview on right).

---

---

## 5. Welcome & Role Selection UX Specification

When users open VetriJobs for the first time, they are welcomed by a clean, visual role-selection screen:

### A. Role Selection Cards
1. **Candidate Card (வேலை தேடுபவர்):**
   * **Title:** நான் வேலை தேடுகிறேன் (I want a Job)
   * **Subtitle:** ஆயிரக்கணக்கான வேலை வாய்ப்புகளை தேடி விண்ணப்பியுங்கள்.
   * **Icon:** `Icons.work_rounded` inside a circular Royal Blue (`#1A56DB`) container.
   * **Action:** Directs user to the Candidate Job Discovery Feed.

2. **Employer Card (வேலை வழங்குபவர்):**
   * **Title:** நான் ஆட்களை தேர்வு செய்கிறேன் (I want to Hire)
   * **Subtitle:** உங்கள் நிறுவனத்திற்கான சிறந்த பணியாளர்களை உடனே கண்டறியுங்கள்.
   * **Icon:** `Icons.business_center_rounded` inside a circular Warm Orange (`#F97316`) container.
   * **Action:** Directs user to the Employer ATS & Post Job Dashboard.

### B. Persistent Preference & Role Switching
* **Local Storage:** The selected role is saved locally (via `SharedPreferences` / local storage). Subsequent app launches bypass the welcome screen and open directly into the chosen workspace.
* **Role Switcher in Profile:** Users can toggle roles anytime under `Profile -> அமைப்புகள் (Settings) -> வேலை வழங்குபவராக மாற (Switch Mode)`.
* **Admin Access:** Hidden from the public welcome screen; accessed via a protected login route (`/admin`).


Copy this configuration directly into your Flutter project (`lib/core/theme.dart`):

```dart
import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors
  static const Color primary = Color(0xFF1A56DB);
  static const Color primaryDark = Color(0xFF0F3D99);
  static const Color accent = Color(0xFFF97316);
  static const Color success = Color(0xFF16A34A);
  static const Color background = Color(0xFFF8FAFC);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.light(
      primary: primary,
      secondary: accent,
      surface: cardSurface,
      error: const Color(0xFFDC2626),
    ),
    fontFamily: 'NotoSansTamil',
    cardTheme: CardTheme(
      color: cardSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: border, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      ),
    ),
  );
}
```
