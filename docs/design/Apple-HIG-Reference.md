# Apple Human Interface Guidelines — iOS Reference

This document captures the exact Apple HIG specifications that QRStudio must follow.
Every value here is sourced from Apple's official documentation, WWDC sessions,
and system component inspection. When in doubt, match what Apple ships.

---

## Typography — Dynamic Type Scale

SF Pro is the system font. SF Pro Text is used at 19pt and below; SF Pro Display
at 20pt and above. The system handles this automatically.

### Default sizes at the "Large" content size category

| Text Style      | Size  | Weight    | Leading | Tracking |
|-----------------|-------|-----------|---------|----------|
| Large Title     | 34pt  | Regular   | 41pt    | 0.37     |
| Title 1         | 28pt  | Regular   | 34pt    | 0.36     |
| Title 2         | 22pt  | Regular   | 28pt    | 0.35     |
| Title 3         | 20pt  | Regular   | 24pt    | 0.38     |
| Headline        | 17pt  | Semibold  | 22pt    | -0.43    |
| Body            | 17pt  | Regular   | 22pt    | -0.43    |
| Callout         | 16pt  | Regular   | 21pt    | -0.32    |
| Subheadline     | 15pt  | Regular   | 20pt    | -0.24    |
| Footnote        | 13pt  | Regular   | 18pt    | -0.08    |
| Caption 1       | 12pt  | Regular   | 16pt    | 0.00     |
| Caption 2       | 11pt  | Regular   | 13pt    | 0.07     |

### Rules
- **NEVER** use `.font(.system(size:))` with fixed point sizes.
- **ALWAYS** use Dynamic Type text styles (`.largeTitle`, `.body`, etc.).
- Headline is the **only** style that defaults to semibold.
- Apply `.fontWeight()` modifiers when you need a different weight.
- Leading and tracking are applied automatically by the system font.
- All styles scale with the user's Dynamic Type accessibility setting.
- iOS 17 added `.extraLargeTitle` (36pt Bold) and `.extraLargeTitle2` (28pt Bold).

---

## Spacing & Layout

### Page margins (layoutMargins)

| Device Class                              | Horizontal Margin |
|-------------------------------------------|-------------------|
| Compact iPhones (375pt width — SE, 8)     | **16pt**          |
| Modern iPhones (390pt+ — 12/13/14/15/16)  | **20pt**          |
| iPad                                      | **20pt** + `readableContentGuide` |

### Grid system
- Apple does not officially mandate a grid, but **8pt** is the de facto standard.
- **4pt** half-unit for fine adjustments.
- Font sizes are NOT constrained to multiples of 8 (e.g., 17pt Body, 13pt Footnote).

### Standard spacing values (observed in system apps)
| Context                          | Value  |
|----------------------------------|--------|
| Sibling spacing (IB default)     | **8pt** |
| Superview-to-content (IB)        | **20pt** |
| Minimum row height               | **44pt** |
| Table section header top spacing  | ~35-38pt |
| Table section header bottom       | ~6-8pt |
| Minimum spacing between targets   | ~8pt |

---

## Touch Targets

**Minimum: 44 x 44 points** (based on ~7mm fingertip at 163 PPI).

- Every tappable element must have a minimum 44x44pt **hit region**.
- Controls can be **visually** smaller than 44pt if the tappable area is expanded.
- Use `.frame(minWidth: 44, minHeight: 44)` + `.contentShape(Rectangle())`.
- Minimum spacing between adjacent touch targets: **~8pt**.

---

## Corner Radii

Apple does NOT publish a formal radius table. Observed values:

| Component                    | Radius   | Notes                       |
|------------------------------|----------|-----------------------------|
| Text fields                  | ~5-6pt   | Subtle rounding             |
| Search bars                  | ~10pt    | Rounded rect                |
| Modal sheets (system)        | ~10pt    | `preferredCornerRadius`     |
| Alerts / Action sheets       | ~14pt    | Continuous curve             |
| Notification banners         | ~20-22pt | Matches device corner shape  |
| Segmented controls           | Capsule  | Half-height radius           |

### CRITICAL: Continuous corner curves (squircles)
Apple uses `CALayerCornerCurve.continuous`, NOT standard circular arcs.
In SwiftUI, always use:
```swift
RoundedRectangle(cornerRadius: value, style: .continuous)
```
This produces the distinctive Apple "squircle" shape. **Never** omit `style: .continuous`.

---

## Shadows

Apple **prefers materials and blur** over traditional drop shadows.

- Nav bars and tab bars use **hairline separators** (0.5pt at 2x), not shadows.
- Sheets use a subtle shadow combined with a dimming scrim.
- `CALayer` defaults: radius 3pt, offset (0, -3), opacity 0, color opaque black.

### Recommended values for custom cards (community convention)
```
shadowColor: black
shadowOpacity: 0.08 - 0.12
shadowOffset: (0, 2) to (0, 4)
shadowRadius: 8 - 16
```

Keep shadows **restrained**. Heavy shadows feel non-native.

---

## Animations

### iOS 17+ Spring System (WWDC23)

Springs are the **default** animation type. `withAnimation { }` = `.smooth`.

| Preset    | Duration | Bounce | Character                    |
|-----------|----------|--------|------------------------------|
| `.smooth` | 0.5s     | 0.0    | Gradual settle, no overshoot |
| `.snappy` | 0.5s     | ~0.15  | Quick settle, slight bounce  |
| `.bouncy` | 0.5s     | ~0.25  | Noticeable overshoot         |

### Legacy reference
- `CATransaction.animationDuration` default: **0.25s**
- Interactive spring: `response: 0.15, dampingFraction: 0.86`
- Legacy spring default: `response: 0.55, dampingFraction: 0.825`

### Rules
- **Prefer spring animations** over easeIn/easeOut. Springs feel more physical.
- Use `.smooth` for most transitions (default system behavior).
- Use `.snappy` for sheets, overlays, expansions.
- Use `.bouncy` sparingly for playful feedback (checkmarks, celebrations).
- Use `.interactiveSpring` for gesture-driven animations.

---

## Colors — Semantic System

**Always** use `Color(uiColor:)` semantic colors. They adapt automatically to:
- Light / Dark mode
- High Contrast accessibility
- Elevated trait collections (sheets in dark mode)

### Label colors

| Token             | Light                | Dark                |
|-------------------|----------------------|---------------------|
| `.label`          | #000000 (100%)       | #FFFFFF (100%)      |
| `.secondaryLabel` | #3C3C43 (60%)        | #EBEBF5 (60%)      |
| `.tertiaryLabel`  | #3C3C43 (30%)        | #EBEBF5 (30%)      |
| `.quaternaryLabel`| #3C3C43 (18%)        | #EBEBF5 (18%)      |

### Background colors

| Token                             | Light    | Dark     |
|-----------------------------------|----------|----------|
| `.systemBackground`               | #FFFFFF  | #000000  |
| `.secondarySystemBackground`      | #F2F2F7  | #1C1C1E  |
| `.tertiarySystemBackground`       | #FFFFFF  | #2C2C2E  |
| `.systemGroupedBackground`        | #F2F2F7  | #000000  |
| `.secondarySystemGroupedBackground`| #FFFFFF | #1C1C1E  |
| `.tertiarySystemGroupedBackground`| #F2F2F7  | #2C2C2E  |

### Fill colors

| Token                    | Light           | Dark            |
|--------------------------|-----------------|-----------------|
| `.systemFill`            | #787880 (20%)   | #787880 (36%)   |
| `.secondarySystemFill`   | #787880 (16%)   | #787880 (32%)   |
| `.tertiarySystemFill`    | #767680 (12%)   | #767680 (24%)   |
| `.quaternarySystemFill`  | #747480 (8%)    | #767680 (18%)   |

### Separator colors

| Token              | Light           | Dark            |
|--------------------|-----------------|-----------------|
| `.separator`       | #3C3C43 (29%)   | #545458 (60%)   |
| `.opaqueSeparator` | #C6C6C8         | #38383A         |

### System grays

| Token          | Light    | Dark     |
|----------------|----------|----------|
| `.systemGray`  | #8E8E93  | #8E8E93  |
| `.systemGray2` | #AEAEB2  | #636366  |
| `.systemGray3` | #C7C7CC  | #48484A  |
| `.systemGray4` | #D1D1D6  | #3A3A3C  |
| `.systemGray5` | #E5E5EA  | #2C2C2E  |
| `.systemGray6` | #F2F2F7  | #1C1C1E  |

Note: `.systemGray` is the same in both modes. Grays 2-6 invert luminance in dark mode.

---

## Native Components — Always Prefer System

| Need              | Use                                              | Never                           |
|-------------------|--------------------------------------------------|---------------------------------|
| Tab navigation    | `TabView` with `.tabItem { Label(...) }`          | Custom floating tab bars        |
| Bottom sheets     | `.sheet()` + `presentationDetents`                | Custom overlay sheets           |
| Navigation        | `NavigationStack` + `NavigationLink`               | Custom nav implementations      |
| Nav bar buttons   | `.toolbar { ToolbarItem(...) }`                    | Custom positioned buttons       |
| Nav bar titles    | `.navigationTitle()` + `.navigationBarTitleDisplayMode` | Manual title Text views    |
| Alerts            | `.alert()` modifier                                | Custom alert overlays           |
| Lists             | `List` or `LazyVStack`                             | Manual scroll + VStack          |
| Pull to refresh   | `.refreshable { }`                                 | Custom pull gestures            |
| Search            | `.searchable()`                                    | Custom search bars              |
| Swipe actions     | `.swipeActions { }`                                | Custom gesture recognizers      |

---

## Modern SwiftUI API (iOS 17+)

| Deprecated                | Use Instead                        |
|---------------------------|------------------------------------|
| `.foregroundColor()`      | `.foregroundStyle()`               |
| `.cornerRadius()`         | `.clipShape(RoundedRectangle(...))` |
| `PreviewProvider`         | `#Preview` macro                   |
| `NavigationView`          | `NavigationStack`                  |
| `.accentColor()`          | `.tint()`                          |
| `.onChange(of:perform:)`  | `.onChange(of:) { old, new in }`   |

---

## App Store Review — Common Rejection Reasons

1. **Minimum functionality** — app must do something useful beyond a basic wrapper.
2. **Broken links/buttons** — every UI element must function.
3. **Crash on launch** — test on real devices, not just simulator.
4. **Privacy** — declare all data collection in App Privacy.
5. **Metadata mismatch** — screenshots must match actual app.
6. **Guideline 4.0 (Design)** — must meet basic quality bar, use standard UI patterns.
7. **Performance** — no excessive battery/CPU usage.

---

---

## iOS 26 — Liquid Glass

iOS 26 introduces the most significant visual shift since iOS 7. Liquid Glass is a translucent material that reflects and refracts surroundings. **QRStudio must make deliberate decisions — not defaults — for every surface.**

### What Adopts Liquid Glass Automatically

Using standard SwiftUI components means these adopt Liquid Glass for free:
- `TabView` with `.tabItem` — tab bar becomes Liquid Glass
- `.navigationBar` — navigation chrome becomes Liquid Glass
- `.sheet` presented modally — sheet chrome adopts material
- `.toolbar` items

**This is why the tab bar and nav bar must use native components.** Custom implementations miss the update.

### QRStudio Liquid Glass Decisions

| Surface | Decision | Rationale |
|---------|----------|-----------|
| Tab bar | Native `TabView` + `.tabItem` — Liquid Glass automatic | Free, correct |
| Navigation bar | Native `NavigationStack` + `.navigationTitle` | Free, correct |
| Hero QR card | **Stays opaque white** — never apply Liquid Glass | QR code must be crisp and scannable. Translucency destroys scan reliability. White beacon card is the design. |
| Type selector pills | Opaque surface bg, no material | Clarity: selected/unselected must be unambiguous |
| Customization bar | `.ultraThinMaterial` background acceptable | Floating control bar over the QR card |
| Bottom sheet (color picker) | System `.sheet` — Liquid Glass automatic on iOS 26 | No custom material needed |
| Paywall sheet | System `.sheet` — Liquid Glass automatic | No custom material needed |
| Present Mode background | `Color.white` — hardcoded, never Liquid Glass | Scanning requires maximum contrast |

### Material Hierarchy (iOS 26)

| Material | Use |
|----------|-----|
| `.ultraThinMaterial` | Overlays that must reveal content beneath (customization bar floating over QR) |
| `.thinMaterial` | Secondary panels |
| `.regularMaterial` | Not needed — native sheets handle this |
| Opaque white | QR card always. Present Mode always. |

### Liquid Glass Anti-Patterns for QRStudio

- **Never** apply any material to the QR code card. The white card is the design.
- **Never** apply Liquid Glass to the QR image itself.
- **Never** use `.glassEffect()` on the paywall icon — use a solid gradient fill.
- **Do** let the tab bar and nav bar pick up Liquid Glass automatically via native components.

### iOS 26 API Notes

```swift
// New in iOS 26 — automatic adoption via native components
// TabView with .tabItem = Liquid Glass tab bar
// NavigationStack = Liquid Glass nav bar
// .sheet = Liquid Glass sheet chrome

// Explicit glass effect (use sparingly):
// .glassEffect() — apply only to floating controls, never to primary content
```

---

## Accessibility — VoiceOver

Apple checks VoiceOver in Design Award reviews. These are the requirements for QRStudio:

### QR Card
```swift
Image(uiImage: qrImage)
    .accessibilityLabel("QR code encoding \(encodedContent)")
    .accessibilityHint("Double-tap to share")
```
The QR image is otherwise an opaque black square to VoiceOver. The label must describe what it encodes.

### Scan Confidence Badge
```swift
Text("● Scans reliably")
    .accessibilityLabel("Scan confidence: high. This QR code scans reliably.")
```

### Type Selector Pills
```swift
Button { ... } label: { ... }
    .accessibilityLabel("\(type.label)\(type.isPro && !isPro ? ", Pro feature" : "")")
    .accessibilityHint(isSelected ? "Selected" : "Double-tap to switch to \(type.label) codes")
```

### Lock Badges
Lock badge images must have `.accessibilityHidden(true)` — the parent button's label already communicates "Pro feature."

### Present Mode
```swift
ZStack { ... }
    .accessibilityLabel("QR code encoding \(encodedContent), full screen presentation")
    .accessibilityHint("Tap anywhere to dismiss")
```

### Paywall Dismiss Button
```swift
Button { dismiss() } label: {
    Image(systemName: "xmark.circle.fill")
}
.accessibilityLabel("Dismiss")
```
Already in the current implementation — keep it.

### Rules
- Every interactive element needs an `accessibilityLabel` if the visual label isn't self-describing
- Images that are purely decorative get `.accessibilityHidden(true)`
- Never rely on color alone to convey state — icon + label always
- Test with VoiceOver on a real device before submitting

---

## Sources

- [Typography | Apple HIG](https://developer.apple.com/design/human-interface-guidelines/typography)
- [Layout | Apple HIG](https://developer.apple.com/design/human-interface-guidelines/layout)
- [Color | Apple HIG](https://developer.apple.com/design/human-interface-guidelines/color)
- [Accessibility | Apple HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Materials | Apple HIG](https://developer.apple.com/design/human-interface-guidelines/materials)
- [Animate with springs — WWDC23](https://developer.apple.com/videos/play/wwdc2023/10158/)
- [The details of UI typography — WWDC20](https://developer.apple.com/videos/play/wwdc2020/10175/)
- [iOS Font Sizes](https://www.iosfontsizes.com/)
