# Calculator Duo

A native SwiftUI calculator adapted for Kyle from [bofeiw/ios-calculator-clone-for-ipados](https://github.com/bofeiw/ios-calculator-clone-for-ipados), upstream commit `803007d`. The original project and this adaptation use CC0 1.0; see LICENSE. Original contributors: bofeiw and ayfallen.

## Layout

- Four columns and five rows on iPhone Duo, instead of five columns and four rows.
- The compact Duo reference keys remain 236 pixels across with 30-pixel gaps at 1398-pixel screen width. The grid aligns to the right with a 16-point margin rather than widening its keys. The calculator mode menu offers a persistent left-handed alignment.
- The display moves up to make room for the added row. Backspace, AC, percent and divide occupy the top row. Sign, zero, decimal point and equals occupy the bottom row.
- Round keys, black background, modern gray utility keys, white text and orange operators.
- Resizes on rotation and window changes, shrinking keys only where needed to keep controls visible. The side status area is disabled, following Apple’s full-width calculator guidance.

## Behavior

Basic addition, subtraction, multiplication, division, decimal entry, sign, contextual percent, backspace, repeated equals, and copy/paste via the display's context menu. Swipe the display to delete a digit. Decimal arithmetic avoids binary floating-point artifacts such as 0.1 + 0.2.

This is a separate app. It does not modify or replace Apple's Calculator binary. Scientific mode appears automatically in landscape and when the available width reaches 600 points (opened Duo); the top menu also selects Basic or Scientific. History and calculator mode controls are visible in both modes. Left-handed alignment lives in the calculator mode menu.

Scientific uses Apple's documented six-column, five-row function arrangement, stacked above the basic keypad in portrait and beside it in landscape. It includes second functions, powers and roots, trig and hyperbolic functions and their inverses, logarithms, constants, random, EE notation, memory, nested parentheses, algebraic precedence, and degree/radian selection. Prefix functions and postfix application are supported. The display previews complete expressions as you type; History retains the last 100 successful calculations on this device and can recall or clear them.

Basic operations retain immediate execution and Decimal arithmetic where representable. Scientific calculations use Double precision rounded to 15 significant digits, with explicit domain/overflow errors; factorial supports nonnegative real inputs through 170 using gamma. Entry is limited to 15 digits. Tap the expression or result to edit with a native caret and selection, or recall history for editing. Convert supports 15 unit categories and 31 currencies through dated ECB rates from Frankfurter. Apple history/Notes synchronization is not included. Math Notes is intentionally excluded. Currency conversion fetches public rates over HTTPS and caches them on this device; entered amounts stay on-device. The app has no advertising or external package dependencies.

## Build

Requires Xcode and iOS 17 or later. Open `Calculator.xcodeproj`, select the Calculator scheme and an iPhone simulator, then Run. To run on a physical iPhone, select your own development team in Signing & Capabilities and use your own device provisioning. No development account is embedded.

Simulator tests:

```sh
xcodebuild -project Calculator.xcodeproj -scheme Calculator \
  -destination 'platform=iOS Simulator,name=Calculator Duo Layout QA' \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
```

Use an available simulator name on another Mac.

## Prior release — November 10, 2026

- Built and ran with Xcode 27.2 on an iPhone Duo simulator running iOS 27.1.
- 15 tests passed: 13 model/layout tests and 2 UI tests, including rotation, all 20 keys, basic input, button size and centering.
- Unsigned generic iOS device build succeeded. This verifies compilation, not phone installation.
- The included preview is an actual simulator capture, not a mockup.
- App Store distribution signing and internal-only TestFlight export succeeded for version 1.0 (2). Apple processed it as VALID / INTERNAL_ONLY; TestFlight state is IN_BETA_TESTING. Kyle is the sole invited internal tester, with automatic build distribution enabled. Physical-device installation has not been performed. No App Store review submission or public release has been made.
- App Store Connect listing: Calculator Duo by Kyle (6833205141). The phone display name remains Calculator Duo. The internal bundle name is CalculatorDuoByKyle to avoid Apple’s reserved-name validation error.
- All 15 simulator tests passed again after final package metadata changes. Release evidence and signed packages are retained locally under QA/testflight-20261110/.

## Version 1.0 (3) update

- Right-hand alignment by default, persistent left-handed setting, unchanged basic Duo button dimensions.
- Adaptive scientific keypad with degrees/radians; no reset of calculations when changing layout.
- Math Notes feasibility: PencilKit handwriting recognition and PaperKit canvas APIs are building blocks, but Apple does not document an embeddable Math Notes solver, graphing engine, or Notes integration. No incomplete substitute is shipped.
- Scientific calculations are immediate-execution, not an algebraic expression editor.
- QA and release evidence for this update are under `QA/testflight-3/` and the scientific test result bundles.

Verification for build 3: all 23 automated tests passed in `QA/ScienceReleaseChecks.xcresult` (21 model/layout and 2 UI), including scientific sin/square, degree-radian toggle, rotation back to basic, and left-handed setting. Signed device archive and internal-only export validated with codesign. Open Duo portrait/landscape were visually inspected in DeviceHub. Closed → Open → Closed was verified, retaining the entered value 42 and switching between basic and scientific layouts. Apple processed build 3 as VALID / INTERNAL_ONLY. Its internal TestFlight state is IN_BETA_TESTING, with automatic notification enabled and membership in the existing Internal group verified. No external testing or public release was submitted.

## Version 1.0 (4) clipping fix

- Bounds the calculator to its safe viewport and reserves a 16-point bottom gutter. Layout sizing now accounts for the full display, keypad, spacing, and scientific toolbar rather than approximate height reserves.
- Keeps Settings hidden in basic mode. Rotate or unfold to scientific mode to access the left-handed preference.
- All 24 automated tests pass, including complete key-frame bounds, scientific-only Settings, left-handed return to basic, and 288 viewport/mode combinations. Signed 1.0 (4) archive and internal-only export verified.
- Live Duo QA also passed closed portrait, open scientific, closed landscape, and left-handed layout, with 42 retained through fold/rotation/settings changes. Every mode has clear bottom/right margins. Evidence is retained under `QA/testflight-4/`.
- Apple processed build 4 as VALID / INTERNAL_ONLY, with internal TestFlight state IN_BETA_TESTING and automatic notification enabled. Membership in the existing Internal group is verified. No public submission was made.

## Version 1.0 (5)

- Replaced the earlier custom scientific subset with the full 30-key scientific arrangement and second functions, based on Apple's iOS 27 scientific guide screenshot. Added scientific expression precedence, nested groups/functions, EE, memory, live previews, and persistent history.
- Preserved basic Duo key sizes, right/left alignment, safe-area clipping fixes, and scientific-only top controls. Scientific keys use capsules and adapt to portrait/landscape without dropping controls.
- References: https://support.apple.com/en-gb/guide/iphone/iphb977c4c0e/27/ios/27 and https://ios.gadgethacks.com/how-to/20-hidden-calculator-tricks-for-your-iphone-0384162/ (second-key mapping).
- No Math Notes implementation or public App Store submission.

Build 5 verification: 47 tests passed (43 model/layout and 4 UI), with the four UI tests rerun after final display refinement. Manual Duo checks passed closed/open/landscape layouts, unclipped controls, 42 retained through transitions, second functions, context-menu handedness, history, and basic live preview. Apple processed 1.0 (5) as VALID / INTERNAL_ONLY / IN_BETA_TESTING, with auto-notification and existing Internal group membership verified. No physical-phone installation or public submission was performed. Build/release evidence is retained locally under QA/testflight-5/.

## Version 1.0 (6)

- Inline expression editing with native cursor movement, word selection, keypad replacement, safe parsing, live reevaluation and history recall. Parentheses, scientific operators/functions and calculator-style percentages round-trip through the parser.
- Reference-style circular history/sidebar and calculator controls in both modes. The checked Basic/Scientific menu includes Left-handed instead of Math Notes, plus functional Convert. Landscape history opens alongside the calculator, with dated groups and edit/delete controls.
- Convert includes Angle, Area, Currency, Data, Energy, Force, Fuel, Length, Power, Pressure, Speed, Temperature, Time, Volume and Weight. Currency uses daily ECB rates from https://api.frankfurter.dev, shows the rate date, caches prior data and clearly reports unavailability rather than inventing rates. Coverage follows the provider's 31 supported currencies; this is not Apple's currency data service.
- The requested four-column basic Duo layout remains intentional, even though Apple's stock Duo reference uses five columns. Basic diameter and safe margins remain preserved where the viewport allows.

Build 6 verification: all 77 automated tests passed (70 model/parser/conversion and 7 UI). Manual Duo checks passed native selection/caret edits, live results, searched unit selection, exact unit swap round trip, portrait history and landscape sidebar, mode/handedness menu, folding/rotation retention and unclipped controls. Apple processed 1.0 (6) as VALID / INTERNAL_ONLY / IN_BETA_TESTING; auto-notification and existing Internal group membership were verified. No physical phone installation or public App Store submission was performed.

## Version 1.0 (7): expression display and sizing

- Entry shows the complete expression in the large primary line. Equals moves that expression into the smaller line above the large result. Long lines scroll horizontally without deleting input; tapping still opens the native caret/selection editor. Live numerical previews remain an intentional app feature.
- Basic and scientific keypad entry now share standard precedence, matching editable expressions rather than showing `2+3×4` while calculating a sequential result. Repeat equals retains the previous operation when a new number is entered, as documented in Apple's Basic Calculator guide.
- Operators keep their orange styling instead of showing a persistent selected highlight. Keys use the available viewport rather than a reference-size cap, with tighter gaps and a 4-point gutter inside the bottom safe area. Camera and home-indicator safe areas remain respected.
- Apple references: https://apps.apple.com/us/app/calculator/id1069511488, https://support.apple.com/guide/iphone/use-the-basic-calculator-iph1ac0b5cc/27/ios/27 and https://support.apple.com/en-nz/guide/iphone/iphb977c4c0e/27/ios/27. These support full-expression calculation, repeat equals and scientific precedence, but do not establish exact parity for all gestures or the live numerical preview.

Source verification: 73 unit/model/parser/conversion/layout tests and 7 UI tests passed in native portrait/landscape batches. Long-expression scrolling preserved input and equals produced 6,175 for five 1,234 terms plus 5. The synthetic XCUIDevice rotation test did not drive this Duo simulator reliably; native Device Hub rotation/folding was checked separately: closed portrait, closed landscape, open portrait and open landscape retained `4+2 = 6`, kept controls unclipped, and restored Basic when upright/closed. Both left/right alignment and the nonsticky orange operator styling were visually checked. Internal release status is recorded separately after Apple processing.

Build 7 release verification: Apple processed 1.0 (7) as VALID / INTERNAL_ONLY / IN_BETA_TESTING, with auto-notification enabled and the existing Internal group membership verified. Signed archive/export and deep strict signature checks passed. No physical-phone installation or public App Store submission was performed.

## Version 1.0 (8): clear-entry and display refinements

- C clears the current operand without inventing a zero: `595+65` becomes `595+`, and the next digit replaces the cleared operand. Incomplete parenthesized operands cannot be silently closed or calculated, including through memory helpers.
- Removed numerical preview lines during entry and native editing. Equals still shows the completed expression above the result.
- The expression uses the available safe screen width independently of the keypad and scrolls horizontally, with a leading fade when earlier content is offscreen. Landscape scientific mode reserves space for the angle-unit label.
- Reclaims excess home-indicator spacing for larger keys while preserving a 20-point bottom clearance on the ordinary 34-point inset; larger camera insets remain untouched.

Source QA: 76 unit/model/layout tests and 8 UI tests passed in native portrait/landscape batches, covering clear/replacement, full-width scrolling, scientific operations, history, native editing/selection and conversion. Closed portrait, closed landscape and expanded portrait were visually checked for clipping. The existing synthetic rotation test remains unreliable on the Duo simulator and was not counted. Internal-release status is recorded separately after Apple processing.
