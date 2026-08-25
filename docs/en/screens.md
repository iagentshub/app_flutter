<div align="center">
  <a href="index.md">← Index</a> &nbsp;·&nbsp;
  <a href="../es/screens.md">🇪🇸 Ver en Español</a>
</div>

<br>

# Screens

The app covers the same sections as the web. Each one lives at its own address, just like in the browser.

---

## Public

Reachable without an account.

| Screen | Address | What it does |
|---|---|---|
| Landing | `/` | Platform overview |
| About | `/about` | What iAgentsHub is |
| Documentation | `/docs` | Usage guides |
| Pricing | `/pricing` | Available plans |
| Support | `/support` | Help channels |
| Public profile | `/u/<user>` | Someone's public page |
| Checkout | `/checkout` | Signing up for a plan |

Each has its English twin under the `/en` prefix.

---

## Sign-in

| Screen | Address | What it does |
|---|---|---|
| Sign in | `/login` | Account access, guest access, or GitHub (if the server has the OAuth App configured) |
| Register | `/register` | New account |
| Forgot password | `/forgot-password` | Recovery request |
| New password | `/reset-password` | Change via the emailed link |
| Verification | `/verify` | Account confirmation |
| Server | `/backend` | Choosing which server to connect to |
| VS Code link | `/vscode-auth` | Authorizing the VS Code extension |

---

## Signed in

| Screen | Address | What it does |
|---|---|---|
| Dashboard | `/dashboard` | Home view, with reorderable blocks |
| Agents | `/agents` | Create, edit and chat with agents |
| Orchestrations | `/orchestrations` | Chain agents into a flow, with a visual editor |
| Connections | `/connections` | AI, machine and database credentials, plus a Providers tab to link external accounts (Anthropic, OpenAI, GitHub Copilot, Ollama, NVIDIA, Google) and choose which models to bring in; Ollama connections can discover models live, and iAgents Hub connections can sync with the remote hub |
| Memory | `/memory` | What the agents remember |
| Knowledge | `/knowledge` | Skills, Prompts, Tools, Documents, and Memory used by agents |
| Explore | `/explore` | Community resources with type, category, language, and label filters |
| Labels | `/labels` | Collapsible catalog and search for labels on your own resources through the shared toolbar and filter dialog, including content language |
| Manager | `/manager` | Workspaces, groups and invitations |
| Profile | `/profile` | Account, preferences and language |

The dashboard lets you reorder its blocks: once edit mode is on, the layout is saved to the account and travels with the user to any device.

Agents have their own conversation view, available once the agent has a connection assigned.

Textual resources accept zero or more optional content languages. The compact
multi-select is available when editing agents, skills, prompts, Knowledge text,
URLs or documents, and workflows. Selecting none means that language does not
apply or was not declared. Tools keep their programming language (Python,
Shell, or C++) separate from content language. Explore and Labels reuse the
Admin type dropdown and render multiple filters as dropdowns instead of rows of
buttons.

### Tools on the device

A Tool may provide instructions and also a Python/Shell script or a native
artifact historically identified as `cpp`. The app obtains the runtime catalog
from the backend, checks operating-system and architecture compatibility, and
verifies SHA-256 while downloading a binary.

Automatic local execution is not enabled yet. A compatible Tool is one the
device will be able to run once an isolated executor with explicit permissions
exists; today it teaches the agent how to perform the task and provides its
authorized implementation for download. The existing `review`, `approved`, and
`quarantine` labels determine whether it can be shared or consumed.

---

## Administration

Visible only to accounts with the administrator role.

| Screen | Address | What it does |
|---|---|---|
| Administration | `/admin` | Users, resources and their ownership |
| Metadata | `/admin/metadata` | Platform catalogs |
| Centinel | `/admin/centinel` | Monitoring and stress testing |
| Logs | `/admin/logs` | System activity |
