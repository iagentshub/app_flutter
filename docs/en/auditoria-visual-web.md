# Flutter web visual audit

Date: 5 September 2026. This is the English companion to the [screen-by-screen Spanish audit](../es/auditoria-visual-web.md). Scope: Flutter web, preserving the brand, color palette and native mobile presentation. React marketing pages and backend changes are outside this audit.

## Findings

The shared shell already provides a common foundation. Individual screens still introduce different widths, tab margins and action rows. Fix shared components first, then validate each screen's exceptions. Empty conversation space is useful for incoming messages; duplicate margins, isolated metric tiles and unreachable actions are defects.

## Shared design rules

- One application shell, navigation order and active state, respecting role visibility.
- Consistent editor headers, surfaces, icons, buttons and overflow menus.
- Collection width limited to 1600 px; agent forms and AI builders to 1280 px on web. Message reading width remains separate.
- Search and actions share a row when they fit, wrapping without losing focus.
- Web cards use 16 px spacing and equal heights within each row, with aligned action footers.
- Layout decisions use local constraints and text scaling. Native variants remain unchanged.

## Implementation

The first revision added the shared web frame and theme, stable sidebar animation, labeled create actions, responsive toolbars, aligned agent/connection cards, balanced dashboard metrics and constrained empty states. Agent and skill builders now share a width and responsive connection controls. Suggestions use columns. Chat history access uses local web width.

The implementation pass extends shared card bodies and wrapping action footers to skills, prompts, tools, documents, packs and memory. Manager receives the common toolbar; Labels and Profile adopt the same web tab margins as Knowledge and Administration. Agent connection settings receive a compact panel. Long builder drafts/errors have a bounded scrolling region so the composer remains available.

## Screen coverage and remaining work

The second pass fixes label groups overflowing when expanded inside equal-height rows. The catalog now opts out of row alignment while retaining its animation; other collections keep aligned rows. A regression test covers expansion and collapse. Image cards adopt the shared web body/footer, graph buttons use a centralized icon, and the workflow inspector uses 30% of web width (320–400 px) with text-scale-aware column selection. Static analysis is clean; 733 tests pass with one skipped. Full visual coverage of image/editor states remains pending.

| Area | Remaining validation |
|---|---|
| Dashboard | Custom widget combinations and long data. |
| Agents | Real pagination, sharing, imports, all form tabs, validation, graph/history dialogs. |
| AI builders | Real streaming, stop, draft review, errors, short windows and enlarged text. |
| Conversations | Markdown, attachments, mentions, preferences and history transitions. |
| Connections | Provider forms, inactive records and long metadata. |
| Workflows and LLM orchestration | Inspector widths, graph space, candidate panels and execution dialogs. |
| Knowledge and Memory | Every card type, permissions, loading/error states, images and nested margins. |
| Explore and official packs | Filters, imports, tabs and long headers. |
| Labels, Manager and Profile | Tabs, membership dialogs, sessions and role-dependent actions. |
| Public profile | Avatar, long names and empty resource collections. |
| Administration | General, Explore, official sources, configuration, import review, metadata/log tables and Centinel results. |
| Authentication | Login, registration, recovery/reset, verification, legal acceptance, backend setup, session recovery and VS Code authorization. |
| Checkout and not-found | Payment sandbox states, embedded content and return navigation. |

Public informational routes and legacy workflow/log routes redirect; they are not separate Flutter screen designs. Fixed dimensions in a dialog are risks to inspect, not proof of overflow without considering parent constraints.

## Acceptance and evidence

The third pass introduces responsive web account sections in Profile, content-sized log summary cards, local-width/text-scale-aware LLM orchestration columns and consistent graph action icons in Explore/Admin. Profile was inspected at desktop and narrow widths; logs at 1280 × 800 with large counters. All 733 tests pass with one skipped and static analysis is clean. Real streaming, workflow runs, account mutations, administrative detail states and payment sandbox checks remain open; the Spanish audit maintains the current pending list.

The fourth pass unifies action icons. Official import review and official pack graphs use the shared graph icon; the workflow editor, workflow cards and canvas nodes drop rounded variants for the `check`, `play_arrow`, `add` and `copy_outlined` icons used elsewhere; the builder composer sends and stops with the same icons as the agent chat; sidebar close, footer About, preferences and pack sync adopt the majority variant. Edit, delete, share and export were already uniform. A structural test fails if any retired variant reappears. All 734 tests pass with one skipped, static analysis is clean and the release build stays within budget (`main.dart.js`: 5,415,341 bytes). These icons do not depend on `kIsWeb`, so VM tests render them; no dedicated visual check was made for this pass.

The fifth pass removes the last five dialogs with literal content sizes (official import tool review and relations, workflow run history, Centinel history, graph quick view) in favour of the shared `dialogContentWidth`/`dialogContentHeight` helpers, so they fit 360 px wide and 600 px high windows. Wide tables in metadata, logs, table data and Centinel results now use `WideTable`, which keeps a single, always-visible horizontal scrollbar on desktop; chip strips and chat code blocks keep their plain scroll. The 360 px run detail column only appears in the ≥ 780 px row layout and the table data dialog uses maximum constraints, so neither was changed. Two guards: no literal dialog sizes in `lib/`, and one scrollbar with full scroll extent at 400 px on Windows. 736 tests pass with one skipped, analysis is clean and the release build stays within budget (`main.dart.js`: 5,415,365 bytes).

The sixth pass covers keyboard and focus. Shared controls are built on Material focusable primitives, tabs use `TabBar`, sidebar items carry a `focusColor`, and Escape closes any `showAppDialog` dialog with focus returning to the opener; these were verified without changes. Two defects were fixed: Enter in the login password field now submits (and Enter in the username moves to the password), and ten form dialogs now autofocus their first field like invite, labels, packs and run workflow already did; dialogs that start with another control, the memory editor and search fields deliberately keep the default. Add URL also submits on Enter. A skip-to-content link and real-data state checks remain open. `test/teclado_y_foco_test.dart` guards the dialog focus/Escape flow and the login Enter path (it failed before the fix). 738 tests pass with one skipped, analysis is clean and the release build stays within budget (`main.dart.js`: 5,415,694 bytes).

The ninth pass is a product decision: the Profile › My account sections go back to a single column stacked top to bottom on every platform; the two-column web layout from the third pass spread the settings across the screen and was withdrawn on request. The tab returns to the profile reading width, and `WebSettingsLayout` becomes `SettingsStack` with no web branch. Analysis is clean for the touched files and the 86 profile tests pass.

The eighth pass fixes what the browser sweep found: on web the dashboard summary collapsed to one column at 360 px (native already gave two), so the minimum tile width drops from 160 to 140 px; and the sidebar clipped section names at 200% text, so its width now grows with the text scale up to 340 px. A `MediaQuery` wrapper the fixture used for text scaling stalled the release boot transition until a pointer event — a fixture artifact, not a product bug, and now applied only when a scale is requested. The sweep itself used an HTML frame loading the fixture in an iframe of the requested size (the automation could not resize the maximized window) and query parameters for route, language, theme and text scale: 360 and 768 px wide, 560 px high, 1024 × 560, light theme, English and 200% text all pass without overflow; 1920 px was not checked because the screen is 1360 px wide. 741 tests pass with one skipped and the release build stays within budget (`main.dart.js`: 5.415.632 bytes).

The seventh pass adds skip links to the wide web shell and fixes a keyboard trap found in the browser: in the release web build, Tab never left the page — it cycled through the page's controls and the sidebar was unreachable; a build without this pass reproduced it, and debug/VM behave differently, so the cause in Flutter's traversal order was not pinned down. The content scope now uses `parentScope` and there are two links: "Skip to content" in the shell corner, first in reading order, and "Go to menu" inside the page scope, which focuses the first menu control. Verified in Chrome with the release fixture. Administration › Configuration already lays out its sections in a responsive masonry grid, and the public agent picker (760 px) and official pack page (1100 px) keep their widths on purpose. A test reproduces the shell geometry with a nested Navigator and checks both links. 741 tests pass with one skipped, analysis is clean and the release build stays within budget (`main.dart.js`: 5,415,568 bytes). The browser pass covered four screens at 1440 × 900 in dark theme; window resizing through automation had no effect, so the other sizes, light theme, English and 200% text remain manual.

Check 360, 768, 1024, 1440 and 1920 px, a 600 px-high window, light/dark themes, Spanish/English and 200% text. Controls must remain reachable; only tables and canvases should intentionally scroll horizontally. Keyboard focus, selection and navigation state must survive resizing.

Visual checks use an ignored local fixture with synthetic data. They do not verify real AI services, payments or administrative mutations. VM widget tests do not execute `kIsWeb` branches. Automated Chrome tests failed to start in the first revision, so browser evidence is manual. The Spanish audit records the latest completed checks and remaining exceptions.

```powershell
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter build web --release --no-pub --no-web-resources-cdn
```
