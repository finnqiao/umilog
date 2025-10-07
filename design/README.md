# UmiLog Design Prototype

This directory contains a **visual reference prototype** exported from Figma. It is a React/TypeScript web application that demonstrates the UI/UX design for the native iOS app.

## Purpose

This prototype serves as:
- **Visual reference** for iOS implementation
- **Component library** showing layouts, spacing, and interactions
- **Color palette** and design token reference
- **Screen flow** documentation

**Important**: This is NOT the production iOS app. The native app will be built in SwiftUI and located in the repository root when development begins.

## Original Source

- **Figma Design**: https://www.figma.com/design/JwMxy351eNAi3eQvWX6GBA/UmiLog-Dive-Log-App
- **Export Date**: October 2024
- **Framework**: React 18 + Vite + TypeScript
- **UI Library**: shadcn/ui (Radix UI components)
- **Styling**: Tailwind CSS

## Running the Prototype (Optional)

If you want to view the interactive prototype locally:

```bash
cd design/
npm install
npm run dev
```

Then open http://localhost:5173 in your browser.

**Note**: The web prototype uses browser LocalStorage for data persistence. It's purely for demonstration.

## iOS Translation

For guidance on translating this web design to native iOS:

1. **Start here**: Read [../DESIGN.md](../DESIGN.md) - Complete iOS translation guide
2. **Component mappings**: Web components → SwiftUI equivalents
3. **Design tokens**: Color palette, typography, spacing system
4. **Screen specs**: Detailed breakdown of each screen's components

## Key Screens

### 1. Dashboard (`src/components/Dashboard.tsx`)
- Quick stats grid (4 cards)
- Hero map card with overlay
- Recent dives list
- Quick action buttons

### 2. Dive Logger (`src/components/DiveLogger.tsx`)
- Site selection
- Depth and time inputs
- Environmental conditions (temp, visibility, current)
- Wildlife tracking
- Notes and instructor sign-off

### 3. Dive History (`src/components/DiveHistory.tsx`)
- Filterable dive list
- Dive detail cards
- Export functionality

### 4. Site Explorer (`src/components/SiteExplorer.tsx`)
- Interactive map view
- Site list with details
- Visited vs wishlist filtering

### 5. Backfill Wizard (`src/components/BackfillWizard.tsx`)
- Multi-step import flow
- CSV/UDDF import support
- Bulk entry capabilities

## Data Model

See `src/types/index.ts` for TypeScript interfaces:
- `DiveLog` - Core dive entry structure
- `DiveSite` - Location data
- `WildlifeSpecies` - Marine life catalog
- `UserStats` - Aggregated statistics

These types map directly to the Swift models in the iOS app.

## Mock Data

`src/data/mockData.ts` contains sample data for:
- Dive sites (Caribbean, Mediterranean, Indo-Pacific)
- Wildlife species by category
- Example dive logs
- User statistics

Use this as reference for seed data in the iOS app.

## Design System

### Colors (Tailwind → iOS)
```typescript
// Web (Tailwind)
blue-600: #2563EB    // → Color.primary (iOS)
teal-600: #0D9488    // → depth metrics
green-600: #16A34A   // → success states
purple-600: #9333EA  // → wildlife
red-600: #DC2626     // → warnings
```

### Spacing (4px base)
```typescript
p-2: 8px   // → .padding(8)
p-4: 16px  // → .padding(16)
p-6: 24px  // → .padding(24)
gap-4: 16px // → .spacing(16)
```

### Typography
```typescript
text-3xl: 30px  // → .largeTitle
text-xl: 20px   // → .title
text-base: 16px // → .body
text-sm: 14px   // → .callout
```

## Attribution

- **shadcn/ui components**: MIT License - https://ui.shadcn.com/
- **Unsplash photos**: Unsplash License - https://unsplash.com/license
- **Lucide icons**: ISC License - https://lucide.dev/

## Development Workflow

When implementing iOS screens:

1. **Reference this prototype** for visual design
2. **Consult DESIGN.md** for SwiftUI implementation details
3. **Match colors/spacing** using the design tokens
4. **Adapt for iOS HIG** (navigation patterns, gestures, accessibility)
5. **Use SF Symbols** instead of Lucide icons (see DESIGN.md mappings)

## Not for Production

This web prototype is:
- ✅ Great for visual reference
- ✅ Useful for design discussions
- ✅ Helpful for understanding user flows
- ❌ NOT the production iOS app
- ❌ NOT maintained after iOS development starts
- ❌ NOT accessible to end users

---

**For iOS implementation**: See parent directory and start with [../DESIGN.md](../DESIGN.md)
