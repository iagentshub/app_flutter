<div align="center">
  <a href="index.md">← Index</a> &nbsp;·&nbsp;
  <a href="../es/architecture.md">🇪🇸 Ver en Español</a>
</div>

<br>

# App Architecture

---

## Overview

The application is written in Flutter, so a single codebase produces the app for Android, iOS, web, Windows, macOS and Linux. It holds no data of its own: everything it shows comes from the iAgentsHub backend, and only the session and preferences stay on the device.

The code is organized by **functional area**, not by file type. Each area of the platform — agents, knowledge, memory, connections… — is its own folder under `lib/features/`, keeping its screens and its data access together. Whatever several areas share lives in `lib/shared/`.

---

## Incremental loading

`core/network/page_result.dart` is the shared HTTP page contract and reads
`X-Total-Count`, `X-Has-More`, and `X-Next-Cursor`. Repositories expose page
operations for long views and fetch all pages only for pickers that genuinely
need the complete accessible catalog.

Knowledge loads offset pages near the end. Chat loads conversations by cursor
and prepends older messages while preserving scroll position. Server-backed
collections use builders/slivers so only visible elements are built.

The Skills, Prompts, and Tools tabs do fetch every page on purpose: they filter
by category or language on the client, and a single page would yield incomplete
results with no way to tell. Paginating them requires those filters to exist
server-side first.

A listing's skeleton — refresh, toolbar, lazy grid, empty state, and next-page
loading — lives in `shared/widgets/resource_collection_view.dart` and backs all
ten collection screens. Views that paint several collections in one scroll
(connections grouped by provider) take `ResourceGridSliver` alone.

A collapsed group must not build what it does not show either:
`shared/widgets/lazy_expansion_tile.dart` defers its content until expansion,
because Material's `ExpansionTile` always builds children and merely hides
them. It backs the official import review and Centinel's test tree, where each
group holds dozens of rows with dropdowns.

On the web there is a second level of incremental loading: **the code for the
heavy sections does not travel in the initial download**. Administration —
Centinel included —, the visual orchestration editor and the checkout are
fetched when you enter them, not when the app opens, because they are the
largest areas and a minority uses them. The first visit shows a loading
indicator and, if the download fails, a retry button; later visits are
immediate. Off the web there is nothing to download and behaviour is unchanged.

State follows one convention instead of a state-management library: `setState` only for
widget-local state, one controller per feature for shared state, and **nobody reloads by
hand after mutating**. `ApiClient` invalidates its cache and emits a `ResourceEvents`
change for the touched resource — derived from the path — while pages declare what they
watch through the `WatchesResourceChanges` mixin and reload on their own, including when
another screen made the change. `test/feature_architecture_test.dart` rejects reloading by
hand after a mutation, and `CLAUDE.md` carries the convention.

## The four layers

**Screens** (`lib/features/*/pages/`) — what the user sees and touches. They never talk to the network directly.

**Repositories** (`lib/features/*/repositories/`) — the only way out towards the backend. Each one groups the operations of its area and returns models ready to render.

**HTTP client** (`lib/core/network/`) — a single point every request goes through. It builds the address, attaches the session, interprets the response and reports when the server is unreachable.

**Shared state** (`lib/shared/state/`) — session, selected server, language and dashboard edit mode. Each notifies the interested screens when it changes.

---

## Startup

Opening the app restores three device-stored things in parallel: the session, the selected server and the language. Parallel on purpose — they are independent of each other, and chaining them made startup longer for no reason. A splash screen shows meanwhile.

Once done, the app decides where to land: the dashboard if the session is valid, the public screen otherwise.

---

## Navigation

Internal addresses mirror the web ones (`/dashboard`, `/agents`, `/knowledge`…), so a link means the same thing in the browser and in the app.

Routes split into **public** — landing, pricing, documentation, support, public profiles, and the whole sign-in flow — and **private**, which require a session. Reaching a private one without a session redirects to sign-in.

---

## Languages

The app ships in Spanish and English. Texts are not written inside the screens: they live in separate translation files per language and per area, loaded on demand the first time they are needed. Switching language requires no restart.

English routes carry the `/en` prefix, same as on the web.

---

## Design decisions

**No code generation** — there is no intermediate build step for models or translations. This buys simplicity and a faster project setup; the price is hand-written parsing of the responses.

**State with Flutter's own tools** — no external state management library. The shared pieces are few and are passed explicitly where needed, which makes it obvious what depends on what.

**A single door to the network** — concentrating every request in one place makes it possible to cache listings, detect a server outage and switch backends without touching the rest of the app.

**Short-lived listing cache** — listing queries are remembered for a minute so they are not repeated every time a view is revisited. Any change the user makes to that resource discards the stored copy immediately.
