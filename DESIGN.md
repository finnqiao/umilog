# UmiLog Design System

This document outlines the design system, UI components, and screen flows for UmiLog, translated from web prototype to native iOS implementation.

## Design Source

The `design/` directory contains a React/TypeScript web prototype originally created in Figma. This serves as a visual reference for the iOS native app implementation. The web prototype uses:

- **Framework**: React 18 + TypeScript + Vite
- **UI Library**: shadcn/ui (Radix UI components)
- **Styling**: Tailwind CSS
- **Icons**: Lucide React

**Figma Source**: https://www.figma.com/design/JwMxy351eNAi3eQvWX6GBA/UmiLog-Dive-Log-App

## Core Data Model

### DiveSite
```typescript
{
  id: string
  name: string
  location: string
  coordinates: { lat: number, lng: number }
  region: string
  averageDepth: number
  maxDepth: number
  averageTemp: number
  averageVisibility: number
  difficulty: 'Beginner' | 'Intermediate' | 'Advanced'
  type: 'Reef' | 'Wreck' | 'Wall' | 'Cave' | 'Shore' | 'Drift'
  description?: string
}
```

### DiveLog
```typescript
{
  id: string
  siteId: string
  date: string
  startTime: string
  endTime?: string
  maxDepth: number
  averageDepth?: number
  bottomTime: number  // minutes
  startPressure: number  // bar
  endPressure: number  // bar
  temperature: number  // celsius
  visibility: number  // meters
  current: 'None' | 'Light' | 'Moderate' | 'Strong'
  conditions: 'Excellent' | 'Good' | 'Fair' | 'Poor'
  wildlife: WildlifeSighting[]
  notes: string
  instructorName?: string
  instructorNumber?: string
  signed: boolean
  photos?: string[]
  equipment?: {
    wetsuit: string
    tank: string
    weights: number
  }
}
```

### WildlifeSpecies
```typescript
{
  id: string
  name: string
  scientificName: string
  region: string[]
  category: 'Fish' | 'Coral' | 'Mammal' | 'Invertebrate' | 'Reptile'
  rarity: 'Common' | 'Uncommon' | 'Rare' | 'Very Rare'
  imageUrl?: string
}
```

### UserStats
```typescript
{
  totalDives: number
  totalBottomTime: number  // minutes
  maxDepth: number  // meters
  sitesVisited: number
  speciesSpotted: number
  certificationsLevel: string
  divingSince: string
}
```

## Screen Architecture

### 1. Dashboard (Home)
**Purpose**: Main hub showing quick stats, recent dives, and quick actions

**Components**:
- Header with "UmiLog" branding and "Log Dive" CTA button
- Quick stats grid (4 cards):
  - Total Dives (blue accent)
  - Max Depth (teal accent)
  - Sites Visited (green accent)
  - Species Spotted (purple accent)
- Hero map card with "Explore Dive Sites" overlay
- Recent dives list (last 3) with dive cards showing:
  - Dive number
  - Date, max depth, bottom time
  - Notes preview
  - Site reference
  - "Signed" badge if applicable
- Quick action cards: Site Explorer, Statistics

**iOS Translation**:
- Use `ScrollView` with `VStack` for vertical layout
- Stats: `LazyVGrid` with 2x2 grid on iPhone, 4x1 on iPad
- Map card: `ZStack` with background image and overlay
- Recent dives: `List` or `ForEach` in `VStack`
- Floating action button for "Log Dive" (bottom trailing)

### 2. Dive Logger
**Purpose**: Real-time or post-dive logging interface

**Components**:
- Site selector (dropdown or search)
- Date and time pickers
- Depth inputs (max, average)
- Bottom time input
- Pressure inputs (start, end)
- Environmental conditions:
  - Temperature slider
  - Visibility slider
  - Current strength selector
  - Overall conditions selector
- Wildlife tracker with species search and count
- Equipment section (optional)
- Notes text area
- Instructor sign-off section
- Save button

**iOS Translation**:
- Use `Form` with `Section` grouping
- `Picker` for site selection with search capability
- `DatePicker` for date/time
- `TextField` with number formatting for depths/pressures
- `Slider` for temperature and visibility
- Custom wildlife selector with `.searchable` modifier
- `TextEditor` for notes
- Pre-fill defaults based on GPS location and season

### 3. Dive History
**Purpose**: Browse and filter all logged dives

**Components**:
- Filter bar (by date, site, conditions)
- Dive list with cards showing:
  - Site name and location
  - Date and time
  - Depth and duration
  - Thumbnail photos
  - Wildlife spotted count
- Detail view on selection
- Export button in toolbar

**iOS Translation**:
- `NavigationStack` with filtered `List`
- `.searchable` for quick filtering
- Custom list rows with dive summary
- `NavigationLink` to detail view
- Share sheet for export functionality

### 4. Site Explorer
**Purpose**: Discover and browse dive sites

**Components**:
- Interactive map view with site markers
- List/Map toggle
- Site cards showing:
  - Site name and location
  - Average depth and temperature
  - Difficulty and type badges
  - "Visited" indicator
  - Distance from current location
- Site detail view with:
  - Full specifications
  - Description
  - Typical wildlife
  - Weather/conditions info
- "Add to Wishlist" button
- "Log Dive Here" action

**iOS Translation**:
- `MapKit` integration with custom annotations
- `Picker` for List/Map view toggle
- GPS-based site suggestions
- Custom site detail sheet with `ScrollView`
- Offline caching of site database

### 5. Backfill Wizard
**Purpose**: Quickly add multiple historical dives

**Components**:
- Multi-step wizard with progress indicator
- CSV/UDDF import option
- Manual entry mode with templates
- Bulk date/site selection
- Quick copy from previous dive
- Photo import with EXIF data extraction
- Review and confirm step

**iOS Translation**:
- Tab-based or paged wizard flow
- `DocumentPicker` for import
- Form templates with smart defaults
- Photo picker with metadata extraction
- Summary view before batch save

### 6. More/Settings (in prototype)
**Purpose**: Additional features and app settings

**Components**:
- Backfill wizard launcher
- Data export
- Settings and preferences
- About and attributions

**iOS Translation**:
- Standard iOS Settings-style `List`
- Settings bundles for system integration
- Share sheet for exports
- Privacy and sync controls

## Design System Tokens

### Colors

#### Primary Palette
- **Ocean Blue**: `#2563EB` - Primary actions, water/depth indicators
- **Teal**: `#0D9488` - Depth metrics, water temp
- **Sea Green**: `#16A34A` - Success states, sites visited
- **Purple**: `#9333EA` - Wildlife, specialty indicators
- **Coral Red**: `#DC2626` - Warnings, required fields

#### Semantic Colors
- **Background**: System background colors
- **Card**: Elevated surface color
- **Border**: Subtle divider color
- **Muted**: Secondary text and backgrounds
- **Accent**: Highlighted interactive elements

**iOS Mapping**:
```swift
// Use semantic colors that adapt to dark mode
Color.primary    // Ocean Blue
Color.secondary  // Teal
Color.accentColor // User-configurable
.background
.secondaryBackground
.systemGray6  // Card backgrounds
```

### Typography

#### Web (Tailwind)
- Headings: `text-3xl`, `text-2xl`, `text-xl`
- Body: `text-base` (14px base)
- Small: `text-sm`, `text-xs`
- Weight: `font-bold` (700), `font-medium` (500), `regular` (400)

#### iOS Translation
```swift
// Use Dynamic Type for accessibility
.font(.largeTitle)      // Dashboard title
.font(.title)           // Section headers
.font(.title2)          // Card titles
.font(.headline)        // Emphasis text
.font(.body)            // Primary text
.font(.callout)         // Secondary text
.font(.caption)         // Metadata, timestamps
```

### Spacing

**Web Scale**: 4px base unit (Tailwind)
- `p-2` = 8px
- `p-4` = 16px
- `p-6` = 24px
- `gap-2` = 8px
- `gap-4` = 16px

**iOS Translation**:
```swift
// Use consistent spacing multiples of 4
.padding(8)
.padding(16)
.padding(24)
.spacing(8)
.spacing(16)
```

### Corner Radius

**Web**:
- `rounded-lg` = 8px
- `rounded-xl` = 12px
- `rounded-full` = 9999px

**iOS**:
```swift
.cornerRadius(8)
.cornerRadius(12)
.clipShape(Circle())  // for rounded-full
```

### Shadows

**Web**: `shadow-lg`, `shadow-md`, `shadow-sm`

**iOS**:
```swift
.shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
.shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
```

## Component Patterns

### Cards
**Web**: Border + rounded corners + padding
```typescript
<Card>
  <CardHeader>
    <CardTitle>Title</CardTitle>
  </CardHeader>
  <CardContent>
    {/* content */}
  </CardContent>
</Card>
```

**iOS**:
```swift
VStack(alignment: .leading, spacing: 8) {
    Text("Title")
        .font(.headline)
    
    // content
}
.padding()
.background(Color.secondaryBackground)
.cornerRadius(12)
.shadow(color: .black.opacity(0.05), radius: 5)
```

### Buttons

**Primary**: Filled with blue background
**Secondary**: Outline style
**Tertiary**: Text only

**iOS**:
```swift
// Primary
Button("Log Dive") { }
    .buttonStyle(.borderedProminent)
    .tint(.blue)

// Secondary
Button("Cancel") { }
    .buttonStyle(.bordered)

// Tertiary
Button("Skip") { }
    .buttonStyle(.plain)
```

### Input Fields

**iOS Best Practices**:
- Use `TextField` with appropriate keyboard types
- Number inputs: `.keyboardType(.decimalPad)`
- Sliders for ranges with clear min/max labels
- `Picker` for predefined options
- Voice input buttons for critical fields (depth, time, pressure)

### Lists and Cards

**iOS Guidelines**:
- Use `List` for scrollable content with built-in styling
- Custom cards with `VStack`/`HStack` in `ForEach`
- Swipe actions for quick edits/deletes
- Pull-to-refresh for sync

## Navigation Patterns

### Web: Single-page with view switching
```typescript
const [currentView, setCurrentView] = useState<AppView>('home')
```

### iOS: TabView + NavigationStack
```swift
TabView {
    NavigationStack {
        DashboardView()
    }
    .tabItem {
        Label("Home", systemImage: "house.fill")
    }
    
    NavigationStack {
        DiveLoggerView()
    }
    .tabItem {
        Label("Log", systemImage: "plus.circle.fill")
    }
    
    NavigationStack {
        DiveHistoryView()
    }
    .tabItem {
        Label("History", systemImage: "clock.fill")
    }
    
    NavigationStack {
        SiteExplorerView()
    }
    .tabItem {
        Label("Sites", systemImage: "map.fill")
    }
    
    NavigationStack {
        SettingsView()
    }
    .tabItem {
        Label("More", systemImage: "ellipsis.circle.fill")
    }
}
```

## Unique iOS Considerations

### 1. Offline-First
- Cache all accessed data locally
- Show sync status indicators
- Queue operations when offline
- Background sync when online

### 2. Voice Input
- Microphone button on key input fields
- Real-time transcription display
- "Did you mean?" corrections
- Haptic feedback on successful parse

### 3. Apple Watch Integration
- Simplified logging interface
- Auto-detect dive start (immersion)
- Push depth/time/pressure to iPhone
- Quick wildlife logging with Digital Crown

### 4. Performance
- Lazy loading of lists
- Image thumbnails with progressive loading
- Background processing for imports
- Optimized Core Data/GRDB queries

### 5. Accessibility
- VoiceOver support for all controls
- Dynamic Type support
- High contrast mode
- Reduce motion support
- Voice input as accessibility feature

## Animation and Feedback

### Web Transitions
- Hover states on cards
- Smooth view transitions
- Loading states with spinners

### iOS Animations
```swift
// Card tap feedback
.scaleEffect(isPressed ? 0.95 : 1.0)
.animation(.easeInOut(duration: 0.2), value: isPressed)

// List item insertion
.transition(.move(edge: .top).combined(with: .opacity))

// Success feedback
let generator = UINotificationFeedbackGenerator()
generator.notificationOccurred(.success)
```

## Responsive Design

### Web: Breakpoints
- Mobile: < 768px
- Tablet: 768px - 1024px
- Desktop: > 1024px

### iOS: Size Classes
- Compact width: iPhone portrait
- Regular width: iPhone landscape, iPad
- Compact height: iPhone landscape
- Regular height: iPhone portrait, iPad

```swift
@Environment(\.horizontalSizeClass) var sizeClass

if sizeClass == .compact {
    // iPhone portrait layout
} else {
    // iPad or landscape layout
}
```

## Icon System

### Web: Lucide React
Common icons used:
- `Home`, `Plus`, `History`, `Map`, `MoreHorizontal`
- `Fish`, `Award`, `MapPin`, `Calendar`, `BarChart3`

### iOS: SF Symbols
Equivalent mappings:
- `house.fill` → Home
- `plus.circle.fill` → Plus
- `clock.fill` → History
- `map.fill` → Map
- `ellipsis.circle.fill` → More
- `fish.fill` → Fish
- `rosette` → Award
- `mappin.circle.fill` → MapPin
- `calendar` → Calendar
- `chart.bar.fill` → BarChart3

## Implementation Priority

### Phase 1: Core Screens (MVP)
1. Dashboard with stats
2. Basic dive logger
3. Dive history list
4. Simple site selector

### Phase 2: Enhanced Features
1. Site explorer with map
2. Wildlife tracking
3. Photo integration
4. Voice input

### Phase 3: Advanced Features
1. Backfill wizard
2. Import/export
3. Apple Watch app
4. CloudKit sync

### Phase 4: Polish
1. Animations and transitions
2. Haptic feedback
3. Widgets
4. Shortcuts integration

## Design Review Checklist

When implementing screens, verify:
- ✅ Uses semantic colors that adapt to dark mode
- ✅ Supports Dynamic Type (all text)
- ✅ Works in both portrait and landscape
- ✅ Has appropriate loading and error states
- ✅ Includes haptic feedback for key actions
- ✅ Accessible via VoiceOver
- ✅ Follows iOS HIG patterns
- ✅ Performs smoothly (60fps scrolling)
- ✅ Handles keyboard appearance gracefully
- ✅ Uses appropriate SF Symbols

## Resources

- **Figma Design**: https://www.figma.com/design/JwMxy351eNAi3eQvWX6GBA/UmiLog-Dive-Log-App
- **shadcn/ui Components**: https://ui.shadcn.com/
- **iOS HIG**: https://developer.apple.com/design/human-interface-guidelines/
- **SF Symbols**: https://developer.apple.com/sf-symbols/

## License

Design components from shadcn/ui used under MIT License.
Photos from Unsplash used under Unsplash License.