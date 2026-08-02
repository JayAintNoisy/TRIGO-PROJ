# TRIGO Feature Plan

Based on the provided design files, here is a detailed assessment and analysis of the features presented in the project UI, grouped by the folder they are located in. Each feature includes framework-agnostic layout directions (colors, spacing, layout structures, and UI properties) so they can be easily replicated in Tailwind CSS, Flutter, React, or Vue.js.

## 1. Admin Portal (`screens/admin/`)

*   **`admin-dashboard.png` (Dashboard Overview & Recent Rides)**
    *   **Layout:** CSS Grid layout for main content area. Top row (`grid-template-columns: repeat(4, 1fr)`) for metrics, spanning full width for the table below.
    *   **Metric Cards:** `background: #FFFFFF`; `border-radius: 12px`; `box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05)`; `padding: 24px`.
        *   **Contents (Flex-col):** Icon container (tinted bg, `border-radius: 8px`), Title (`color: #64748B`, `font-size: 14px`), Value (`color: #0F172A`, `font-size: 32px`, `font-weight: 700`), Trend tag (`color: #10B981` or `#EF4444`).
    *   **Recent Rides Table:** `background: #FFFFFF`; `border-radius: 12px`; `padding: 24px`. Header row (`display: flex`, `justify-content: space-between`, `align-items: center`). Table rows (`display: grid` or flex-row) with bottom border (`border-bottom: 1px solid #E2E8F0`). Status badges use pill shapes (`border-radius: 9999px`, `padding: 4px 12px`) with soft tinted backgrounds (e.g., `#D1FAE5` for success).

*   **`admin-communication.png` (Communication Center)**
    *   **Layout:** Split pane or 2-column Grid (`grid-template-columns: 300px 1fr`).
    *   **Sidebar (List):** `display: flex`, `flex-direction: column`, `gap: 8px`. Items have `padding: 12px 16px`, `border-radius: 8px`. Active item has `background: #F8FAFC` and left-border accent (`border-left: 4px solid #2563EB`).
    *   **Chat/Message Area:** Flex column. Header (`padding: 16px`, bottom border), Scrollable body (`flex: 1`, `padding: 16px`), Input footer (`padding: 16px`, top border). Input field (`border-radius: 9999px`, `background: #F1F5F9`, `padding: 12px 20px`).

*   **`admin-driver.png` & `admin-passenger.png` (User Management Lists)**
    *   **Layout:** Single full-width container (`background: #FFFFFF`, `border-radius: 12px`, `padding: 24px`, soft shadow).
    *   **Toolbar:** `display: flex`, `justify-content: space-between`, `margin-bottom: 24px`. Search input (`border-radius: 8px`, `border: 1px solid #E2E8F0`). Add/Filter buttons (`background: #2563EB`, `color: #FFFFFF`, `border-radius: 8px`, `padding: 8px 16px`).
    *   **List Rows:** Flex row with user avatar (`width/height: 40px`, `border-radius: 50%`), name column, status badge, and action menu icon (vertical dots).

*   **`admin-fare-matrix.png` (Fare Configuration)**
    *   **Layout:** Form container (`max-width: 600px`, `background: #FFFFFF`, `border-radius: 12px`, `padding: 32px`, `margin: 0 auto`).
    *   **Inputs:** `display: flex`, `flex-direction: column`, `gap: 24px`. Each field group has a label (`color: #0F172A`, `margin-bottom: 8px`), and input field (`border: 1px solid #E2E8F0`, `border-radius: 8px`, `padding: 12px`, focus state: `border-color: #2563EB`, `box-shadow: 0 0 0 3px rgba(37,99,235,0.2)`).
    *   **Submit Button:** Full width (`width: 100%`), `background: #2563EB`, `color: white`, `border-radius: 12px`, `padding: 16px`, `font-weight: 600`.

*   **`admin-financial.png` (Financial Reports)**
    *   **Layout:** Multi-section Grid. Top row charts, bottom row transaction lists.
    *   **Chart Cards:** `background: #FFFFFF`, `border-radius: 12px`, `padding: 24px`. Use a canvas/SVG container. Axes labels (`color: #64748B`, `font-size: 12px`).
    *   **Summary Cards:** Similar to dashboard metrics but themed with Brand Green (`#10B981`) for revenue numbers.

*   **`admin-safety.png` (Safety & Reports)**
    *   **Layout:** Flex column. Prominent Alert Banners at the top if there are active SOS alerts.
    *   **Alert Banner:** `background: #FEE2E2` (Danger Light), `border-left: 4px solid #EF4444`, `padding: 16px`, `display: flex`, `align-items: center`, `gap: 12px`. Text `color: #991B1B`.

---

## 2. Mobile App (`screens/app/`)

### Authentication & Onboarding
*   **`landing-page.png`, `*-login.png`, `*-register.png`**
    *   **Layout:** Full-screen flex column (`min-height: 100vh`, `justify-content: center`, `align-items: center`).
    *   **Background:** Landing page uses `background: linear-gradient(to bottom right, #14B8A6, #2563EB)`. Others use neutral `#F8FAFC`.
    *   **Form Cards:** `background: #FFFFFF`, `width: 100%` (with `padding-left/right: 20px` safe area), `border-radius: 24px` (top only if bottom sheet, or all sides if centered card), prominent shadow (`box-shadow: 0 10px 15px -3px rgba(0,0,0,0.1)`).
    *   **Role Buttons:** High contrast. Passenger: `background: #10B981`, Driver: `background: #F97316`. `border-radius: 16px`, `padding: 20px`, `display: flex`, `align-items: center`, `gap: 16px`.

### Active Ride & Mapping
*   **`passenger-home.png`, `driver-waiting-online.png`**
    *   **Layout:** Full-screen map (Z-index 0) with absolute positioned floating elements (Z-index 10).
    *   **Search/Address Bar (Passenger):** Absolute top (`top: 40px`, `left: 20px`, `right: 20px`). `background: #FFFFFF`, `border-radius: 12px`, `box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1)`, `padding: 16px`.
    *   **Online Toggle (Driver):** Absolute top center. Pill-shaped (`border-radius: 9999px`), `background: #10B981`, `color: white`, heavy shadow.

*   **`passenger-active-ride.png`, `driver-active-ride.png`**
    *   **Layout:** Map background. Bottom Sheet card containing ride details.
    *   **Bottom Sheet:** `position: absolute`, `bottom: 0`, `width: 100%`, `background: #FFFFFF`, `border-top-left-radius: 24px`, `border-top-right-radius: 24px`, `padding: 24px`, heavy drop shadow (`box-shadow: 0 -4px 10px rgba(0,0,0,0.05)`).
    *   **Driver/Passenger Info:** `display: flex`, `flex-direction: row`, `align-items: center`, `gap: 16px`. Avatar (`width: 48px`, `height: 48px`, `border-radius: 50%`). Text column (`flex: 1`).
    *   **Action Buttons (Call/Text):** Side-by-side (`display: grid`, `grid-template-columns: 1fr 1fr`, `gap: 12px`). Call (`background: #2563EB`), Text (`background: #10B981`). Both: `border-radius: 12px`, `padding: 12px`, `color: white`, `text-align: center`, `font-weight: 600`.
    *   **Main Action Button (Arrived / Complete):** Full width, massive, `background: #2563EB`, `padding: 16px`, `border-radius: 12px`, `font-size: 18px`, `box-shadow: 0 4px 10px rgba(37,99,235,0.4)`.

### Driver Earnings & Wallet
*   **`driver-earnings.png`**
    *   **Layout:** Flex column with `padding: 20px`, `background: #F8FAFC`.
    *   **Hero Earnings Card:** Large top card. `background: #059669` (Dark Green), `color: #FFFFFF`, `border-radius: 24px`, `padding: 32px 24px`. Huge typography for balance (`font-size: 48px`, `font-weight: 700`).
    *   **Trip Breakdown List:** `background: #FFFFFF`, `border-radius: 16px`, `padding: 16px`, `margin-top: 24px`. Rows: `display: flex`, `justify-content: space-between`, `padding: 12px 0`, border bottom.

### Dispatch & Ride Requests
*   **`new-ride-request.png`**
    *   **Layout:** Modal/Dialog overlaid on map with a dark translucent backdrop (`background: rgba(0,0,0,0.5)`).
    *   **Dialog Card:** Centered (`margin: auto`), `width: 85%`, `background: #FFFFFF`, `border-radius: 24px`, `padding: 24px`.
    *   **Buttons:** Accept (`background: #10B981`, heavy shadow), Reject (`background: transparent`, `color: #64748B`, `border: 1px solid #E2E8F0`).

### Settings, Profile, & General Shared Features
*   **`*-profile.png`, `*-settings.png`, `passenger-history.png`, `help-and-support.png`**
    *   **Layout:** Standard mobile list view.
    *   **Header:** `display: flex`, `align-items: center`, `padding: 16px 20px`, `border-bottom: 1px solid #E2E8F0`. Back button on left, title centered.
    *   **List Groups:** `display: flex`, `flex-direction: column`, `margin: 24px 20px`.
    *   **List Item:** `display: flex`, `flex-direction: row`, `align-items: center`, `justify-content: space-between`, `padding: 16px 0`, `border-bottom: 1px solid #F1F5F9`. Left side: Icon (`color: #64748B`) + Text (`color: #0F172A`). Right side: Chevron arrow or Toggle switch.

---

## 3. Color Scheme & Theming

The design uses a modern, vibrant, and clean palette. Here is the color scheme broken down by primary, secondary, status, and neutral colors, ready for theming (e.g., in Tailwind CSS or standard CSS variables):

### Primary Colors (Brand & Action)
*   **Brand Blue** (Primary buttons, active states, gradients)
    *   **Light (Hover/Soft backgrounds):** `#60A5FA` (approx. Blue 400)
    *   **Base (Main Brand/Buttons):** `#2563EB` to `#1D4ED8` (approx. Blue 600/700)
    *   **Dark (Active/Pressed):** `#1E3A8A` (approx. Blue 900)
*   **Brand Green** (Passenger branding, Earnings/Money, success metrics)
    *   **Light (Backgrounds/Soft tags):** `#D1FAE5` (approx. Emerald 50/100)
    *   **Base (Main Actions/Icons):** `#10B981` (approx. Emerald 500)
    *   **Dark (Earnings Cards/Solid):** `#059669` (approx. Emerald 600)

### Secondary & Accent Colors
*   **Driver Orange/Yellow** (Driver role, tricycle illustrations, warnings)
    *   **Yellow Base (Tricycle Icon):** `#EAB308` (approx. Yellow 500)
    *   **Orange Base (Driver Actions/Icons):** `#F97316` or `#EA580C` (approx. Orange 500/600)
*   **Admin Purple** (Secondary actions in Admin Dashboard)
    *   **Light (Soft backgrounds):** `#F3E8FF` (approx. Purple 100)
    *   **Base (Buttons):** `#A855F7` or `#9333EA` (approx. Purple 500/600)

### Status Colors
*   **Danger/Alert Red** (Map markers, active SOS alerts)
    *   **Light (SOS Background):** `#FEE2E2` (approx. Red 100)
    *   **Base (Map Pin):** `#EF4444` (approx. Red 500)
*   **Warning Yellow** ("In Transit" statuses)
    *   **Base:** `#FEF08A` (approx. Yellow 200)

### Neutral Colors (Typography & Backgrounds)
*   **Backgrounds & Surfaces**
    *   **App Background:** `#F8FAFC` (approx. Slate 50)
    *   **Card Surface:** `#FFFFFF` (White)
    *   **Dividers/Borders:** `#E2E8F0` (approx. Slate 200)
*   **Typography**
    *   **Primary Text (Headings/Important info):** `#0F172A` (approx. Slate 900)
    *   **Secondary Text (Subtitles/Timestamps):** `#64748B` (approx. Slate 500)
    *   **Disabled/Placeholder:** `#94A3B8` (approx. Slate 400)

### Gradients
*   **Landing Page Gradient:** Starts with a vibrant teal/green (`#14B8A6`) and transitions smoothly into Brand Blue (`#2563EB`).

---

## 4. UI/UX Patterns & Design Language

The application follows a modern, mobile-first design language characterized by clean typography, ample whitespace, and a card-based layout system. The UI heavily relies on soft flat design, using subtle drop shadows to create depth without harsh borders.

### Global UI Properties & Layout Architecture

#### 1. Border Radius (Rounded Corners)
The design avoids sharp edges, using rounded corners to create a friendly and approachable feel.
*   **Buttons:** Fully rounded (pill-shaped) or heavily rounded. Property: `border-radius: 9999px` (for pill) or `border-radius: 12px` (`0.75rem`) for standard buttons.
*   **Cards & Modals (Bottom Sheets):** Large rounding for emphasis. Property: `border-radius: 24px` (`1.5rem`). Often applied only on top corners for bottom sheets (`border-top-left-radius`, `border-top-right-radius`).
*   **Small Elements (Tags, Badges, Icons):** Subtle rounding. Property: `border-radius: 8px` (`0.5rem`).

#### 2. Shadows & Elevation
Shadows are soft and diffused, used primarily to lift interactive elements and cards off the light gray background.
*   **Cards/Containers:** Soft, spread-out shadow. Property: `box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05), 0 2px 4px -1px rgba(0, 0, 0, 0.03)`.
*   **Primary Actions (FABs/Main Buttons):** Stronger, more focused shadow to indicate interactivity. Property: `box-shadow: 0 10px 15px -3px rgba(37, 99, 235, 0.3)` (often tinted with the button's primary color).
*   **Header/Nav Bar:** Subtle bottom shadow when scrolling. Property: `box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1)`.

#### 3. Spacing (Margin & Padding)
The layout relies on a consistent 8pt/4pt grid system to ensure visual rhythm.
*   **Screen Edge Padding (Safe Area):** Consistent horizontal padding across all screens. Property: `padding-left: 20px` (`1.25rem`), `padding-right: 20px`.
*   **Card Internal Padding:** Spacious interiors to prevent text cramping. Property: `padding: 16px` (`1rem`) to `24px` (`1.5rem`).
*   **Inter-element Spacing (Gap):** Distance between stacked items (like list rows). Property: `gap: 12px` (`0.75rem`) or `margin-bottom: 16px`.
*   **Section Spacing:** Distance between major visual blocks. Property: `margin-bottom: 32px` (`2rem`).

#### 4. Layout Structures (Columns & Rows)
The layouts are highly structured using Flexbox/Grid-style principles.
*   **List Items (Rows):** Typically structured as a horizontal row with centered cross-axis alignment.
    *   *Implementation concept:* `display: flex`, `flex-direction: row`, `align-items: center`, `justify-content: space-between`.
    *   *Usage:* Ride history lists, settings menus, profile details.
*   **Main Screen Flow (Columns):** The overall screen flow is top-to-bottom.
    *   *Implementation concept:* `display: flex`, `flex-direction: column`, `align-items: stretch`.
*   **Grids (Dashboard/Metrics):** For stats on the admin dashboard or earnings page.
    *   *Implementation concept:* `display: grid`, `grid-template-columns: repeat(2, 1fr)` (for mobile split views) or `repeat(4, 1fr)` (for desktop admin metrics), `gap: 16px`.

#### 5. Typography
*   **Headings:** Bold and prominent. E.g., `font-weight: 700`, `font-size: 24px`.
*   **Body Text:** Regular weight, high legibility. E.g., `font-weight: 400`, `font-size: 14px` or `16px`.
*   **Hierarchy:** Important data (like a Fare or ETA) uses large typography and high-contrast color (Brand Blue or Brand Green) to stand out immediately against the neutral background.

#### 6. Interactive Feedback (UX)
*   **Active States:** Buttons darken on press/hover (using the Dark shades from the color palette).
*   **Transitions:** Smooth transitions for state changes. Property: `transition: all 0.2s ease-in-out`.
