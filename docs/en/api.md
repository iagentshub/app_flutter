<div align="center">
  <a href="index.md">← Index</a> &nbsp;·&nbsp;
  <a href="../es/api.md">🇪🇸 Ver en Español</a>
</div>

<br>

# Backend connection

---

## Which server it uses

The app is not tied to one server. It ships with a built-in one — `www.iagentshub.com` — and lets you add others by hand from the server screen, giving a name and an address. That is what makes it possible to use the app against your own iAgentsHub installation without rebuilding it.

Built-in servers cannot be removed from the list; user-added ones can. The choice is stored on the device and survives closing the app.

---

## Availability check

Before saving a new server you can check whether it responds. The server list is also revisited periodically, so the user can see which one is reachable without having to try signing in.

The app tells apart two situations that are easily confused:

- **The server answers with an error** (invalid credentials, permission denied, missing resource). That is a legitimate response and is shown as the specific error it is.
- **The server does not answer** (no network, wrong address, service down). Only this case is reported as a connection problem.

Keeping them apart avoids the most typical silent failure: presenting a permissions error as if the server were down, or the other way round.

---

## Session

On sign-in the backend returns a session token that the app stores on the device and attaches to every later request. It is the same mechanism the web uses.

If "remember" is unchecked at sign-in, the session lives only while the app is open and, on top of that, any previously stored session is cleared so it cannot be reused by mistake. Guest access behaves the same way.

Signing out clears the token and the cached trace of the queries made with it.

---

## What it asks the backend for

The app consumes the public iAgentsHub API. By family:

| Family | What for |
|---|---|
| `auth`, `users`, `settings` | Access, account and preferences |
| `agents`, `chats` | Agents and their conversations |
| `workflows` | Orchestrations |
| `connections` | AI, machine and database credentials (includes discovering Ollama models and syncing with another hub) |
| `accounts` | Linked provider accounts (Anthropic, OpenAI, GitHub Copilot, Ollama, NVIDIA, Google): link, test and sync models as connections |
| `knowledge`, `skills`, `prompts`, `tools`, `resources` | Reusable content, Tools, and their versions |
| `memory` | Agent memory |
| `workspaces`, `sharing` | Workspaces, groups and sharing |
| `explore`, `feed` | Discovery and activity |
| `billing` | Plans and payments |
| `admin` | Administration tools |

For Tools, the app consumes `tool_runtimes` from the server's public settings;
it does not keep a local language list. Binary downloads are streamed and their
SHA-256 is verified. The backend never executes a Tool, and automatic local
execution in Flutter is still pending.

---

## Cache

Listing queries are kept in memory for one minute: returning to a just-visited view does not repeat the request. Same spirit as the freshness window in the web frontend.

Two details matter:

- A stored entry is bound to the session that requested it. Switching accounts never serves the previous one's data.
- Any operation that modifies a resource invalidates that resource's cached copy immediately, so a change made from the app shows up right away.

The cache is memory-only: closing the app empties it completely.
