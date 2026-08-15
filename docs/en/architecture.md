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
