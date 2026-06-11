---
name: Warm Enterprise Portal
colors:
  surface: '#f8f9ff'
  surface-dim: '#cbdbf5'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e5eeff'
  surface-container-high: '#dce9ff'
  surface-container-highest: '#d3e4fe'
  on-surface: '#0b1c30'
  on-surface-variant: '#3d4947'
  inverse-surface: '#213145'
  inverse-on-surface: '#eaf1ff'
  outline: '#6d7a77'
  outline-variant: '#bcc9c6'
  surface-tint: '#006a61'
  primary: '#00685f'
  on-primary: '#ffffff'
  primary-container: '#008378'
  on-primary-container: '#f4fffc'
  inverse-primary: '#6bd8cb'
  secondary: '#565e74'
  on-secondary: '#ffffff'
  secondary-container: '#dae2fd'
  on-secondary-container: '#5c647a'
  tertiary: '#825100'
  on-tertiary: '#ffffff'
  tertiary-container: '#a36700'
  on-tertiary-container: '#fffbff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#89f5e7'
  primary-fixed-dim: '#6bd8cb'
  on-primary-fixed: '#00201d'
  on-primary-fixed-variant: '#005049'
  secondary-fixed: '#dae2fd'
  secondary-fixed-dim: '#bec6e0'
  on-secondary-fixed: '#131b2e'
  on-secondary-fixed-variant: '#3f465c'
  tertiary-fixed: '#ffddb8'
  tertiary-fixed-dim: '#ffb95f'
  on-tertiary-fixed: '#2a1700'
  on-tertiary-fixed-variant: '#653e00'
  background: '#f8f9ff'
  on-background: '#0b1c30'
  surface-variant: '#d3e4fe'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 57px
    fontWeight: '700'
    lineHeight: 64px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
  title-lg:
    fontFamily: Inter
    fontSize: 22px
    fontWeight: '500'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.1px
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.5px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  xs: 4px
  sm: 12px
  md: 16px
  lg: 24px
  xl: 32px
  container-max: 1280px
  gutter: 24px
  margin-mobile: 16px
---

## Brand & Style
The design system focuses on accessibility and clarity for homeowners interacting with complex ERP data. The personality is **Approachable Professionalism**—balancing the reliability of an enterprise system with the warmth of a consumer-facing application.

Drawing from **Modern Corporate** and **Minimalist** influences, the system utilizes Material Design 3 (MD3) principles:
- **Clarity over Density:** Increased whitespace and generous hit targets ensure the UI feels unhurried and manageable for non-technical users.
- **Friendly Authority:** The interface remains structured and "stable" to instill trust, but utilizes rounded corners and soft tonal shifts to feel inviting rather than clinical.
- **Human-Centric:** Information is grouped into logical "cards" or "modules" to prevent cognitive overload.

## Colors
The palette is anchored by a **Warm Teal (#0D9488)**, which provides a refreshing, trustworthy alternative to standard corporate blues. 

- **Primary:** Used for key actions, active states, and brand presence.
- **Surface:** A high-brightness strategy using pure white for content cards and a soft "Slate" gray (#F8FAFC) for background containment.
- **Semantic:** Status indicators are high-chroma but balanced with soft background tints (e.g., a light amber background with a dark amber text for "Pending" status) to ensure readability and a gentle tone.

## Typography
The system uses **Inter** exclusively to maintain a clean, systematic look that excels in legibility. 

- **Hierarchy:** Strong weight differentiation is used to guide the eye. Headlines use Medium (500) and SemiBold (600) weights to stand out against body text.
- **Readability:** Line heights are slightly increased (1.5x for body text) to accommodate homeowners who may be viewing complex billing or service data on mobile devices.
- **Functional Labels:** All-caps are avoided for labels to maintain the "friendly" tone; instead, we use SemiBold weight and subtle letter spacing for button text and category headers.

## Layout & Spacing
The layout follows a **Fluid Grid** model with strict adherence to an 8px spacing scale.

- **Desktop:** 12-column grid with a 1280px max-width container. Content is centered with generous side margins to prevent eye strain.
- **Mobile:** Single column with 16px side margins. Hit targets for buttons and links are a minimum of 48x48px to ensure ease of use for all ages.
- **Rhythm:** Vertical rhythm is maintained by using `lg` (24px) spacing between distinct cards and `md` (16px) spacing for elements within a card.

## Elevation & Depth
In accordance with MD3, depth is primarily communicated through **Tonal Layers** rather than heavy shadows.

- **Level 0 (Background):** Surface Light (#F8FAFC) used for the page body.
- **Level 1 (Cards):** Pure White (#FFFFFF) with a very soft, high-diffusion shadow (4px blur, 2% opacity) or a subtle 1px border (#E2E8F0) to define boundaries.
- **Interactions:** On hover, cards may lift slightly using a more pronounced shadow or a subtle primary-colored inner border to indicate focus.
- **Modals:** Use a heavy backdrop blur (8px) to isolate the user's attention from the background data.

## Shapes
The design system utilizes **Rounded** geometry to soften the "enterprise" feel. 

- **Standard Elements:** Buttons, input fields, and small components use 0.5rem (8px) corners.
- **Large Elements:** Content cards and main navigation containers use `rounded-lg` (16px) to emphasize the friendly, modern aesthetic.
- **Selection UI:** Checkboxes use a small 4px radius, while radio buttons remain fully circular.

## Components
Consistent component behavior is essential for the homeowner experience:

- **Buttons:** 
  - **Primary:** Solid Teal with white text. 
  - **Secondary:** Tonal Teal (Teal at 10% opacity) with Teal text.
  - **Size:** Standard buttons are 44px high; mobile-friendly "Action" buttons are 52px high.
- **Input Fields:** Outlined style with 1px gray borders. On focus, the border thickens to 2px in Primary Teal. Labels sit above the field rather than floating inside to maintain constant visibility.
- **Chips/Badges:** Used for status. They should feature a low-contrast background (10% of the semantic color) and high-contrast text for accessibility.
- **Cards:** The primary container for ERP data (e.g., "Active Projects", "Latest Invoice"). Every card should have a clear title and a primary action button at the bottom.
- **Empty States:** Use soft, simplified illustrations and a "Friendly Teal" primary button to guide the user to their first action.
- **Lists:** High-density lists are avoided. List items feature 16px of vertical padding and distinct dividers.