# FreshTrack — Smart Kitchen Manager

A SwiftUI iOS app that tracks food freshness, scans product barcodes, syncs expiry dates to Apple Calendar, sends local expiry reminders, and suggests batch cooking recipes using expiring ingredients.

## Architecture

| File | Purpose |
|---|---|
| `Theme.swift` | Full design system — colors, typography, radii, shadows, gradients, view modifiers (extracted from HTML/CSS) |
| `FoodItem.swift` | Data models: `FoodItem`, `Recipe`, `ShoppingItem`, enums, sample data |
| `FoodStore.swift` | Central `@ObservableObject` state manager — CRUD, batch logic, expiry scoring |
| `ScannerView.swift` | Camera scanner — AVFoundation barcode capture; expiry entered/confirmed by the user |
| `ContentView.swift` | Main tab navigation (Home / Scan / Kitchen) with glassmorphism nav bar |
| `HomeView.swift` | Dashboard with freshness score, expiring-soon list, quick actions |
| `PantryView.swift` | Inventory list / calendar toggle with add-item sheet |
| `CalendarGridView.swift` | Monthly grid with colored expiry dots and date-tap drill-down |
| `RecipesView.swift` | Batch cooking: recipes scored by 3+ expiring ingredients |
| `ShoppingListView.swift` | Checklist with add/delete/toggle |
| `CalendarManager.swift` | EventKit — adds all-day expiry events + 2-day-before alarms |
| `NotificationManager.swift` | UNUserNotificationCenter — 2-day-before local notifications |

## Frameworks Used

- **SwiftUI** — All UI
- **AVFoundation** — Barcode scanning (EAN-8/13, UPC-E, Code 128, QR, etc.)
- **EventKit** — Calendar sync with 2-day-before alarm
- **UserNotifications** — Local push alerts 2 days before expiry

> Live OCR of printed expiry dates (VisionKit) is a planned enhancement and is not yet wired into the scanner.

## Design System: "The Culinary Atelier"

Extracted from the provided HTML/CSS assets with full Material Design 3 tonal palette:

- **Primary:** `#006E1C` (deep green) / Container: `#4CAF50`
- **Tertiary:** `#A63360` (rose) / Container: `#F26F9D`
- **Error:** `#BA1A1A` / Container: `#FFDAD6`
- **Typography:** Manrope (headlines) + Inter (body/labels)
- **Surfaces:** Tonal nesting — no hard borders, ambient shadows only
- **Nav bar:** 32px top radius, glassmorphism (ultra-thin material)

## Requirements

- iOS 16.0+
- Xcode 15+
- Physical device recommended (camera scanner)

## Setup

```bash
# Option A: XcodeGen
brew install xcodegen
cd iOS_app
xcodegen generate
open FreshTrack.xcodeproj

# Option B: Create Xcode project manually
# 1. New Xcode project → iOS App → "FreshTrack"
# 2. Copy all App/*.swift files into the project
# 3. Build & run on simulator or device
```
