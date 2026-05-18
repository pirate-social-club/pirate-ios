# Pirate iOS — Agent Notes

## Project Structure

```
pirate/
├── pirateApp.swift                — App entry point, SessionManager DI
├── Models/
│   └── APIModels.swift            — Codable structs matching API contract (~800 lines)
├── Services/
│   ├── ApiClient.swift            — URLSession HTTP client with auth, all endpoint groups
│   ├── SessionManager.swift       — Observable session state coordinator
│   ├── SessionStore.swift         — Keychain persistence + JWT expiry checking
│   ├── SessionRefresher.swift     — Proactive token refresh 5min before expiry
│   └── AuthService.swift          — Privy SDK auth wrapper (conditional import)
├── Theme/
│   └── PirateTokens.swift         — Design tokens, colors, radii, typography
├── Navigation/
│   ├── PirateRoute.swift          — Route enum (24 routes) + tab definitions
│   ├── PirateScaffold.swift       — Tab bar shell
│   └── NavigationCoordinator.swift — NavigationStack + route destinations
├── Features/
│   ├── Auth/SignInDrawer.swift    — Auth bottom sheet (Google, X, Email OTP)
│   ├── Home/HomeView.swift        — Home feed (cursor pagination, sort controls)
│   ├── Community/CommunityView.swift — Community detail + posts
│   ├── Post/PostView.swift        — Post thread + comments + voting
│   ├── Profile/MeView.swift       — Own profile + settings link + sign out
│   ├── Profile/PublicProfileView.swift — Public profile by handle
│   ├── Notifications/NotificationsView.swift — Tasks + activity feed
│   ├── Settings/SettingsView.swift — Settings index + sections
│   ├── Wallet/WalletView.swift    — Wallet placeholder
│   ├── Chat/ChatPlaceholderView.swift — Chat placeholder (XMTP pending)
│   └── Onboarding/OnboardingView.swift — Onboarding placeholder
└── Shared/
    ├── AuthGate.swift             — Auth gating wrapper (shows sign-in sheet)
    └── Components/SharedComponents.swift — Reusable UI: PirateCard, AvatarView, VoteButton, etc.
```

## Build Commands

```bash
# Build for macOS (current dev machine)
xcodebuild -project pirate.xcodeproj -scheme pirate \
  -destination 'platform=macOS' \
  -allowProvisioningUpdates \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  build

# Build for iOS (requires iOS platform installed)
xcodebuild -project pirate.xcodeproj -scheme pirate \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build
```

## Privy SDK Integration

The Privy iOS SDK (`privy-io/privy-ios`, v2.x) is integrated conditionally:
- `AuthService.swift` uses `#if canImport(PrivySDK)` / `#else` guards
- On macOS builds (no iOS SDK), stub implementations are used
- To fully enable: open in Xcode → File → Add Package Dependencies → add `https://github.com/privy-io/privy-ios` (v2.0.0+)
- App ID: `cmnbdx9xk00ty0clapn2q8pdj`
- Client ID: `client-WY6Xkpp2wLef8Y9cWBrZ1GhnmqAtnVh9YisfZ2dA3c7DW`

## Architecture Patterns

- **SwiftUI** with `@Observable` (Swift Observation framework) — no Combine
- **No `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`** — removed for Privy SDK compatibility
- **Repository pattern** — `ApiClient` is the single API layer; views call `ApiClient.shared`
- **Session** — `SessionStore` (class, Keychain) → `SessionManager` (`@Observable`) → views
- **Auth gate** — `AuthGate` wrapper shows sign-in drawer for protected routes
- **Dark-only theme** — `PirateTokens.colors` provides semantic color tokens; `.pirateTheme()` modifier
- **Conditional platform** — `#if os(iOS)` guards for iOS-only APIs (textInputAutocapitalization, etc.)

## Design Tokens (matching Android/Web)

- Primary accent: `#D97757` (warm coral)
- Background: `#262624`, Surface: `#1B1B19`, Elevated: `#30302E`
- Accent color in asset catalog set to `rgb(217, 119, 87)`
- Border radius: 4/8/12/14/16/24/full(999) dp
- Typography: body always 16pt; use `PirateTokens.Typography` variants
- Buttons: pill-shaped (radius.full = 999pt)

## Info.plist / Entitlements

- `Info.plist`: URL scheme `pirate://` for OAuth callbacks, LSApplicationQueriesSchemes for Twitter/Google, NSAllowsArbitraryLoads for API access
- `pirate.entitlements`: network.client enabled for outgoing HTTP
- `ENABLE_APP_SANDBOX = NO` for development builds (re-enable for App Store)

## Deployment Targets

- iOS 17.0, macOS 14.0 (matching Privy SDK minimums)
- `SWIFT_VERSION = 5.0`
- `SWIFT_APPROACHABLE_CONCURRENCY = YES`
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`

## Key Rules

- Use semantic color tokens from `PirateTokens.colors`, not hardcoded hex
- Use `PirateTokens.Typography` fonts, not arbitrary sizes
- Access colors via `@Environment(\.pirateColors)` and radii via `@Environment(\.pirateRadii)`
- All API models use `Codable` with `CodingKeys` (snake_case ↔ camelCase)
- Views requiring auth must be wrapped in `AuthGate`
- App is dark-mode only (`.preferredColorScheme(.dark)`)
- Privy SDK features guarded with `#if canImport(PrivySDK)`