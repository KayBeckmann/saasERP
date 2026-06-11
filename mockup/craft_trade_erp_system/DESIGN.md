---
name: Craft-Trade ERP System
colors:
  surface: '#f8fafb'
  surface-dim: '#d8dadb'
  surface-bright: '#f8fafb'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f4f5'
  surface-container: '#eceeef'
  surface-container-high: '#e6e8e9'
  surface-container-highest: '#e1e3e4'
  on-surface: '#191c1d'
  on-surface-variant: '#45474c'
  inverse-surface: '#2e3132'
  inverse-on-surface: '#eff1f2'
  outline: '#75777d'
  outline-variant: '#c5c6cd'
  surface-tint: '#545f74'
  primary: '#000000'
  on-primary: '#ffffff'
  primary-container: '#111c2e'
  on-primary-container: '#7a849b'
  inverse-primary: '#bcc7df'
  secondary: '#4a607e'
  on-secondary: '#ffffff'
  secondary-container: '#c5dcff'
  on-secondary-container: '#4a607f'
  tertiary: '#000000'
  on-tertiary: '#ffffff'
  tertiary-container: '#1e192b'
  on-tertiary-container: '#888098'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d8e2fc'
  primary-fixed-dim: '#bcc7df'
  on-primary-fixed: '#111c2e'
  on-primary-fixed-variant: '#3d475b'
  secondary-fixed: '#d3e4ff'
  secondary-fixed-dim: '#b1c8eb'
  on-secondary-fixed: '#021c37'
  on-secondary-fixed-variant: '#324865'
  tertiary-fixed: '#e8def9'
  tertiary-fixed-dim: '#ccc2dc'
  on-tertiary-fixed: '#1e192b'
  on-tertiary-fixed-variant: '#4a4358'
  background: '#f8fafb'
  on-background: '#191c1d'
  surface-variant: '#e1e3e4'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 57px
    fontWeight: '600'
    lineHeight: 64px
    letterSpacing: -0.25px
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
  headline-sm:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '500'
    lineHeight: 32px
  title-lg:
    fontFamily: Inter
    fontSize: 22px
    fontWeight: '500'
    lineHeight: 28px
  title-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: 0.15px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: 0.5px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0.25px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.1px
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.5px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  base: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  sidebar_width: 280px
  grid_columns: '12'
  gutter: 24px
---

## Brand & Style
The design system is engineered for the German "Mittelstand"—specifically craft and trade businesses (Handwerksbetriebe). The brand personality is rooted in reliability, precision, and "Ordnung." It avoids decorative flourishes in favor of utility and clarity. 

The aesthetic follows a **Corporate / Modern** style, utilizing a refined evolution of Material Design 3. The UI evokes a sense of digital craftsmanship: sturdy, organized, and high-functioning. It prioritizes high legibility and rapid data density management to help users move from the office to the job site efficiently.

**Target Audience:** 
- Business owners (Inhaber)
- Project managers (Projektleiter) 
- Administrative staff (Sachbearbeiter)

## Colors
The palette is anchored by **Deep Navy (#091426)**, representing stability and professional authority. 

- **Primary:** Used for key actions (Primäraktionen), active states, and branding.
- **Secondary (Steel Blue):** Used for less prominent UI elements, supporting icons, and tonal variations in the navigation.
- **Neutral:** A range of cool greys ensures the interface feels "clean" rather than "stark." White surfaces are used for active work areas, while light grey (`#F8F9FA`) defines background containers.
- **Semantic/Status:** High-saturation tokens for *Erfolgreich* (Success), *Fehler/Überfällig* (Error/Overdue), and *Warnung* (Warning) are utilized sparingly to ensure critical information stands out against the navy/slate background.

## Typography
This design system utilizes **Inter** for its exceptional legibility in data-heavy environments. The typeface's tall x-height and clear apertures ensure that complex German compound words (e.g., *Handwerkskammerbeitrag*) remain readable even at smaller sizes.

- **Headlines:** Use Medium or SemiBold weights to create a clear hierarchy.
- **Body:** Standardized at 14px (`body-md`) for data density, scaling to 16px for long-form text.
- **Labels:** Used for table headers, form captions, and small UI meta-data. Always prioritize clarity over stylistic expression.

## Layout & Spacing
The layout follows a **Fixed-Fluid Hybrid** model. 

1. **Sidebar Navigation:** A fixed 280px left sidebar persists across all views, housing the primary navigation (*Dashboard, Aufträge, Kunden, Lager, Buchhaltung*).
2. **Main Content:** A fluid 12-column grid with a 24px margin and gutter. 
3. **Data Grids:** Within content cards, spacing is tightened to a 4px/8px rhythm to allow for high information density without visual clutter.

**Breakpoints:**
- **Desktop (1200px+):** Full 12-column layout.
- **Tablet (768px - 1199px):** Sidebar collapses into an icon-only rail or hamburger menu; margins reduce to 16px.
- **Mobile (<767px):** Single column stack; gutters reduced to 12px.

## Elevation & Depth
This design system employs **Tonal Layers** rather than heavy shadows to signify depth.

- **Level 0 (Background):** Surface Container (`#F8F9FA`).
- **Level 1 (Cards/Tables):** White surfaces (`#FFFFFF`) with a subtle 1px border (`#E0E0E0`). Shadows are avoided here to maintain a flat, professional look.
- **Level 2 (Modals/Dropdowns):** Use a soft ambient shadow (Blur: 8px, Y: 4px, Opacity: 0.08) to distinguish overlaying elements from the primary workspace.
- **Active State:** Elements being dragged or interacted with use a slight tonal shift (tinting with Primary 5%) rather than a shadow "lift."

## Shapes
The shape language is **Soft (0.25rem/4px)**. 

This subtle rounding strikes a balance between the precision of sharp corners and the modern feel of rounded UI. 
- **Buttons & Inputs:** 4px radius.
- **Cards:** 8px (`rounded-lg`) to provide a clear container boundary.
- **Status Chips:** Full radius (Pill) to differentiate them from interactive buttons.

## Components

### Buttons
- **Primary:** Solid Deep Navy with White text.
- **Secondary:** Outlined Steel Blue.
- **Tertiary:** Ghost buttons for "Abbrechen" (Cancel) or minor actions.

### Data Tables (Datentabellen)
- **Header:** Sticky headers with `label-lg` typography, capitalized, using a light grey background.
- **Rows:** Alternating row shading (Zebramuster) using `#F8F9FA`. 
- **Cell Content:** Standardized at `body-md`. Numeric values are tabular-lined for alignment.

### Status Chips (Status-Abzeichen)
Small, pill-shaped containers with low-opacity background tints of the status colors (e.g., Success Green at 10% opacity) and high-contrast text for accessibility. 
- *Bezahlt* (Paid) - Green
- *Offen* (Open) - Amber
- *Überfällig* (Overdue) - Red

### Input Fields
- Underlined or Outlined Material 3 style.
- Active state uses a 2px Deep Navy bottom border.
- Error states clearly display a red helper text (*Pflichtfeld*).

### Navigation Sidebar
- Vertical list of items with icons.
- Active state: Background fill of Steel Blue at 10% opacity and a 4px vertical "indicator bar" on the left edge in Primary Navy.