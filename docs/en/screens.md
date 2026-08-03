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
| Knowledge | `/knowledge` | Documents and skills the agents consult |
| Explore | `/explore` | Resources shared by the community |
| Labels | `/labels` | Organizing your own resources |
| Manager | `/manager` | Workspaces, groups and invitations |
| Profile | `/profile` | Account, preferences and language |

The dashboard lets you reorder its blocks: once edit mode is on, the layout is saved to the account and travels with the user to any device.

Agents have their own conversation view, available once the agent has a connection assigned.

---

## Administration

Visible only to accounts with the administrator role.

| Screen | Address | What it does |
|---|---|---|
| Administration | `/admin` | Users, resources and their ownership |
| Metadata | `/admin/metadata` | Platform catalogs |
| Centinel | `/admin/centinel` | Monitoring and stress testing |
| Logs | `/admin/logs` | System activity |
