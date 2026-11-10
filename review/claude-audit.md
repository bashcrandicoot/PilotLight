# PilotLight audit: UI/UX polish and code quality

This is a read-only review. I read all of `Sources/PilotLight/*.swift`, `Resources/Info.plist`, `README.md`, `QUICKSTART.md`, `Scripts/build.sh`, `install.sh`, `uninstall.sh`, `generate-app-icon.py`, `generate-assets.py`, `Tools/pilotlight` and `Package.swift`. I did not read `Makefile`, `Scripts/render-*.py`, `docs/`, `review/` or `test-artifacts/`. Nothing was built, run or visually inspected, so rendering claims are from reading the code and should be checked on a Mac. Bash was denied, so I used Read and Glob only.

---

## 1. Summary

The app is small and the structure is sound: a flag watcher, an overlay controller, one window per display, and a click-through glow plus pill. The product constraints are respected in code:

- The label is exactly "Grok is working" (`Constants.message`).
- The pill sizes itself from Ember plus the full label, using `.byClipping` with an explicit intrinsic width (`PillView.swift:66-78`, `119-128`).
- There are six preset swatches and no color well.
- The glow is static, with an opacity pulse only. Nothing rotates.
- The menu-bar glyph is a template image.

The main issues:

1. **`install.sh` runs `rm -rf "$HOME/Developer/grok-border"` unconditionally** (`install.sh:37-40`). That path is a user directory, not an app artifact, and this is the one item I'd call a release blocker.
2. **Settings gives no feedback when the border is hidden, which is its normal state.** Clicking a swatch or dragging the slider changes nothing the user can see until they press Preview.
3. **The pill and menu-bar glyph ignore the chosen glow color and the on/off state.**
   - The pill stays brown/gold with a gold border and shadow even when the glow is Blue.
   - The menu-bar glyph looks the same whether the border is on or off.
4. **The glow renderer is the main architectural limit.**
   - It rasterizes a full-screen bitmap per display, up to about 59 MB on a 5K screen.
   - Its inner contours go square-cornered at 12 pt of depth, so the "soft rounded bloom" gets boxy in the corners.
   - It special-cases the default gold (`usesDefaultGold`). Other colors get a flatter ramp.
5. **Accessibility gaps:** there is no Reduce Motion handling, no VoiceOver announcement, and the swatches don't expose which one is selected.
6. **Several small correctness and hygiene issues:**
   - A `UserDefaults.didChangeNotification` observer makes every slider tick re-layout the pill.
   - There is a deprecated `activate(ignoringOtherApps:)` call.
   - Layer `CGColor`s go stale after an appearance change.
   - `generate-assets.py` has a hard-coded absolute source path.
   - The app bundle ships a 1024 px source PNG it never uses.

Section 4 proposes four calm styles, ranked.

---

## 2. UI / UX findings

### Pill

| # | Sev | Finding | Recommendation |
|---|---|---|---|
| P1 | polish | The pill ignores the glow color. `Palette.pillBorder`, `goldDeep` shadow, `0x302006` fill and the highlight are all hard-coded gold/brown (`PillView.swift:30-51`). With Blue, Green or Pink selected you get a blue glow with a gold-brown pill. | Make the border color, halo shadow and top highlight derive from `Preferences.glowColor`, using the same `glowAppearanceDidChange` notification the glow already observes. Keep the fill a neutral dark with a slight tint. The label stays cream, and Ember keeps its terracotta. |
| P2 | polish | The pill sits at `menuBarHeight + 11` pt, centered. In browsers it covers tab strips and URL bars. It is click-through, but it hides what the user may want to read. | Add "ghosting". In `GlowBorderView`, sample `NSEvent.mouseLocation` at about 10 Hz only while visible. If the cursor is within about 60 pt of the pill, fade it to about 25% opacity. Optionally add a Settings pop-up for pill position (Top / Bottom / Hidden). |
| P3 | polish | Ember redraws through a 60 Hz `Timer` plus `needsDisplay` on every display (`PillBotView.swift:45-72`). That is one timer per screen and a CPU redraw each frame. The README's "idle CPU near zero" holds only when hidden. | Build Ember from `CAShapeLayer`s (body group plus two eye layers). Drive the bob, squash, blink and look with `CAKeyframeAnimation`, using the existing `keyTimes` from `Pose` and a 2.4 s `repeatCount = .infinity`. This runs on the compositor with no timers. Alternatively, animate on one display only. |
| P4 | polish | Ember ignores Reduce Motion. The glow pulse does too (`GlowBorderView.swift:94-103`). | Check `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`. When it is true, show Ember static (a blink only, or a pose at t=0) and hold the glow at opacity 1. Observe `NSWorkspace.accessibilityDisplayOptionsDidChangeNotification`. |
| P5 | polish | `PillView` observes `UserDefaults.didChangeNotification` (`PillView.swift:84`). That fires on every defaults write, including every continuous slider tick. Each one triggers an async `applyFont`, `invalidateIntrinsicContentSize` and a superview relayout. | Remove that observer. Keep the screen-parameter observer. The three distributed notification names (`AppleTextScalingChangedNotification` etc.) are undocumented, and I couldn't confirm they exist. Treat them as no-ops and don't rely on them. |
| P6 | nit | The `intrinsicContentSize` getter has side effects: `applyFont()`, `invalidateIntrinsicContentSize()`, and setting `preferredMaxLayoutWidth` (`PillView.swift:119-128`). `preferredMaxLayoutWidth = 0` is also set in `commonInit`, and `label.stringValue` is set twice. | Make it a pure measurement. Compute the label size with `NSAttributedString.size()` or `label.cell?.cellSize`. Remove the duplicate assignments. |
| P7 | polish | There is no automated check for the "never truncates" guarantee. macOS has no system-wide Dynamic Type for third-party apps, so this is easy to regress silently. | Add a unit test. Build `PillView`, force `label.font` to sizes 12-48 pt, and assert that `label.frame.width >= ceil(attributedSize.width)` and that the pill width equals the padding plus Ember plus text. Also assert the pill fits within the screen width. |
| P8 | nit | The magic numbers `9`, `9`, `16`, `10` and `-0.5` are repeated between `intrinsicContentSize` and `layout()` (`PillView.swift:124-145`). The left padding (9) and right padding (16) are asymmetrical, and the 0.5 pt border barely renders on 1x displays. | Move them into named constants (`pillLeadingPad`, `pillIconGap`, `pillTrailingPad`) and share them between the two methods. Use 1 pt for the border (alpha 0.35-0.45) or scale it with `backingScaleFactor`. |
| P9 | polish | The pill is not exposed to assistive tech. The overlay is invisible to VoiceOver, so a blind user never learns the Mac is being driven. | On each hidden→visible transition, post `NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [.announcement: "Grok is working", .priority: NSAccessibilityPriorityLevel.high])`. Do this only on transitions, never on pings. Also set `setAccessibilityLabel` on the pill. |

### Settings window

| # | Sev | Finding | Recommendation |
|---|---|---|---|
| S1 | polish | There is no live feedback. A swatch click or slider drag changes only the stored value (`SettingsWindowController.swift:142-150`). The border is normally hidden, so the user must find and press Preview. | When a swatch is clicked or the slider is released, auto-run the 5-second preview. Post `.previewGlowRequested` with a short debounce (about 250 ms). Do it on slider mouse-up (`NSApp.currentEvent?.type == .leftMouseUp`), not on every tick. Preview stays as an explicit button. |
| S2 | polish | The Preview button gives no state. Pressing it during a preview silently restarts the timer. | Post a "preview ended" notification, or have `StatusItemHosting` expose `isTesting`. Disable the button, or retitle it "Previewing…", for the 5 seconds. |
| S3 | polish | The swatches are `.button` role with a drawn ring, and the selected state is not exposed (`SettingsWindowController.swift:158-229`). The focus ring is drawn around the whole 44×52 rect, not the circle. There is no hover or pressed feedback, and no arrow-key movement within the row. | Group the swatches under an `NSAccessibilityRadioGroup`-style container, with each swatch `.radioButton` and `setAccessibilityValue(isChosen ? 1 : 0)`. Override `focusRingMaskBounds` and `drawFocusRingMask()` to return the circle. Add a faint hover ring through an `NSTrackingArea`. Add left/right arrow handling, or make the row a roving-tabindex control. |
| S4 | nit | Swatch captions are drawn at a fixed 10 pt in `secondaryLabelColor`. The contrast is low and they ignore text-size changes. | Bump them to 11 pt `.secondaryLabelColor`, or use `NSTextField` labels so the system handles scaling. |
| S5 | polish | The window is a fixed 400×248 and `window.center()` runs on every present (`SettingsWindowController.swift:14`, `33`). It re-centers even if the user dragged it. The root view's frame is also hard-coded, separate from the constraints. | Size the window from the content: `window.setContentSize(root.fittingSize)`. Call `center()` only the first time, or use `setFrameAutosaveName("PilotLightSettings")`. |
| S6 | polish | There is no "Reset to defaults" (Yellow, 55%). The slider has no default tick mark. The 25% floor isn't explained. | Add a quiet "Reset" link-style button that sets `defaultColor` and `defaultIntensity`. Optionally add one tick mark at the default on the slider. |
| S7 | polish | `NSApp.activate(ignoringOtherApps: true)` is deprecated in macOS 14 (`SettingsWindowController.swift:35`, `WelcomeWindowController.swift:37`). | Use `if #available(macOS 14, *) { NSApp.activate() } else { NSApp.activate(ignoringOtherApps: true) }`. |
| S8 | polish | The app is `.accessory` with no main menu, so ⌘W, ⌘C and ⌘A don't work in the Welcome and Settings windows. Esc doesn't close them either. The ⌘, and ⌘Q key equivalents on the status menu work only while that menu is open. | Install a minimal `NSApp.mainMenu` (App, Edit, Window). It is invisible for accessory apps but enables the shortcuts when a window is key. Implement `cancelOperation(_:)` on both windows to close. |
| S9 | nit | The window title is "PilotLight Settings". | "Settings" or "PilotLight Settings" are both fine. Just keep it consistent with the "Welcome to PilotLight" / "Quick Start…" naming (see Q1). |

### Quick Start / Welcome window

| # | Sev | Finding | Recommendation |
|---|---|---|---|
| Q1 | nit | There are three names for one thing: the window is "Welcome to PilotLight", the menu item is "Quick Start…", the file is QUICKSTART.md. | Pick one. I suggest the window title "PilotLight Quick Start" and a single `Constants` string. |
| Q2 | polish | The window has no brand moment and weak hierarchy. It is a 15 pt semibold title over a wall of 13 pt text, with no Ember. | Add a 64 pt Ember (reuse `EmberBot.draw`) or the app icon at the top. Group sections with the same semibold subheads. |
| Q3 | polish | The "Done" button is left-aligned because the stack uses `.leading` alignment (`WelcomeWindowController.swift:49`, `116-122`). | Put Done in a trailing-aligned bottom bar. |
| Q4 | polish | Copy gives no confirmation. The "Copy" button does nothing visible (`:146-149`). | Swap the title to "Copied ✓" for 1.5 s, then restore it. |
| Q5 | polish | The commands block is a monospaced label aligned with literal spaces (`:62-70`). The `<command>` line wraps by hand, which breaks when the font or width changes. | Use an `NSGridView` of (command, description) rows. Make the commands selectable. Optionally add a per-row copy button. |
| Q6 | polish | There is no "Try it" action in the window, though that is the first-run aha moment. The text says to use the menu instead. | Add a "Show test border" button that posts `.previewGlowRequested`. |
| Q7 | polish | The fixed 680 pt height with a bottom `lessThanOrEqual` constraint can clip at large text sizes or on small displays. | Wrap the stack in an `NSScrollView`, or derive the window height from `fittingSize` with a minimum. |
| Q8 | nit | The first-launch window steals focus through `NSApp.activate`. That is acceptable, but `install.sh` says it "does not take over the screen". | Keep it, but soften the install.sh comment. Or defer the window until the user next clicks the menu item. |
| Q9 | polish | The agent box uses `layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor` and `borderColor = separatorColor.cgColor` (`:81-84`). These are `CGColor` snapshots and won't update if the system switches between light and dark while the window is open. | Subclass `NSView` and set the colors in `updateLayer()` or `viewDidChangeEffectiveAppearance()` using `effectiveAppearance.performAsCurrentDrawingAppearance { … }`. |
| Q10 | nit | The copy is hard-wired to "yellow" ("soft yellow glow", in the intro and README) although color is configurable. QUICKSTART §5 says "ping every few minutes" while the copied instruction says every 15 minutes. | Say "soft glow (yellow by default)". Make the ping guidance one consistent phrase. |
| Q11 | polish | `Constants.message` and the agent instruction are duplicated in Swift and Markdown. The comment "Copy matches QUICKSTART.md so the two cannot drift" is aspirational. | Add a test that extracts the blockquote from QUICKSTART.md and compares it to `agentInstruction`. |

### Menu bar item and menu

| # | Sev | Finding | Recommendation |
|---|---|---|---|
| M1 | polish | The glyph is identical whether the border is on or off. The only signal is opening the menu. | Ship a second template variant (Ember with a small dot or glow-arc cut-out) and swap it on `.on` and `.test` in `refresh()`. It stays a template image. At minimum, update `button.toolTip` and the accessibility label ("PilotLight, border on"). |
| M2 | polish | "Hide Border Now" is always enabled, even when the state is Off (`StatusItemController.swift:39-45`, `menu.autoenablesItems = false`). It also removes the real flag, so an agent's next `ping` (which recreates the flag, per `Tools/pilotlight:70-76`) brings the border straight back. The user may think it's broken. | Disable it when the border is off. Label it "Hide Border (until next ping)", or add a short comment in the menu or Quick Start. If you want a sticky hide, add "Snooze 1h" as a separate feature. |
| M3 | polish | The status line is a plain disabled item reading "Border: On". | Add an `NSMenuItem.image` (`circle.fill` SF Symbol, macOS 11+, tinted green/gray/yellow). Refresh on `menuNeedsUpdate(_:)` so it's correct at open time. |
| M4 | nit | The title "Show Test Border for 5s" hard-codes the duration that `Constants.testDuration` already owns (`StatusItemController.swift:28`). | Build the title from the constant. |
| M5 | polish | Missing standard items: "About PilotLight" (version 1.0.0 lives only in Info.plist), a login-item toggle, and an update path. | Add About, with `orderFrontStandardAboutPanel`. Optionally add "Launch at Login" using `SMAppService.mainApp` (macOS 13+). |
| M6 | polish | The last-resort fallback `menuImage()` is an empty `NSImage` (`:76-78`). If both resource lookups fail you get a zero-ink status item that cannot be clicked. | Fall back to an SF Symbol (`NSImage(systemSymbolName: "flame", …)`) with `isTemplate = true`. |

### Screen glow

| # | Sev | Finding | Recommendation |
|---|---|---|---|
| G1 | polish | Inner contours square off. Band radius is `max(0, radius − inset)` (`GlowBorderView.swift:150-151`), which hits 0 at 12 pt of depth. A bloom that reaches 80 pt therefore has boxy inner corners and a visibly rectangular falloff. The brief says "rounded". | Grow the radius with depth: `radius + inset * k`, with k about 1.0-1.5, so deeper contours round off. A better route is a signed-distance rounded-rect falloff (see C1). |
| G2 | polish | Yellow, Amber and White glow on light content (white web pages) is barely visible. The glow is a translucent tint over the content. | Add an optional thin inner rim (1.5-2 pt, deeper tone, e.g. the unused `Palette.goldStroke`) that gives a hard edge cue independent of background. This is also the core of Style A in section 4. |
| G3 | polish | Non-default colors lose their depth. `GlowSpec.bands` uses the warm three-layer gold profile only when the tint matches default gold. Otherwise it applies a flat tint with the same alpha (`Constants.swift:115-131`). Blue and Green therefore look thinner than Yellow. | Give `GlowPreset` explicit `core`, `mid` and `outer` colors, or derive them with an HSB shift. Remove the `usesDefaultGold` hack. |
| G4 | polish | The faint tail is cut off. Bands with `alpha < 0.012` are dropped (`:126`). With 2 pt bands and 8-bit alpha you can see steps at the outer edge, especially at low intensity. | Render by a distance function, or use 1 pt bands with dithering. The 9-slice approach in C1 makes this cheap. |
| G5 | polish | The overlay will be in every screenshot the agent takes. The glow tints about 80 pt of every screen edge and the pill covers part of the window titlebar. That can confuse a vision agent and obscure UI. | Offer "Hide overlay from screenshots", setting `window.sharingType = .none` on `OverlayWindow`. Test it on your target macOS versions, because newer capture APIs may not honor it. Default it based on your product judgment. |
| G6 | nit | Corner radii are hard-coded: 12 pt for any built-in display and 10 pt for external ones (`Constants.swift:90-91`, `OverlayController.swift:140-145`). Real panel radii differ, and external panels are square. | Keep it, but treat 10/12 as a tuning knob in `GlowSpec`. Optionally read `NSScreen.safeAreaInsets` to detect notch hardware. |
| G7 | nit | A newly attached display gets its window shown without a fade (`OverlayController.swift:111-115`). | Run the same alpha animation used in `show()` for windows created while visible. |
| G8 | polish | The pulse is a layer opacity animation between 0.84 and 1 over 3.2 s with autoreverse, which is a calm, appropriate choice. | Keep it. Just add Reduce Motion handling (P4). |

---

## 3. Code quality findings

### Blocker

| # | Sev | Finding | Recommendation |
|---|---|---|---|
| C0 | **blocker** | `install.sh:37-40` does `rm -rf "$HOME/Developer/grok-border"` with no ownership check. A user who keeps their own project there loses it. Everything else in the installer is scoped to PilotLight artifacts. | Delete this block. If the legacy cleanup is still wanted, remove only the known legacy app bundle and plist, and for the dev directory print a note rather than deleting. |

### Polish

| # | Sev | Finding | Recommendation |
|---|---|---|---|
| C1 | polish | `GlowBorderView.renderGlowImage` allocates a full-screen RGBA bitmap per display. That is about 59 MB on a 5K screen at 2x (`:123-176`). It re-renders about 40 bands on every appearance change, including per slider tick. The glow is only about 80 pt deep and the center is transparent. | Render a small 9-slice: an image of about `2 * maxDistance + 2 * radius + 4` points square. Assign it to the layer with `contentsCenter` set to the central 1-pixel region and `contentsGravity = .resize`. This cuts memory to well under 1 MB and makes re-render nearly free. Use a color space of `CGColorSpace(name: .sRGB)` instead of `DeviceRGB`. |
| C2 | polish | The view reads global state while rendering: `Preferences.glowColor` and `glowIntensity` inside `renderGlowImage` (`:141`). `GlowSpec.bands` also defaults its arguments from `Preferences` (`Constants.swift:103-104`). That makes it hard to test and impossible to render a different style per display. | Introduce `struct GlowStyleConfiguration { style, tint, intensity, cornerRadius }`. Build it in `OverlayController`, pass it to `GlowBorderView.apply(_:)`, and make renderers pure functions. This is also the seam that Section 4 needs. |
| C3 | polish | `Preferences.glowColor` stores a `NSKeyedArchiver` blob of an `NSColor`, then re-matches it to a preset with a tolerance (`Preferences.swift:35-58`). `GlowPreset` already has a `String` raw value. | Store `glowPreset.rawValue`. Add a one-time migration: if the old `glowColor` data exists, map it with `GlowPreset.matching` and delete the key. Then `matching(_:tolerance:)` can live only in the migration. |
| C4 | polish | `Constants.swift` mixes `Constants`, `Palette`, `GlowPreset`, `GlowSpec` and the `NSColor` extension. `Palette.goldLight`, `goldAmber` and `goldStroke` appear unused. `OverlayController.isVisible`, `FlagWatcher.currentState()` and `FlagWatcher.directoryFD` appear unused. `syncScreens(preserveVisibility:)` is always called with `true`. | Split into `Palette.swift`, `GlowPreset.swift`, `GlowSpec.swift`, `Constants.swift`. Delete the dead members (verify with a project-wide search first). |
| C5 | polish | The preview path is indirect. Settings posts `Notification.Name.previewGlowRequested`, and `AppDelegate` wraps its handler in `Task { @MainActor }` (`AppDelegate.swift:52-60`). The observer token is discarded. | Inject a `previewHandler` closure, or extend `StatusItemHosting`/a small `AppCommands` protocol, so Settings calls `host.showTestBorder()` directly. This is type-checked and testable. |
| C6 | polish | The test timer uses both `testUntil: Date?` and a `Timer`. `finishTestIfNeeded` ends the test only if `Date() >= testUntil` (`AppDelegate.swift:123-129`). If the timer ever fired early, the preview would never end. | Use one `testToken`/generation integer or a single `DispatchWorkItem`. Drop the `Date` comparison. |
| C7 | polish | `FlagWatcher` comment says the directory source wakes the app when the flag is "touched" (`FlagWatcher.swift:35-36`). Touching an existing file changes its mtime and generally does not produce a directory vnode event, so touch-only pings rely on the 1 s poll. The `Timer`/`DispatchSource` handlers also hop through `Task { @MainActor }` on a main-queue source. Any write anywhere in `$HOME` wakes the watcher. | Correct the comment. Either watch the file itself (open the flag with `O_EVTONLY` when it exists), or keep the poll and drop the directory source. Call `publish` directly with `MainActor.assumeIsolated`. |
| C8 | polish | Pulse timing in `startAnimations` uses `CACurrentMediaTime()` directly for `beginTime` (`:101`). This is fine only while the layer sits at the root of its time space. It also removes and re-adds the animation on every `prepare`/`layout`. | Use `layer.convertTime(epoch, from: nil)`. Skip re-adding if the animation is already installed. |
| C9 | polish | `PillBotView.Pose.lerp` uses `from` as both an argument label and a parameter name in one signature, which is confusing (`PillBotView.swift:146-150`). `layer?.contentsScale` is set in init and again on backing change. | Rename to `lerp(_ a, _ b, start:, end:, at t:)`. |
| C10 | polish | There are no tests and no CI. `Package.swift` declares only the executable, and `@main` in an executable target makes `@testable import` awkward. `GlowSpec`, `GlowPreset.matching`, `FlagWatcher.readState`, `EmberBot.Pose` and the pill sizing are all pure and easy to test. | Split a `PilotLightCore` library target (everything except `AppDelegate.swift`). Add XCTest targets for pill measurement, flag states, preset migration and QUICKSTART/instruction drift. Add a CI job that runs `swift build` and `swift test`. |
| C11 | polish | Accessibility and localization are absent app-wide: no `NSLocalizedString`, and only the swatches have labels. | Wrap user-visible strings in `String(localized:)` now, even with English only. It's cheap to do early. |
| C12 | nit | `#available(macOS 12.0, *)` in `OverlayController.menuBarHeight` is always true for a 13.0 deployment target. | Remove the check. |
| C13 | nit | `AppDelegate.retained` static plus `NSApplication.delegate` is redundant. `app.delegate` is weak, so one strong reference is needed, but a local `let delegate` in `main()` that lives for the `run()` call is enough. | Drop the static, or keep it and comment why. |

### Scripts, build and bundle

| # | Sev | Finding | Recommendation |
|---|---|---|---|
| B1 | polish | `build.sh` copies every `Resources/*.png|pdf|svg` into the app (`:45-50`). That includes the 1024 px `AppIcon-source.png` and `ember-menubar.svg`, which the runtime never loads. | Copy only `MenuIcon.png` and `MenuIcon@2x.png`. |
| B2 | polish | README says "Apple Silicon or Intel", but `build.sh` produces a single native-arch binary (`:15-22`). A build on Apple Silicon won't run on Intel. | Build both with `swiftc -target arm64-…` and `x86_64-…`, then `lipo -create`. Alternatively, say "builds for the architecture it runs on". |
| B3 | nit | Dead and misleading comments in `build.sh`: "Strip a leading 'macos'…" with no code after it (`:9`), and `# shellcheck disable=SC2046` with no matching construct (`:25`). `codesign --deep` is discouraged. | Remove them. Sign the nested pieces explicitly (none today), or just `codesign --force --sign -`. |
| B4 | polish | `install.sh` relies on `sleep 0.3` between `bootout` and `bootstrap` (`:90-95`). On a slow machine `bootstrap` can fail with an I/O error, and `set -e` aborts the install half-done. | Poll `launchctl print` until the job is gone (with a timeout), then bootstrap. The comment about `KeepAlive` and `RunAtLoad` at lines 88-89 is also confusing. |
| B5 | polish | `install.sh` overwrites `/usr/local/bin/pilotlight` and `grok-border` with `ln -sfn` without checking what they were (`:58-62`). `uninstall.sh` is careful about this; install is not. | Only overwrite if absent or already a symlink to `$CLI_DEST`. |
| B6 | polish | The install uses a plain LaunchAgent, so macOS shows an unidentified "Allow in the Background" entry. QUICKSTART calls it a "login item". | Consider `SMAppService.mainApp.register()` (macOS 13+), exposed as a menu toggle. Otherwise, fix the wording. |
| B7 | polish | `uninstall.sh` leaves the `com.bashframes.pilotlight` preferences behind. | Add `defaults delete com.bashframes.pilotlight 2>/dev/null || true`, and mention it in QUICKSTART §6. |
| B8 | polish | `generate-assets.py` originally hard-coded a machine-local brand path for `DEFAULT_SOURCE` (`:25`). It only worked on one machine, and it copies the SVG into Resources. | Make the env var or an argument required with a helpful error. Or check the template PNGs into `Resources/` as the source of truth and delete the script. |
| B9 | nit | `generate-app-icon.py` requires Pillow with no note in the README. It prints the source size and mode but never asserts 1024×1024 RGBA. | Add `pip install pillow` to the README. Validate dimensions and alpha, and `SystemExit` with a clear message. |
| B10 | nit | `Scripts/__pycache__/`, `render-preview.py`, `render-review-v2.py`, `review/` and `test-artifacts/` sit in the tree. | Add `__pycache__/` and `build/` to `.gitignore`. Move one-off render scripts under `Tools/` or `docs/`, or delete them. |
| B11 | nit | `Info.plist`: `NSSupportsAutomaticGraphicsSwitching` does nothing useful for a `LSUIElement` overlay. There is no `NSHumanReadableCopyright`. Versions are static. | Remove the first, add the second, and have `build.sh` stamp `CFBundleVersion` from git. |
| B12 | nit | QUICKSTART clones `github.com/bashcrandicoot/PilotLight` while the license and bundle ID say `bashframes`. | Confirm which org is correct. |
| B13 | nit | The CLI is a single shared flag. Two agents (or `run` nested inside an `on`) clobber each other: the first `off` hides the border for both. | Not for now, but note it in the README. A future option is a per-PID file in `~/.grok-working.d/` with the app treating "any fresh file" as on. |

---

## 4. Extra border and glow styles

All four are static in geometry. Only opacity and color crossfade animate, so there is no rotating or spinning rectangle. All four also depend on one prerequisite refactor.

**Prerequisite (small):**

- Add `enum GlowStyle: String, CaseIterable { case softGlow, pilotLine, lamp, cornerLamps, duskFade }`.
- Store the selection in `Preferences.glowStyle` (default `.softGlow`).
- Add `struct GlowStyleConfiguration { style, tint, intensity, cornerRadius }` (C2).
- Move the existing band rendering behind a `GlowRenderer` protocol: `func makeLayers(for config: GlowStyleConfiguration, size: CGSize, scale: CGFloat) -> [CALayer]`, plus `func animations(epoch: CFTimeInterval) -> [(CALayer, CAAnimation)]`.
- `GlowBorderView` then holds a content container layer (`bloomLayer` becomes its first child). It swaps the sublayers when the configuration changes. `GlowSpec` keeps the Soft Glow profile and gains per-style specs next to it.
- In Settings, add a "Style" row. Use a segmented control or four small icon tiles, with no color well. Preview uses the chosen style.

### Ranking

**1. Pilot Line** (thin rim plus tight halo). Best overall.

- **Look:** a crisp 2 pt line hugging the rounded screen edge in the tint at about 70% opacity. A narrow 10-14 pt halo sits just inside it, and the center of the screen stays clear. It reads like a tiny pilot flame drawn around the display. It is very distinct from the broad 80 pt bloom.
- **Build:** a `CAShapeLayer` with a `CGPath(roundedRect: bounds.insetBy(1), cornerWidth: r, cornerHeight: r)`, `strokeColor` set to the tint, `lineWidth = 2`, and `shadowColor` set to the tint with `shadowRadius ≈ 10`, `shadowOpacity ≈ 0.8` and zero offset. Mask it to the screen bounds so the shadow only goes inward. Animate `shadowRadius` (9→13) or opacity (0.85→1) on the existing `Constants.pulseDuration`. The `GlowSpec` entry is just `lineWidth`, `haloRadius` and `alpha`, scaled by intensity.
- **Why:** it is the quietest style and the cheapest to render (no bitmap). It stays visible on white and light content, which fixes the weakness in G2. It matches the "pilot light" name and is easy to ignore while working.

**2. Lamp** (top-edge wash tied to the pill).

- **Look:** a soft warm wash that falls from the top edge of the screen to about 120-160 pt down. It is brightest behind the pill and fades toward the sides and downward. The pill looks like it is casting the light. The other three edges stay clear.
- **Build:** one `CAGradientLayer` (axial, top to bottom, tint alpha stops 0.55→0.18→0) plus a horizontal mask layer (a second gradient, 0 at the sides, 1 in the middle 60%). Optionally add a `.radial` `CAGradientLayer` centered on the pill's x position. Pulse by opacity. `GlowSpec` gains `lampHeight` and `lampSpread`.
- **Why:** it uses the area the user already attends to, so the indicator reads as the pill's status. It also takes the least screen area, so it is the least intrusive style for people who find a full perimeter busy. The bottom and side edges stay free for the Dock and scrollbars.

**3. Corner Lamps**

- **Look:** four soft radial glows tucked into the screen corners, each about 140-180 pt radius, with the edges between them nearly clear. They breathe in unison, or with a 0.25-cycle phase offset between corners. Offset the phase symmetrically to avoid a "circling" read.
- **Build:** four `CAGradientLayer`s with `type = .radial`, `startPoint = (0.5, 0.5)`, `endPoint = (1, 1)`, and color stops tint@0.6 → tint@0. Each is positioned in a corner and clipped to the screen. Pulse the opacity with per-layer `beginTime` offsets. `GlowSpec` gets `cornerRadiusPoints` and `phaseOffsets`.
- **Why:** it is clearly different from the perimeter bloom, and it reads as an ambient aura. It also respects rounded screen corners naturally. A disadvantage is that it shows less around the middle of each edge.

**4. Dusk Fade** (two-tone crossfade).

- **Look:** the Soft Glow geometry, but the color slowly crossfades between the preset and a companion hue (gold↔amber, blue↔teal, pink↔coral) over about 8 seconds. Nothing moves, only color shifts.
- **Build:** two `bloomLayer`s rendered with different ramps (reuse the existing renderer with a `companion` color on `GlowPreset`). Animate their opacities inversely using `CABasicAnimation` with `autoreverses`. `GlowSpec` gains `companion` and `crossfadeDuration`. It doubles memory unless the 9-slice change (C1) lands first.
- **Why:** it is the closest to the current look, so it is a low-risk option for people who like Soft Glow but want a hint of life. The weakness is that it is the least distinct, and it is a bit ornate for a calm indicator, so it ranks last.

**Rejected:**

- A marching or dashed border, or a light that travels around the perimeter. Both read as rotation.
- A screen-darkening vignette. It changes content legibility and agent screenshots.

---

## 5. Suggested implementation order

1. **Safety and quick wins** (under an hour):
   - Remove the `Developer/grok-border` deletion (C0).
   - Remove the `UserDefaults.didChangeNotification` observer (P5).
   - Disable "Hide Border Now" when Off (M2).
   - Fix `activate` deprecation (S7).
   - Make `buildContent` colors appearance-aware (Q9).
   - Stop copying the unused PNG and SVG into the bundle (B1).
   - Remove the dead-comment and dead-member items (B3, C4, C12).
2. **Renderer refactor** (the main architectural step):
   - Add `GlowStyleConfiguration` and `GlowRenderer` (C2).
   - Render the 9-slice (C1).
   - Fix the inner-corner rounding (G1) and the `usesDefaultGold` hack with per-preset ramps (G3, G4).
   - Store the preset as a raw string (C3).
3. **Pill:**
   - Tint to the glow color (P1).
   - Convert Ember to layer animations (P3).
   - Reduce Motion (P4).
   - Hover ghosting (P2).
   - VoiceOver announcement (P9).
   - Constants and pure intrinsic size (P6, P8).
4. **Settings and Welcome polish:**
   - Auto-preview on change (S1, S2).
   - Swatch accessibility (S3).
   - Reset and fitting size (S5, S6).
   - Main menu with ⌘W/⌘C and Esc (S8).
   - Welcome layout, Copy confirmation, Try-it button (Q2-Q7).
5. **Menu bar:** state-aware glyph and tooltip (M1), status icon (M3), About and login toggle (M5), SF Symbol fallback (M6).
6. **Tests and CI:** split `PilotLightCore` (C10). Add the pill-truncation test (P7), the QUICKSTART drift test (Q11), and flag-state and preset-migration tests.
7. **New styles**, in this order: Pilot Line, Lamp, Corner Lamps, Dusk Fade, plus the Style row in Settings.
8. **Packaging and docs:**
   - Universal binary (B2).
   - Install robustness (B4, B5).
   - Prefs cleanup on uninstall (B7).
   - Fix the asset script source path (B8).
   - Doc consistency: yellow wording, ping interval, repo org (Q10, B12).
   - Gitignore and repo clutter (B10).

If the owner wants the lowest-effort visible improvement first, do step 2's 9-slice plus corner rounding together with Pilot Line from step 7. It improves the default's softness and gives light-background users a style they can actually see.
