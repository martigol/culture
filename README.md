# CultureLens — iOS

A native SwiftUI app: scan a monument or artifact, read its story, and save it to your library.
This repo holds the **UI foundation**. All screens and flows work, backed by mock services, so each team can plug in its real feature behind a protocol.

**Requirements:** Xcode 16+ · iOS 17+ · no third-party dependencies.

```bash
open Culture.xcodeproj   # then ⌘R on any iPhone simulator
```

## User flow
`Home → Scan → Summary sheet → Story detail → Save to Library`

| Tab | Screen | File |
|---|---|---|
| Home | Hero, Scan orb, featured carousel | `Features/Home/HomeView.swift` |
| Discover | "For You" recommendations, themes | `Features/Discover/DiscoverView.swift` |
| Scan (modal) | Viewfinder, capture, result sheet | `Features/Scan/*` |
| Stories | Filter chips, search, save | `Features/Stories/StoriesView.swift` |
| Library | Saved / Offline / History / Collections | `Features/Library/LibraryView.swift` |
| — | Story detail + narration player | `Features/StoryDetail/StoryDetailView.swift` |

## Project structure
```
Culture/
├─ App/                 Entry point, root TabView, dependency container (AppEnvironment)
├─ Core/
│  ├─ Models/           Story, StoryCategory, Artwork, ScanRecord, StoryCollection
│  ├─ Services/         Protocols + mocks: StoryProviding, ScanRecognizing, AudioPlayer, MockData
│  ├─ Stores/           LibraryStore (@Observable app state)
│  ├─ Navigation/       AppTab, Route, Router (typed per-tab stacks)
│  └─ Security/         KeychainStore, AppConfig, Log, InputSanitizer, PrivacyShield
├─ DesignSystem/
│  ├─ Tokens/           Palette, Typography, Layout (Spacing / Radius / Motion)
│  └─ Components/       Cards, ScanInvite, Buttons, Chips, AudioPlayerCard, QuoteBlock, MeanderDivider…
├─ Features/<Feature>/  One folder per feature (View + ViewModel)
└─ Resources/           Assets, Fonts, PrivacyInfo.xcprivacy
Config/                 Shared.xcconfig, Info.plist (partial), Secrets.example.xcconfig
```
The project uses **folder-synchronised groups**, so any file you add under `Culture/` is picked up automatically. You don't need to edit the `.pbxproj`.

## Design system: "Engraving"
Bone ink on black, like a classical copperplate print (see `Resources/Assets.xcassets/Stories/hero-bust`).

- **Colour:** strictly monochrome. Use `Palette.background`/`surface`/`hairline` + the `ink` ramp; `accent` *is* bone. Don't add new hues. The app opts into dark mode in `CultureApp.swift`.
- **Imagery:** `ArtworkView` gives every photo an "aged print" look (muted natural colour, warm bone wash, faint engraving lines), so any image the backend sends matches the brand.
- **Motion:** `DesignSystem/Tokens/MotionKit.swift` has `.reveal(order:)` (staggered entrance), `.carouselCard()`, `.listRowEntrance()`, `.parallax()`, `.shimmer()` and `StoryLink` (card → story zoom transition on iOS 18+). All of them respect Reduce Motion. Keep motion to one authored moment per screen (Home hero) plus navigation transitions; don't add an entrance animation to every section.
- **Type:** **Zodiak** (classical serif) for titles, ledes and inscribed section titles only; **SF Pro** (system) for all reading text, labels and controls (HIG + legibility). No small "eyebrow" labels above headings; meta goes *below* titles. Use `.textStyle(.title)` and friends. They set font, tracking, leading and case together and scale with Dynamic Type. The full scale is documented in `DesignSystem/Tokens/Typography.swift`. Never call `Font.custom` in a feature.
- **Spacing (8-pt):** screen margin `Spacing.screen` = 24 · between sections `Spacing.section` = 56 · header→content `md` = 16 · within text groups `xs` = 8 · card image→text `sm` = 12. The rules live in `Layout.swift`.
- **Shape:** near-square corners (`Radius.xs`–`lg`, 2–10pt), hairline (0.5–0.75pt) rules instead of filled backgrounds, outlined thin (`.light`) SF Symbols.
- **HIG:** native TabView, NavigationStack, `.searchable` and sheets; 44-pt hit targets; VoiceOver labels; Reduce Motion; haptics.

## Plugging in real features
| Team | Replace | Where |
|---|---|---|
| Backend / content | `MockStoryService` → networked `StoryProviding` | `App/AppEnvironment.swift` |
| Scan / ML | `MockScanService` → Vision / CoreML; `ViewfinderBackground` → `AVCaptureSession` preview | `Core/Services/ScanService.swift`, `Features/Scan/ScanView.swift` |
| Audio | `AudioPlayer` → AVPlayer + Now Playing | `Core/Services/AudioPlayer.swift` |
| Imagery | Set `Artwork.imageURL` (remote), or add assets under `Resources/Assets.xcassets/Stories`. Sample photos are from Wikimedia Commons; see `docs/IMAGE_CREDITS.md` | `Core/Models/Story.swift` |
| New screen | Add a `Route` case and register it in `appDestinations()` | `Core/Navigation/Route.swift`, `App/RootView.swift` |

## QA launch arguments (Debug only)
Add these under Scheme ▸ Run ▸ Arguments to open the app on a specific screen: `-debugTab discover|stories|library`, `-debugStory <id>` (e.g. `parthenon`), `-debugScan YES`, `-debugScanResult <id>` (with `-debugScan YES`).

## Security baseline
- **Secrets:** never commit them. Copy `Config/Secrets.example.xcconfig` to `Config/Secrets.xcconfig`, which is git-ignored, and read values with `AppConfig`.
- **Network:** ATS stays strict (no arbitrary loads), and `AppConfig.apiBaseURL` rejects any URL that isn't HTTPS.
- **Tokens and credentials:** store them in `KeychainStore` (this-device-only, not backed up), never in `UserDefaults`.
- **Logging:** use `Log.*` (OSLog, private by default). Don't call `print` with user data.
- **Input:** run free text through `InputSanitizer.clean` before you query or send it.
- **App Switcher:** `PrivacyShield` blurs content when the app is inactive.
- **Privacy:** `PrivacyInfo.xcprivacy` is included, and camera and location usage strings are declared.

Fonts are licensed under the Fontshare Free License (`docs/font-licenses/FFL.txt`).
