# Design System (Theme) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the app's scattered hardcoded colors, font sizes, padding/spacing and corner radii with a central `Theme` token system, and migrate every existing call site to it — as groundwork for automatic dark mode and, later, a user-selectable accent color.

**Architecture:** One new file, `Core/Theme.swift`, exposing `Theme.Color` (semantic color roles resolved dynamically via `NSColor(name:dynamicProvider:)`, so they adapt to light/dark without `@Environment` plumbing), `Theme.Font` (named `CGFloat` point sizes), `Theme.Spacing` and `Theme.Radius` (named `CGFloat` scales). Every other file in this plan is migrated to consume these tokens instead of raw literals — colors first (Task 2, the existing `SessionKindStyle.swift` precedent), then feature by feature.

**Tech Stack:** SwiftUI / AppKit (macOS 26 SDK, macOS 14 deployment target), SwiftData. No third-party dependencies.

**Spec:** `docs/superpowers/specs/2026-08-27-design-system-design.md`

## Global Constraints

- **No automated test suite in this project** (standing decision). Every task's verification is: `xcodebuild -scheme "Xisto In Time" -configuration Release build` with **zero warnings**, plus a manual visual check (this environment has no screen capture — the executor confirms via the running app). This replaces the skill's default "write a failing test" step pattern with "implement → build clean → visually confirm unchanged in light mode → commit."
- **Light mode must look unchanged.** This is a refactor, not a redesign. A few color tokens are *derived by opacity* rather than kept as separate hex (documented per-task below) and land within ~1–8 RGB units of the original hex — visually indistinguishable, not byte-identical. Flag these explicitly when checking a task, don't just glance.
- **Dark mode is new** — there is no "before" to compare against. Nothing in this plan requires verifying dark mode per-task; Task 9 (final) is the one pass where the user checks it end to end.
- **Folding rule for spacing/radius values that aren't an exact `Theme.Spacing`/`Theme.Radius` value:** fold to a named tier only when the value is unambiguously closer to one tier than the other. A value exactly between two tiers, or a corner radius on an element under ~8pt tall (where the generic scale would visually distort a thin element), stays a local literal — not folded. Every task below states explicitly, per value, whether it folds or stays local; do not re-derive this while implementing.
- **Commits:** one commit per task, Portuguese message, following existing project convention (see `git log`).
- **Never write to the live SwiftData store to test this work** — every check in this plan is visual/build-only.
- **Fixed "conventional" system colors that stay literal, not migrated:** SwiftUI's named colors (`Color.red`, `.orange`, `.green`, `.white`, etc. — as opposed to `.primary`/`.secondary`/`.accentColor`, which *are* dynamic) do not adapt to light/dark on their own. Two call sites use one of these for a purpose where migrating it to a `Theme` token would be wrong, not just unnecessary, and are deliberately left as-is: `CalendarWeekView.swift`'s current-time red line (`Color.red` — a universal "live now" marker, reads fine in both appearances, not part of the neutral text/surface palette any `Theme.Color` role models) and `PomodoroDecisionView.swift`'s `DecisionButtonBody.foregroundStyle(prominent ? Color.white : tint)` (line 67 — white text sits on `tint`, itself a fixed, non-adaptive color per button; since the background never flips in dark mode, the text must stay a fixed white too — using a token that flips independently, like `chipActiveText`, would break contrast in dark mode instead of fixing it).

---

### Task 1: `Core/Theme.swift`

**Files:**
- Create: `Xisto In Time/Core/Theme.swift`

**Interfaces:**
- Produces: `Theme.Color.{accent, accentSubtle, surfacePrimary, surfaceHover, fillSubtle, divider, textMuted, textSecondary, textFaint, inkStrong, chipActiveBackground, chipActiveText, badgeTodayText, badgeTodayBackground, sessionWork, sessionWorkLight, sessionBreak, sessionBreakLight, sessionBreakText, sessionPlan, sessionPlanLight, sessionPlanText}` — all `SwiftUI.Color`.
- Produces: `Theme.Font.{micro, badge, caption, footnote, subheadline, body, callout, title3, statLarge, title2, largeTitle}` — all `CGFloat`.
- Produces: `Theme.Spacing.{xxs, xs, sm, md, base, lg, xl, xxl}` — all `CGFloat` (2, 4, 6, 8, 10, 12, 16, 22).
- Produces: `Theme.Radius.{sm, md, lg, xl}` — all `CGFloat` (4, 8, 12, 20).
- Consumes: `Color(hex:)` from `Core/ColorHex.swift` (already exists, unchanged).

- [ ] **Step 1: Create the file**

```swift
//
//  Theme.swift
//  Xisto In Time
//

import AppKit
import SwiftUI

/// App-wide design tokens — the single source of truth for color, type
/// size, spacing and corner radius. Colors are semantic roles (not raw hex
/// names), resolved dynamically against the current system appearance, so
/// every call site gets dark mode for free and, later, a swappable accent
/// color without touching call sites again.
enum Theme {
    enum Color {
        // MARK: Accent

        private static var accentHex: String {
            UserDefaults.standard.string(forKey: "themeAccentColorHex") ?? "007AFF"
        }

        /// The app's brand color. Reads a persisted preference that no UI
        /// writes yet — a future accent-color picker only needs to write
        /// that one key for this (and `sessionWork`, which mirrors it) to
        /// follow.
        static var accent: SwiftUI.Color { dynamic(light: accentHex, dark: "0A84FF") }

        /// Tinted background variant of `accent`, derived by opacity rather
        /// than a separate hex — inherits `accent`'s light/dark behavior
        /// automatically instead of needing its own dark value maintained
        /// by hand.
        static var accentSubtle: SwiftUI.Color { accent.opacity(0.12) }

        // MARK: Surfaces

        static var surfacePrimary: SwiftUI.Color { dynamic(light: "FFFFFF", dark: "1C1C1E") }
        static var surfaceHover: SwiftUI.Color { dynamic(light: "FAFAFC", dark: "242426") }
        static var fillSubtle: SwiftUI.Color { dynamic(light: "F1F1F4", dark: "2C2C2E") }
        static var divider: SwiftUI.Color { dynamic(light: "ECECF0", dark: "38383A") }

        // MARK: Text

        static var textMuted: SwiftUI.Color { dynamic(light: "8A8A90", dark: "98989F") }
        static var textSecondary: SwiftUI.Color { dynamic(light: "6A6A70", dark: "B4B4BA") }
        static var textFaint: SwiftUI.Color { dynamic(light: "C4C4C9", dark: "48484A") }
        static var inkStrong: SwiftUI.Color { dynamic(light: "2A2A2F", dark: "F0F0F2") }

        /// Active/selected filter-chip fill and its matching text — kept as
        /// their own pair (rather than reusing `inkStrong` for the
        /// background and `surfacePrimary`/white for the text separately)
        /// because `inkStrong` intentionally *flips* in dark mode (near-
        /// black → near-white); a text color picked to contrast in light
        /// mode would stop contrasting the moment the background flips.
        static var chipActiveBackground: SwiftUI.Color { inkStrong }
        static var chipActiveText: SwiftUI.Color { dynamic(light: "FFFFFF", dark: "1C1C1E") }

        // MARK: "Hoje" badge

        static var badgeTodayText: SwiftUI.Color { dynamic(light: "B05800", dark: "FFB454") }
        static var badgeTodayBackground: SwiftUI.Color { dynamic(light: "FFD6D6", dark: "4A2020") }

        // MARK: Session kinds

        static var sessionWork: SwiftUI.Color { accent }
        static var sessionWorkLight: SwiftUI.Color { sessionWork.opacity(0.12) }
        static var sessionBreak: SwiftUI.Color { dynamic(light: "A0A0A6", dark: "8E8E93") }
        static var sessionBreakLight: SwiftUI.Color { sessionBreak.opacity(0.15) }
        static var sessionBreakText: SwiftUI.Color { textSecondary }
        static var sessionPlan: SwiftUI.Color { dynamic(light: "E8A300", dark: "E8A300") }
        static var sessionPlanLight: SwiftUI.Color { sessionPlan.opacity(0.13) }
        static var sessionPlanText: SwiftUI.Color { dynamic(light: "A87000", dark: "D4A64C") }

        /// Resolves against the current effective appearance at render
        /// time — works anywhere a `Color` is used, including outside a
        /// `View` body (unlike `@Environment(\.colorScheme)`, which only
        /// resolves inside one).
        private static func dynamic(light: String, dark: String) -> SwiftUI.Color {
            SwiftUI.Color(nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                return NSColor(SwiftUI.Color(hex: isDark ? dark : light))
            })
        }
    }

    enum Font {
        static let micro: CGFloat = 9
        static let badge: CGFloat = 10
        static let caption: CGFloat = 11.5
        static let footnote: CGFloat = 12.5
        static let subheadline: CGFloat = 13
        static let body: CGFloat = 14
        static let callout: CGFloat = 15
        static let title3: CGFloat = 19
        static let statLarge: CGFloat = 20
        static let title2: CGFloat = 30
        static let largeTitle: CGFloat = 34
    }

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let base: CGFloat = 10
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 22
    }

    enum Radius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 20
    }
}
```

- [ ] **Step 2: Build to verify it compiles standalone**

Run: `xcodebuild -scheme "Xisto In Time" -configuration Release build`
Expected: `** BUILD SUCCEEDED **`, zero warnings. Nothing else in the app references `Theme` yet, so this only proves the file itself is valid.

- [ ] **Step 3: Commit**

```bash
git add "Xisto In Time/Core/Theme.swift"
git commit -m "$(cat <<'EOF'
feat: Core/Theme.swift — tokens de cor, tipografia, espaçamento e raio

Base do design system: papéis de cor semânticos resolvidos
dinamicamente (claro/escuro), escalas nomeadas de tamanho de fonte,
espaçamento e raio. Ainda não é consumido em lado nenhum.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `Core/SessionKindStyle.swift`

**Files:**
- Modify: `Xisto In Time/Core/SessionKindStyle.swift` (full file, 45 lines)

**Interfaces:**
- Consumes: `Theme.Color.{sessionWork, sessionWorkLight, sessionBreak, sessionBreakLight, sessionBreakText, sessionPlan, sessionPlanLight, sessionPlanText}` (Task 1).
- Produces: unchanged public surface (`SessionKind.label/color/lightColor/chipTextColor`) — every caller elsewhere in the app (Calendar, Sessões list) needs zero changes from this task alone.

- [ ] **Step 1: Replace the three color-returning computed properties**

Old:
```swift
    var color: Color {
        switch self {
        case .work: Color(hex: "007AFF")
        case .break: Color(hex: "A0A0A6")
        case .plan: Color(hex: "E8A300")
        }
    }

    var lightColor: Color {
        switch self {
        case .work: Color(hex: "DFEEFF")
        case .break: Color(hex: "EEEEF1")
        case .plan: Color(hex: "FFF4D6")
        }
    }

    var chipTextColor: Color {
        switch self {
        case .work: color
        case .break: Color(hex: "71717A")
        case .plan: Color(hex: "A87000")
        }
    }
```

New:
```swift
    var color: Color {
        switch self {
        case .work: Theme.Color.sessionWork
        case .break: Theme.Color.sessionBreak
        case .plan: Theme.Color.sessionPlan
        }
    }

    var lightColor: Color {
        switch self {
        case .work: Theme.Color.sessionWorkLight
        case .break: Theme.Color.sessionBreakLight
        case .plan: Theme.Color.sessionPlanLight
        }
    }

    var chipTextColor: Color {
        switch self {
        case .work: color
        case .break: Theme.Color.sessionBreakText
        case .plan: Theme.Color.sessionPlanText
        }
    }
```

The `label` property and file header comment are unchanged.

- [ ] **Step 2: Build**

Run: `xcodebuild -scheme "Xisto In Time" -configuration Release build`
Expected: `** BUILD SUCCEEDED **`, zero warnings.

- [ ] **Step 3: Visual check**

Open the app (Calendário and Sessões, which both already consume `SessionKind.color`/`lightColor`/`chipTextColor` today). Confirm:
- Work/Trabalho blocks and chips still read as the same blue.
- Break/Pausa still the same medium gray.
- Plan/Plano still the same amber/yellow, both the full-strength block fill and the lighter chip background — these two are the ones derived by opacity now (`sessionWorkLight`, `sessionBreakLight`, `sessionPlanLight`); expect a visually-identical but not byte-identical tint.
- The Pausa type-chip's text color (`chipTextColor` → `sessionBreakText` → `textSecondary`) is a touch lighter than before (was `71717A`, now `6A6A70`-based) — confirm it's still clearly legible on the light chip background, not just "close enough."

- [ ] **Step 4: Commit**

```bash
git add "Xisto In Time/Core/SessionKindStyle.swift"
git commit -m "$(cat <<'EOF'
refactor: SessionKindStyle delega em Theme.Color

Xisto In Time/Core/SessionKindStyle.swift agora só compõe papéis
de Theme.Color em vez de hex próprios — ganha modo escuro sem
alterar nenhum dos chamadores (Calendário, Sessões).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Calendário — raio de canto

**Files:**
- Modify: `Xisto In Time/UI/CalendarSessionBlock.swift:72,75`
- Modify: `Xisto In Time/UI/CalendarRunningBlock.swift:37,40`
- Modify: `Xisto In Time/UI/CalendarWeekView.swift:350,353`

**Interfaces:**
- Consumes: `Theme.Radius.sm` (Task 1).
- Note: `CalendarSessionBlock`'s `fillColor`/`borderColor` already call `SessionKind.break.color`/`.plan.color`, which became theme-derived in Task 2 with zero changes needed here — this task only touches the one remaining literal in these three files, the `cornerRadius: 4` used for every session/ghost/running block.

- [ ] **Step 1: `CalendarSessionBlock.swift` — replace both `cornerRadius: 4`**

Old (line 72 and 75):
```swift
        RoundedRectangle(cornerRadius: 4)
            .fill(fillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
```

New:
```swift
        RoundedRectangle(cornerRadius: Theme.Radius.sm)
            .fill(fillColor)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
```

- [ ] **Step 2: `CalendarRunningBlock.swift` — replace both `cornerRadius: 4`**

Old (line 37 and 40):
```swift
        RoundedRectangle(cornerRadius: 4)
            .fill(kind == .break ? SessionKind.break.color.opacity(0.35) : (projectColor ?? .accentColor).opacity(0.35))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
```

New:
```swift
        RoundedRectangle(cornerRadius: Theme.Radius.sm)
            .fill(kind == .break ? SessionKind.break.color.opacity(0.35) : (projectColor ?? .accentColor).opacity(0.35))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
```

- [ ] **Step 3: `CalendarWeekView.swift` — replace both `cornerRadius: 4` in `creationGhost(for:)`**

Old (line 350 and 353):
```swift
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.accentColor.opacity(0.25))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
```

New:
```swift
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(Color.accentColor.opacity(0.25))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
```

`Theme.Radius.sm` is exactly `4` — this step changes nothing visually, it only names the value.

- [ ] **Step 4: Build**

Run: `xcodebuild -scheme "Xisto In Time" -configuration Release build`
Expected: `** BUILD SUCCEEDED **`, zero warnings.

- [ ] **Step 5: Visual check**

Open the Calendário tab. Confirm session blocks, the running block, and a click/drag creation ghost all still have the same subtly-rounded corners as before (this step is a pure rename — should be pixel-identical, not just close).

- [ ] **Step 6: Commit**

```bash
git add "Xisto In Time/UI/CalendarSessionBlock.swift" "Xisto In Time/UI/CalendarRunningBlock.swift" "Xisto In Time/UI/CalendarWeekView.swift"
git commit -m "$(cat <<'EOF'
refactor: raio dos blocos do calendário usa Theme.Radius.sm

Sem alteração visual — só nomeia o cornerRadius: 4 já usado em
CalendarSessionBlock/CalendarRunningBlock/CalendarWeekView.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: `Xisto In Time/UI/SessionDayHeader.swift`

**Files:**
- Modify: `Xisto In Time/UI/SessionDayHeader.swift` (full file, 57 lines)

**Interfaces:**
- Consumes: `Theme.Font.{footnote, badge, caption}`, `Theme.Color.{badgeTodayText, badgeTodayBackground, divider, textMuted}`, `Theme.Spacing.{xxs, base}`, `Theme.Radius.sm` (Task 1).

- [ ] **Step 1: Replace the `body`**

Old:
```swift
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(Self.dayTitle(for: group.day))
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(.primary)
            if isToday {
                Text("HOJE")
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(Color(hex: "B05800"))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color(hex: "FFD6D6"), in: RoundedRectangle(cornerRadius: 5))
            }
            Rectangle()
                .fill(Color(hex: "ECECF0"))
                .frame(height: 1)
            Text("\(group.sessions.count) \(group.sessions.count == 1 ? "sessão" : "sessões") · \(TimerEngine.format(group.total))")
                .font(.system(size: 11.5))
                .foregroundStyle(Color(hex: "9A9AA0"))
                .monospacedDigit()
        }
        .textCase(nil)
        .padding(.top, 9)
        .padding(.bottom, 7)
        .padding(.horizontal, 2)
    }
```

New:
```swift
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(Self.dayTitle(for: group.day))
                .font(.system(size: Theme.Font.footnote, weight: .bold))
                .foregroundStyle(.primary)
            if isToday {
                Text("HOJE")
                    .font(.system(size: Theme.Font.badge, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(Theme.Color.badgeTodayText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, Theme.Spacing.xxs)
                    .background(Theme.Color.badgeTodayBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
            }
            Rectangle()
                .fill(Theme.Color.divider)
                .frame(height: 1)
            Text("\(group.sessions.count) \(group.sessions.count == 1 ? "sessão" : "sessões") · \(TimerEngine.format(group.total))")
                .font(.system(size: Theme.Font.caption))
                .foregroundStyle(Theme.Color.textMuted)
                .monospacedDigit()
        }
        .textCase(nil)
        .padding(.top, Theme.Spacing.base)
        .padding(.bottom, 7)
        .padding(.horizontal, 2)
    }
```

`.padding(.horizontal, 7)` (HOJE badge) and `.padding(.bottom, 7)`/`.padding(.horizontal, 2)` (outer) stay local literals — `7` sits exactly between `Theme.Spacing.sm`(6) and `.md`(8), `2` here is the outer horizontal inset (not the `xxs` badge padding above it), both are genuine ties/one-offs per the folding rule, not folded.

- [ ] **Step 2: Build**

Run: `xcodebuild -scheme "Xisto In Time" -configuration Release build`
Expected: `** BUILD SUCCEEDED **`, zero warnings.

- [ ] **Step 3: Visual check**

Open Sessões (the only screen currently passing `isToday: true`). Confirm: the day title, the "HOJE" badge (orange text on pink background, same size), the thin divider line, and the "N sessões · total" trailing text all look the same as before.

- [ ] **Step 4: Commit**

```bash
git add "Xisto In Time/UI/SessionDayHeader.swift"
git commit -m "$(cat <<'EOF'
refactor: SessionDayHeader usa tokens de Theme

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: `Xisto In Time/UI/SessionListRow.swift`

**Files:**
- Modify: `Xisto In Time/UI/SessionListRow.swift` (full file, 215 lines)

**Interfaces:**
- Consumes: `Theme.Font.{micro, badge, caption, footnote, subheadline, body}`, `Theme.Color.{surfaceHover, surfacePrimary, fillSubtle, textMuted, textSecondary, inkStrong, accent, accentSubtle, textFaint}`, `Theme.Spacing.{xs, sm, md, xxs, base}`, `Theme.Radius.md` (Task 1).

- [ ] **Step 1: Row background/divider (lines 50–53)**

Old:
```swift
        .background(isSelected ? Color.accentColor.opacity(0.05) : (isHovered ? Color(hex: "FAFAFC") : Color.white))
        .overlay(alignment: .top) {
            if !isFirstInGroup {
                Rectangle().fill(Color(hex: "F0F0F3")).frame(height: 1)
            }
        }
```

New:
```swift
        .background(isSelected ? Color.accentColor.opacity(0.05) : (isHovered ? Theme.Color.surfaceHover : Theme.Color.surfacePrimary))
        .overlay(alignment: .top) {
            if !isFirstInGroup {
                Rectangle().fill(Theme.Color.fillSubtle).frame(height: 1)
            }
        }
```

`Color.accentColor` here is the system accent (row-selection tint) — left unchanged per spec, it's already adaptive and distinct from `Theme.Color.accent`.

- [ ] **Step 2: `textColumn` (lines 88–133)**

Old:
```swift
    private var textColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(session.task?.externalRef ?? "—")
                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(hex: "8A8A90"))
                Text(session.task?.title ?? "Sem atribuição")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                if session.kind != .work {
                    Text(session.kind.label.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.4)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(session.kind.lightColor, in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(session.kind.chipTextColor)
                        .fixedSize()
                }
            }

            HStack(spacing: 8) {
                if let project = session.task?.project {
                    Text(project.name)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Color(hex: "6A6A70"))
                    Text("·").foregroundStyle(Color(hex: "8A8A90").opacity(0.5))
                }
                Text("\(session.startedAt.formatted(date: .omitted, time: .shortened)) – \(session.endedAt.formatted(date: .omitted, time: .shortened))")
                    .monospacedDigit()
                if let note = session.note, !note.isEmpty {
                    Text("·").foregroundStyle(Color(hex: "8A8A90").opacity(0.5))
                    Text(note)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 380, alignment: .leading)
                }
            }
            .font(.system(size: 11.5))
            .foregroundStyle(Color(hex: "8A8A90"))

            timeline
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }
```

New:
```swift
    private var textColumn: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.md) {
                Text(session.task?.externalRef ?? "—")
                    .font(.system(size: Theme.Font.caption, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.Color.textMuted)
                Text(session.task?.title ?? "Sem atribuição")
                    .font(.system(size: Theme.Font.body, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                if session.kind != .work {
                    Text(session.kind.label.uppercased())
                        .font(.system(size: Theme.Font.badge, weight: .bold))
                        .tracking(0.4)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xxs)
                        .background(session.kind.lightColor, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
                        .foregroundStyle(session.kind.chipTextColor)
                        .fixedSize()
                }
            }

            HStack(spacing: Theme.Spacing.md) {
                if let project = session.task?.project {
                    Text(project.name)
                        .font(.system(size: Theme.Font.caption, weight: .medium))
                        .foregroundStyle(Theme.Color.textSecondary)
                    Text("·").foregroundStyle(Theme.Color.textMuted.opacity(0.5))
                }
                Text("\(session.startedAt.formatted(date: .omitted, time: .shortened)) – \(session.endedAt.formatted(date: .omitted, time: .shortened))")
                    .monospacedDigit()
                if let note = session.note, !note.isEmpty {
                    Text("·").foregroundStyle(Theme.Color.textMuted.opacity(0.5))
                    Text(note)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 380, alignment: .leading)
                }
            }
            .font(.system(size: Theme.Font.caption))
            .foregroundStyle(Theme.Color.textMuted)

            timeline
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }
```

Note: `.padding(.horizontal, 6)` folded to `Theme.Spacing.sm` — `6` is an exact match, not a judgment call.

- [ ] **Step 3: `timeline` (lines 137–159) — only the track background color**

Old (lines 148–149):
```swift
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "F0F0F3"))
```

New:
```swift
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.Color.fillSubtle)
```

`cornerRadius: 2` stays a local literal — the track is 3pt tall (`.frame(height: 3)` two lines below), and `Theme.Radius.sm` (4) would look chunky relative to it; this is the "thin element" proportional exception from the folding rule.

- [ ] **Step 4: `durationText` (lines 161–166)**

Old:
```swift
    private var durationText: some View {
        Text(TimerEngine.format(duration))
            .font(.system(size: 13.5, design: .monospaced))
            .foregroundStyle(session.kind == .break ? Color(hex: "9A9AA0") : Color(hex: "2A2A2F"))
            .frame(width: 84, alignment: .trailing)
    }
```

New:
```swift
    private var durationText: some View {
        Text(TimerEngine.format(duration))
            .font(.system(size: Theme.Font.subheadline, design: .monospaced))
            .foregroundStyle(session.kind == .break ? Theme.Color.textMuted : Theme.Color.inkStrong)
            .frame(width: 84, alignment: .trailing)
    }
```

- [ ] **Step 5: `actions` (lines 168–207)**

Old:
```swift
    private var actions: some View {
        HStack(spacing: 6) {
            Button {
                startFreeSession()
            } label: {
                HStack(spacing: 5) {
                    Text("▶").font(.system(size: 9))
                    Text(isRunningThisTask ? "A correr" : "Começar")
                        .font(.system(size: 12.5, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
            .buttonStyle(.plain)
            .background(Color(hex: "EAF3FF"), in: RoundedRectangle(cornerRadius: 7))
            .foregroundStyle(Color(hex: "007AFF"))
            .disabled(isRunningThisTask)

            Menu {
                Button("Apagar sessão", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Color(hex: "8A8A90"))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 26, height: 26)

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "C4C4C9"))
                .onTapGesture {
                    path.wrappedValue.append(SessionRoute(id: session.persistentModelID))
                }
        }
        .frame(width: 150, alignment: .trailing)
        .opacity(isHighlighted ? 1 : 0)
        .allowsHitTesting(isHighlighted)
    }
```

New:
```swift
    private var actions: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button {
                startFreeSession()
            } label: {
                HStack(spacing: 5) {
                    Text("▶").font(.system(size: Theme.Font.micro))
                    Text(isRunningThisTask ? "A correr" : "Começar")
                        .font(.system(size: Theme.Font.footnote, weight: .semibold))
                }
                .padding(.horizontal, Theme.Spacing.base)
                .padding(.vertical, 5)
            }
            .buttonStyle(.plain)
            .background(Theme.Color.accentSubtle, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .foregroundStyle(Theme.Color.accent)
            .disabled(isRunningThisTask)

            Menu {
                Button("Apagar sessão", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Theme.Color.textMuted)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 26, height: 26)

            Image(systemName: "chevron.right")
                .font(.system(size: Theme.Font.footnote))
                .foregroundStyle(Theme.Color.textFaint)
                .onTapGesture {
                    path.wrappedValue.append(SessionRoute(id: session.persistentModelID))
                }
        }
        .frame(width: 150, alignment: .trailing)
        .opacity(isHighlighted ? 1 : 0)
        .allowsHitTesting(isHighlighted)
    }
```

Note: `.font(.system(size: 12))` for the chevron folds to `Theme.Font.footnote` (12.5) per the spec's font table, which explicitly lists `12` as one of `footnote`'s substituted sizes.

- [ ] **Step 6: Build**

Run: `xcodebuild -scheme "Xisto In Time" -configuration Release build`
Expected: `** BUILD SUCCEEDED **`, zero warnings.

- [ ] **Step 7: Visual check**

Open Sessões. Confirm every row still looks the same: external-ref code, task title, type chip (Pausa/Plano only), project name, time range, note, the mini-timeline track and its colored bar, the duration on the right, and — on hover — the "Começar" pill (light blue background, blue text), the "…" menu, and the chevron. The "Começar" pill's background is one of the opacity-derived tints (`accentSubtle`) — expect it visually identical to before, not necessarily byte-identical.

- [ ] **Step 8: Commit**

```bash
git add "Xisto In Time/UI/SessionListRow.swift"
git commit -m "$(cat <<'EOF'
refactor: SessionListRow usa tokens de Theme

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: `Xisto In Time/UI/AllSessionsView.swift`

**Files:**
- Modify: `Xisto In Time/UI/AllSessionsView.swift` (full file, 302 lines)

**Interfaces:**
- Consumes: `Theme.Font.{title3, subheadline, callout, footnote, caption, statLarge, body}`, `Theme.Color.{divider, surfacePrimary, textMuted, fillSubtle, accent, chipActiveBackground, chipActiveText, textSecondary}`, `Theme.Spacing.{md, lg, xl, xxl}`, `Theme.Radius.md` (Task 1).

- [ ] **Step 1: `body` — dividers and page background (lines 104–140)**

Old (relevant lines):
```swift
            toolbar
            Divider().foregroundStyle(Color(hex: "ECECF0"))
            summaryBar
            Divider().foregroundStyle(Color(hex: "ECECF0"))
            filterChips
```
```swift
                    .padding(.horizontal, 22)
                    .padding(.bottom, 28)
                }
            }
        }
        .background(Color.white)
```

New:
```swift
            toolbar
            Divider().foregroundStyle(Theme.Color.divider)
            summaryBar
            Divider().foregroundStyle(Theme.Color.divider)
            filterChips
```
```swift
                    .padding(.horizontal, Theme.Spacing.xxl)
                    .padding(.bottom, 28)
                }
            }
        }
        .background(Theme.Color.surfacePrimary)
```

`.padding(.bottom, 28)` stays local — an explicitly-named outlier in the spec.

- [ ] **Step 2: `toolbar` (lines 144–182)**

Old:
```swift
    private var toolbar: some View {
        HStack(spacing: 14) {
            Text("Sessões")
                .font(.system(size: 19, weight: .bold))

            Spacer()

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "9A9AA0"))
                TextField("Pesquisar tarefa, código ou projecto", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(width: 268)
            .background(Color(hex: "F1F1F4"), in: RoundedRectangle(cornerRadius: 8))

            Button {
                showingNewSessionEditor = true
            } label: {
                HStack(spacing: 6) {
                    Text("+").font(.system(size: 15))
                    Text("Nova sessão").font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
            }
            .buttonStyle(.plain)
            .background(Color(hex: "007AFF"), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)
            .help("Criar uma sessão passada, com início e fim escolhidos à mão")
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }
```

New:
```swift
    private var toolbar: some View {
        HStack(spacing: 14) {
            Text("Sessões")
                .font(.system(size: Theme.Font.title3, weight: .bold))

            Spacer()

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: Theme.Font.subheadline))
                    .foregroundStyle(Theme.Color.textMuted)
                TextField("Pesquisar tarefa, código ou projecto", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: Theme.Font.subheadline))
            }
            .padding(.horizontal, Theme.Spacing.base)
            .padding(.vertical, Theme.Spacing.sm)
            .frame(width: 268)
            .background(Theme.Color.fillSubtle, in: RoundedRectangle(cornerRadius: Theme.Radius.md))

            Button {
                showingNewSessionEditor = true
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Text("+").font(.system(size: Theme.Font.callout))
                    Text("Nova sessão").font(.system(size: Theme.Font.subheadline, weight: .semibold))
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, 7)
            }
            .buttonStyle(.plain)
            .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .foregroundStyle(.white)
            .help("Criar uma sessão passada, com início e fim escolhidos à mão")
        }
        .padding(.horizontal, Theme.Spacing.xxl)
        .padding(.top, Theme.Spacing.xl)
        .padding(.bottom, 14)
    }
```

Note: `.padding(.horizontal, 13)` (the "Nova sessão" button) folds to `Theme.Spacing.lg` (12) — `13` is unambiguously closer to `12` than to `16`. `.padding(.vertical, 7)` (search field and button) stays local (tie).

- [ ] **Step 3: `summaryBar` / `metric(label:color:total:)` (lines 186–230)**

Old:
```swift
    private var summaryBar: some View {
        HStack(alignment: .center, spacing: 26) {
            Picker("", selection: $scope) {
                ForEach(SummaryScope.allCases) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 170)

            metric(label: "Trabalho", color: SessionKind.work.color, total: metricTotal(for: .work))
            metric(label: "Planeado", color: SessionKind.plan.color, total: metricTotal(for: .plan))
            metric(label: "Pausas", color: SessionKind.break.color, total: metricTotal(for: .break))

            Spacer()

            let worked = metricTotal(for: .work)
            let planned = metricTotal(for: .plan)
            VStack(alignment: .trailing, spacing: 2) {
                Text(scope == .today ? "Registado hoje vs. planeado" : "Registado esta semana")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color(hex: "7C7C82"))
                Text("\(ReportBuilder.formatHoursMinutes(worked)) de \(ReportBuilder.formatHoursMinutes(worked + planned))")
                    .font(.system(size: 13, weight: .semibold))
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    private func metric(label: String, color: Color, total: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(label)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color(hex: "7C7C82"))
            }
            Text(TimerEngine.format(total))
                .font(.system(size: 20, design: .monospaced))
                .tracking(-0.5)
        }
        .frame(minWidth: 116, alignment: .leading)
    }
```

New:
```swift
    private var summaryBar: some View {
        HStack(alignment: .center, spacing: 26) {
            Picker("", selection: $scope) {
                ForEach(SummaryScope.allCases) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 170)

            metric(label: "Trabalho", color: SessionKind.work.color, total: metricTotal(for: .work))
            metric(label: "Planeado", color: SessionKind.plan.color, total: metricTotal(for: .plan))
            metric(label: "Pausas", color: SessionKind.break.color, total: metricTotal(for: .break))

            Spacer()

            let worked = metricTotal(for: .work)
            let planned = metricTotal(for: .plan)
            VStack(alignment: .trailing, spacing: 2) {
                Text(scope == .today ? "Registado hoje vs. planeado" : "Registado esta semana")
                    .font(.system(size: Theme.Font.caption))
                    .foregroundStyle(Theme.Color.textMuted)
                Text("\(ReportBuilder.formatHoursMinutes(worked)) de \(ReportBuilder.formatHoursMinutes(worked + planned))")
                    .font(.system(size: Theme.Font.subheadline, weight: .semibold))
            }
        }
        .padding(.horizontal, Theme.Spacing.xxl)
        .padding(.vertical, 14)
    }

    private func metric(label: String, color: Color, total: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: Theme.Spacing.sm) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(label)
                    .font(.system(size: Theme.Font.caption, weight: .medium))
                    .foregroundStyle(Theme.Color.textMuted)
            }
            Text(TimerEngine.format(total))
                .font(.system(size: Theme.Font.statLarge, design: .monospaced))
                .tracking(-0.5)
        }
        .frame(minWidth: 116, alignment: .leading)
    }
```

Note: `Color(hex: "7C7C82")` (both occurrences) consolidates into `Theme.Color.textMuted` alongside `8A8A90`/`9A9AA0`, per the spec's color table — expect a few RGB units of drift, same caveat as Task 2.

- [ ] **Step 4: `filterChips` / `chip(for:)` (lines 234–269)**

Old:
```swift
    private var filterChips: some View {
        HStack(spacing: 8) {
            ForEach(SessionKindFilter.allCases) { filter in
                chip(for: filter)
            }
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
    }

    private func chip(for filter: SessionKindFilter) -> some View {
        let isActive = kindFilter == filter
        return Button {
            kindFilter = filter
        } label: {
            HStack(spacing: 7) {
                if let kind = filter.sessionKind {
                    Circle().fill(kind.color).frame(width: 7, height: 7)
                }
                Text(filter.label)
                Text("\(count(for: filter))")
                    .opacity(0.55)
                    .monospacedDigit()
            }
            .font(.system(size: 12.5, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .background(isActive ? Color(hex: "1C1C1E") : Color(hex: "F4F4F7"), in: Capsule())
        .foregroundStyle(isActive ? Color.white : Color(hex: "5A5A60"))
        .overlay(
            Capsule().stroke(isActive ? Color.clear : Color(hex: "E9E9EE"), lineWidth: 1)
        )
    }
```

New:
```swift
    private var filterChips: some View {
        HStack(spacing: Theme.Spacing.md) {
            ForEach(SessionKindFilter.allCases) { filter in
                chip(for: filter)
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.xxl)
        .padding(.vertical, Theme.Spacing.lg)
    }

    private func chip(for filter: SessionKindFilter) -> some View {
        let isActive = kindFilter == filter
        return Button {
            kindFilter = filter
        } label: {
            HStack(spacing: 7) {
                if let kind = filter.sessionKind {
                    Circle().fill(kind.color).frame(width: 7, height: 7)
                }
                Text(filter.label)
                Text("\(count(for: filter))")
                    .opacity(0.55)
                    .monospacedDigit()
            }
            .font(.system(size: Theme.Font.footnote, weight: .semibold))
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .background(isActive ? Theme.Color.chipActiveBackground : Theme.Color.fillSubtle, in: Capsule())
        .foregroundStyle(isActive ? Theme.Color.chipActiveText : Theme.Color.textSecondary)
        .overlay(
            Capsule().stroke(isActive ? Color.clear : Theme.Color.divider, lineWidth: 1)
        )
    }
```

- [ ] **Step 5: `dayBlock(for:)` and `emptyState` (lines 273–301)**

Old:
```swift
    private func dayBlock(for group: DaySessionGroup) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(group.sessions.enumerated()), id: \.element.persistentModelID) { index, session in
                SessionListRow(
                    session: session,
                    isFirstInGroup: index == 0,
                    isSelected: selectedSessionID == session.persistentModelID,
                    path: path,
                    onSelect: { selectedSessionID = session.persistentModelID }
                )
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "E7E7EB"), lineWidth: 1))
    }

    private var emptyState: some View {
        VStack(spacing: 5) {
            Text("Sem sessões para este filtro")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: "6A6A70"))
            Text("Ajusta a pesquisa ou escolhe \u{201C}Todos\u{201D}.")
                .font(.system(size: 12.5))
                .foregroundStyle(Color(hex: "9A9AA0"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
    }
```

New:
```swift
    private func dayBlock(for group: DaySessionGroup) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(group.sessions.enumerated()), id: \.element.persistentModelID) { index, session in
                SessionListRow(
                    session: session,
                    isFirstInGroup: index == 0,
                    isSelected: selectedSessionID == session.persistentModelID,
                    path: path,
                    onSelect: { selectedSessionID = session.persistentModelID }
                )
            }
        }
        .background(Theme.Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Color.divider, lineWidth: 1))
    }

    private var emptyState: some View {
        VStack(spacing: 5) {
            Text("Sem sessões para este filtro")
                .font(.system(size: Theme.Font.body, weight: .semibold))
                .foregroundStyle(Theme.Color.textSecondary)
            Text("Ajusta a pesquisa ou escolhe \u{201C}Todos\u{201D}.")
                .font(.system(size: Theme.Font.footnote))
                .foregroundStyle(Theme.Color.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
    }
```

`cornerRadius: 10` (both occurrences) and `.padding(.vertical, 70)` stay local — `10` is an exact tie between `Theme.Radius.md`(8) and `.lg`(12), `70` is the spec's explicitly-named outlier.

- [ ] **Step 6: `dayGroups` `LazyVStack` spacing and its outer padding (line 117, 127)**

Old:
```swift
                    LazyVStack(alignment: .leading, spacing: 18, pinnedViews: [.sectionHeaders]) {
```
```swift
                    .padding(.horizontal, 22)
```

New:
```swift
                    LazyVStack(alignment: .leading, spacing: Theme.Spacing.xl, pinnedViews: [.sectionHeaders]) {
```
```swift
                    .padding(.horizontal, Theme.Spacing.xxl)
```

`18` folds to `Theme.Spacing.xl` (16) — unambiguously closer to 16 than to 22.

- [ ] **Step 7: Build**

Run: `xcodebuild -scheme "Xisto In Time" -configuration Release build`
Expected: `** BUILD SUCCEEDED **`, zero warnings.

- [ ] **Step 8: Visual check**

Open Sessões and confirm, end to end: toolbar (title, search field, "+ Nova sessão" blue button), the three-metric summary bar with the "Registado hoje vs. planeado" line, the filter chip row (note the active chip — this task changed its background from a raw `1C1C1E` hex to `Theme.Color.chipActiveBackground`, same value in light mode, confirm it's still the same near-black pill with white text), the day cards, and — if you clear all sessions from a filter — the empty state text.

- [ ] **Step 9: Commit**

```bash
git add "Xisto In Time/UI/AllSessionsView.swift"
git commit -m "$(cat <<'EOF'
refactor: AllSessionsView usa tokens de Theme

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: `SessionRow.swift` + `SessionControlView.swift`

**Files:**
- Modify: `Xisto In Time/UI/SessionRow.swift:36-42`
- Modify: `Xisto In Time/UI/SessionControlView.swift` (several call sites, listed below)

**Interfaces:**
- Consumes: `Theme.Font.{caption, footnote, callout, body}`, `Theme.Color.textFaint`, `Theme.Spacing.md`, `Theme.Radius.lg` (Task 1); `SessionKind.color` (Task 2, already-migrated `.break`/`.plan` cases).

- [ ] **Step 1: `SessionRow.swift` — fix the stale Plano color and the fixed `.gray`**

Old (lines 36–42):
```swift
    private var kindBadge: (label: String, color: Color)? {
        switch session.kind {
        case .work: return nil
        case .break: return ("Pausa", .gray)
        case .plan: return ("Plano", Color(hex: "FAE588"))
        }
    }
```

New:
```swift
    private var kindBadge: (label: String, color: Color)? {
        switch session.kind {
        case .work: return nil
        case .break: return ("Pausa", SessionKind.break.color)
        case .plan: return ("Plano", SessionKind.plan.color)
        }
    }
```

This is the fix noted in the spec: `SessionRow.swift` still had the pre-unification Plano color (`FAE588`, from before the Sessões redesign unified it to `E8A300` everywhere else) — routing through `SessionKind.plan.color` picks up the correct, already-migrated (Task 2) value, and gets a dark-mode-safe break color too.

- [ ] **Step 2: `SessionControlView.swift` — `modeSelector`'s inactive fill (line 228)**

Old:
```swift
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(m == mode ? accentColor : Color.gray.opacity(0.18))
                )
```

New:
```swift
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                        .fill(m == mode ? accentColor : Theme.Color.textFaint.opacity(0.18))
                )
```

`Color.gray` (SwiftUI's fixed system gray, ~`#8E8E93`) is closer in luminosity to `Theme.Color.textFaint` (`C4C4C9`) than to `fillSubtle` (`F1F1F4`, near-white) — this keeps the original's `0.18` alpha unchanged and only swaps which base gray it's a tint of, rather than inventing a compensating opacity value. It's still an approximation, not an exact reproduction — flag it in the visual check below. `accentColor` (this view's own computed property, `selectedProject?.color ?? .accentColor`) is unrelated to `Theme.Color.accent` and stays unchanged — it deliberately reflects the *selected project's* color, not the app's brand color. `cornerRadius: 12` folds to `Theme.Radius.lg`, an exact match.

- [ ] **Step 3: `SessionControlView.swift` — font sizes, exact/documented matches only**

| Line | Old | New |
|---|---|---|
| 175, 186 | `.font(.system(compact ? .title2 : .largeTitle, design: .monospaced, weight: .semibold))` | unchanged — semantic system font, not a numeric literal, out of scope |
| 220 | `.font(.system(size: 15, weight: m == mode ? .bold : .regular))` | `.font(.system(size: Theme.Font.callout, weight: m == mode ? .bold : .regular))` |
| 400 | `.font(.system(size: 11, weight: .semibold))` | `.font(.system(size: Theme.Font.caption, weight: .semibold))` |
| 404 | `.font(.system(size: 15, weight: .semibold))` | `.font(.system(size: Theme.Font.callout, weight: .semibold))` |
| 413 | `.font(.system(size: 11, weight: .semibold))` | `.font(.system(size: Theme.Font.caption, weight: .semibold))` |
| 417 | `.font(.system(size: 15, weight: .semibold))` | `.font(.system(size: Theme.Font.callout, weight: .semibold))` |
| 425 | `.font(.system(size: 14, weight: .semibold))` | `.font(.system(size: Theme.Font.body, weight: .semibold))` |
| 452 | `.font(.system(size: 12, weight: .semibold))` | `.font(.system(size: Theme.Font.footnote, weight: .semibold))` |

Lines 400/413 (`11` → `caption`, which is `11.5`) and line 452 (`12` → `footnote`, which is `12.5`) are the documented consolidations from the spec's font table (`caption` substitutes `11, 11.5`; `footnote` substitutes `12, 12.5`), not ad-hoc rounding.

- [ ] **Step 4: `SessionControlView.swift` — spacing, exact matches only**

| Line | Old | New |
|---|---|---|
| 68 | `VStack(alignment: .leading, spacing: compact ? 8 : 14)` | `VStack(alignment: .leading, spacing: compact ? Theme.Spacing.md : 14)` |
| 201 | `.padding(.vertical, compact ? 8 : 14)` | `.padding(.vertical, compact ? Theme.Spacing.md : 14)` |

The `14` branch of both ternaries stays local (tie between `Theme.Spacing.lg`(12) and `.xl`(16)). `cornerRadius: 10` (lines 162, 430), `cornerRadius: 16` (line 203), and `cornerRadius: 3` (line 261, the tiny 5pt-tall Pomodoro block bars) all stay local per the folding rule — none is an unambiguous nearest-neighbor case.

- [ ] **Step 5: Build**

Run: `xcodebuild -scheme "Xisto In Time" -configuration Release build`
Expected: `** BUILD SUCCEEDED **`, zero warnings.

- [ ] **Step 6: Visual check**

Open a Projecto or Tarefa detail page (uses `SessionRow`) and confirm a Pausa session's badge is still gray and a Plano session's badge is now the correct amber `E8A300` (previously it may have shown the stale pale-yellow `FAE588` — this is an intentional visible fix, not a regression, if you happen to have any Plano sessions with a task/project to look at). Open the popover and the main window's mini timer (`SessionControlView` in both `compact` and full layouts): confirm the free/pomodoro mode toggle, the timer text, "A REGISTAR EM" label, and the "Mudar"/"Retomar" buttons are unchanged. Look closely at the *inactive* mode-toggle pill (Livre/Pomodoro, whichever isn't selected) — its background is the one approximated color in this task (`textFaint.opacity(0.18)` standing in for `Color.gray.opacity(0.18)`); confirm it still reads as the same faint neutral wash, not visibly lighter or darker.

- [ ] **Step 7: Commit**

```bash
git add "Xisto In Time/UI/SessionRow.swift" "Xisto In Time/UI/SessionControlView.swift"
git commit -m "$(cat <<'EOF'
refactor: SessionRow/SessionControlView usam tokens de Theme

Corrige de caminho a cor do Plano em SessionRow (ainda tinha o
FAE588 anterior à unificação para E8A300).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Ficheiros restantes — apenas espaçamento/raio (sem cor)

None of the files in this task contain a `Color(hex:)` literal or a fixed system-gray/red/white constant — every color they use (`.primary`, `.secondary`, `.accentColor`, `.thinMaterial`/`.regularMaterial`, `.separator`, project/task colors) is already adaptive and out of scope per the spec. This task only names their padding/corner-radius numbers that are exact `Theme.Spacing`/`Theme.Radius` matches or unambiguous folds — zero color changes, zero visual risk beyond a couple of documented radius folds.

**Files:**
- Modify: `Xisto In Time/UI/TaskPickerView.swift:113-114,178,226`
- Modify: `Xisto In Time/UI/ProjectDetailView.swift:61-63,164,177-178`
- Modify: `Xisto In Time/UI/TaskDetailView.swift:66-68,76-78,155-156`
- Modify: `Xisto In Time/UI/ProjectsView.swift:98`
- Modify: `Xisto In Time/UI/TaskCard.swift:59`
- Modify: `Xisto In Time/UI/ReportsView.swift:109-111`
- Modify: `Xisto In Time/UI/PomodoroDecisionView.swift:19,41,68-69`
- Modify: `Xisto In Time/UI/IdleResolutionView.swift:19,42`
- Modify: `Xisto In Time/PopoverView.swift:26,35`
- Modify: `Xisto In Time/UI/MainWindowView.swift:126-127,137-138,152-153`

**Interfaces:**
- Consumes: `Theme.Font.{title2, largeTitle}`, `Theme.Spacing.{xxs, xs, sm, md, base, lg, xl}`, `Theme.Radius.{md, lg, xl}` (Task 1).

- [ ] **Step 1: `TaskPickerView.swift`**

Old (line 113–114):
```swift
            .padding(8)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
```
New:
```swift
            .padding(Theme.Spacing.md)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
```

Old (line 178, `recentRow`):
```swift
                    .font(.system(size: 15, weight: .semibold))
```
New:
```swift
                    .font(.system(size: Theme.Font.callout, weight: .semibold))
```

Old (line 226, `taskRow`):
```swift
                highlightedTitle(task.title, query: query)
                    .font(.system(size: 15))
```
New:
```swift
                highlightedTitle(task.title, query: query)
                    .font(.system(size: Theme.Font.callout))
```

- [ ] **Step 2: `ProjectDetailView.swift`**

Old (lines 61–63, `statCard` HStack padding):
```swift
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
```
New:
```swift
                .listRowInsets(EdgeInsets())
                .padding(.vertical, Theme.Spacing.sm)
                .padding(.horizontal, Theme.Spacing.xs)
```

Old (line 164, `blockHeader`):
```swift
        .padding(.vertical, 4)
```
New:
```swift
        .padding(.vertical, Theme.Spacing.xs)
```

Old (lines 177–178, `statCard`):
```swift
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
```
New:
```swift
            .padding(Theme.Spacing.lg)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
```

- [ ] **Step 3: `TaskDetailView.swift`**

Old (lines 66–68, the "Começar sessão" button):
```swift
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
```
New:
```swift
                .listRowInsets(EdgeInsets())
                .padding(.vertical, Theme.Spacing.sm)
                .padding(.horizontal, Theme.Spacing.xs)
```

Old (lines 76–78, stat cards row):
```swift
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
```
New:
```swift
                .listRowInsets(EdgeInsets())
                .padding(.vertical, Theme.Spacing.sm)
                .padding(.horizontal, Theme.Spacing.xs)
```

Old (lines 155–156, `statCard`):
```swift
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
```
New:
```swift
            .padding(Theme.Spacing.lg)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
```

- [ ] **Step 4: `ProjectsView.swift`**

Old (line 98):
```swift
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
```
New:
```swift
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
```

- [ ] **Step 5: `TaskCard.swift`**

Old (line 59):
```swift
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
```
New:
```swift
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
```

- [ ] **Step 6: `ReportsView.swift`**

Old (lines 109–111, `totalCard`):
```swift
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
```
New:
```swift
            .padding(.horizontal, 14)
            .padding(.vertical, Theme.Spacing.md)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
```

`14` and `10` both stay local (ties), only the exact `8` folds.

- [ ] **Step 7: `PomodoroDecisionView.swift`**

Old (line 19):
```swift
                .font(.system(size: 34))
```
New:
```swift
                .font(.system(size: Theme.Font.largeTitle))
```

Old (line 41):
```swift
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
```
New:
```swift
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.xl))
```

Old (lines 68–69, `DecisionButtonBody`):
```swift
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
```
New:
```swift
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.md)
```

`.padding(32)` (line 39, the outer `VStack`) stays local — the spec's named outlier.

- [ ] **Step 8: `IdleResolutionView.swift`**

Old (line 19):
```swift
                .font(.system(size: 30))
```
New:
```swift
                .font(.system(size: Theme.Font.title2))
```

Old (line 42):
```swift
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
```
New:
```swift
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.xl))
```

`.padding(28)` (line 40) stays local — the spec's named outlier.

- [ ] **Step 9: `PopoverView.swift`**

Old (line 26):
```swift
        .padding(16)
```
New:
```swift
        .padding(Theme.Spacing.xl)
```

Old (line 35):
```swift
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
```
New:
```swift
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
```

`14` folds to `Theme.Radius.lg` (12) — unambiguously closer to 12 (diff 2) than to 20 (diff 6). `spacing: 14` on the outer `VStack` (line 22) stays local (tie).

- [ ] **Step 10: `MainWindowView.swift`**

Old (lines 126–127, `SessionControlView(compact: true)`):
```swift
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
```
New:
```swift
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.base)
```

Old (lines 137–138, `SettingsLink`):
```swift
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
```
New:
```swift
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.md)
```

Old (lines 152–153, "Sair" button):
```swift
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
```
New:
```swift
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.md)
```

- [ ] **Step 11: Build**

Run: `xcodebuild -scheme "Xisto In Time" -configuration Release build`
Expected: `** BUILD SUCCEEDED **`, zero warnings.

- [ ] **Step 12: Visual check**

These are all exact-value renames or small, well-justified folds (max drift: the `PomodoroDecisionView`/`IdleResolutionView` overlay corner radius and the `PopoverView` panel corner radius, each already an exact `Theme.Radius.xl`/`.lg` match). Spot-check: a Projecto and a Tarefa detail page (stat cards, task/session cards), Projectos list, Estatísticas' "Total" pill, the menu-bar popover panel shape, the sidebar's mini timer/Preferências/Sair rows, and — by triggering them if convenient, or by inspection if not — the Pomodoro decision and Idle-resolution overlays. Nothing should look different from before this task.

- [ ] **Step 13: Commit**

```bash
git add "Xisto In Time/UI/TaskPickerView.swift" "Xisto In Time/UI/ProjectDetailView.swift" "Xisto In Time/UI/TaskDetailView.swift" "Xisto In Time/UI/ProjectsView.swift" "Xisto In Time/UI/TaskCard.swift" "Xisto In Time/UI/ReportsView.swift" "Xisto In Time/UI/PomodoroDecisionView.swift" "Xisto In Time/UI/IdleResolutionView.swift" "Xisto In Time/PopoverView.swift" "Xisto In Time/UI/MainWindowView.swift"
git commit -m "$(cat <<'EOF'
refactor: espaçamento/raio dos restantes ecrãs usa Theme

Sem alteração de cor nestes ficheiros — já usavam só cores
adaptativas do sistema. Só nomeia paddings/raios já existentes.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Bump de versão + verificação final de modo escuro

**Files:**
- Modify: `VERSION`
- Modify: `CHANGELOG.md`
- Modify: `Xisto In Time/Core/AppVersion.swift`

**Interfaces:**
- Consumes: nothing new — this task only bumps version metadata and asks the user to verify dark mode end to end (something no earlier task can do on its own, since dark mode is entirely new behavior).

- [ ] **Step 1: Bump version (minor — new capability, no breaking change)**

Current version is `1.22.1`. Bump to `1.23.0`.

`VERSION`:
```
1.23.0
```

`Xisto In Time/Core/AppVersion.swift`:
```swift
import Foundation

/// Current app version, following SemVer (major.minor.patch).
/// Kept in sync with `VERSION`, `CHANGELOG.md` and the git tag on every release — see CLAUDE.md.
enum AppVersion {
    static let current = "1.23.0"
}
```

`CHANGELOG.md`: add an entry at the top (read the file first to match its existing format exactly) along the lines of "design system (Theme) — cores, tipografia, espaçamento e raio centralizados; base para tema escuro automático."

- [ ] **Step 2: Build**

Run: `xcodebuild -scheme "Xisto In Time" -configuration Release build`
Expected: `** BUILD SUCCEEDED **`, zero warnings.

- [ ] **Step 3: Commit and tag**

```bash
git add VERSION CHANGELOG.md "Xisto In Time/Core/AppVersion.swift"
git commit -m "$(cat <<'EOF'
v1.23.0 — design system (Theme)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git tag v1.23.0
```

- [ ] **Step 4: Ask the user to verify dark mode end to end**

This is the one check nothing earlier in this plan can perform, since dark mode is new behavior with no "before" to diff against. Ask the user to switch System Settings → Appearance to Dark, then open the app and look at:
- Menu bar popover.
- Janela principal → Calendário (grid, session blocks of all three kinds, current-time red line, the "Agora"/chevron controls).
- Janela principal → Sessões (toolbar, summary bar, filter chips including the active one, day cards, rows, hover actions).
- Janela principal → Projectos, a Projecto detail page, a Tarefa detail page, Estatísticas.
- Trigger (or describe wanting to see) the Pomodoro decision and Idle-resolution overlays.

Report anything that reads as low-contrast, wrong-hue, or otherwise off — those are exactly the hand-picked dark values in `Core/Theme.swift` (Task 1) that would need adjusting, since none of them existed before this plan.
