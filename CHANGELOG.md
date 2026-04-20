# Changelog

All notable changes to Clawuno are documented here.

---

## v0.6.9 — 2026-04-20

### New

- **Agent-to-agent messaging** — Agents can now send messages to each
  other via the `agent_message` tool (send / status / wait semantics).
  The parent conversation embeds a foldable live view of the nested
  session so you can watch the exchange unfold in-context.

- **Uno unified inbox + timeline** — All notifications, agent messages,
  and system events are now surfaced in a single Uno-per-user inbox with
  type filters and an expandable detail view, replacing the older
  separate notification panel.

- **Self-evolution for agents (Beta)** — Agents can be given the
  `self_evolution_enabled` flag to improve their own prompt and skills
  after tasks complete. Uno can toggle the flag. Post-task evaluation
  runs an adversarial-first critic and feeds concrete improvements back
  into skills / memory.

- **System-wide token usage dashboard** — New dashboard page shows
  token consumption by agent and by day, with hover details, max-day
  scaled charts, and proper date labels.

- **`@` file-mention in Uno chat** — The same workspace file
  quick-insert that lives in Agent Chat is now available in Uno chat.

- **ChatGPT Subscription improvements** — Fully reworked model-config
  test UX and the ChatGPT connection panel; per-profile mutex prevents
  OAuth `refresh_token_reused` errors when multiple requests refresh
  the token simultaneously.

### Fixed

- Various bug fixes and stability improvements.

---

## v0.6.8 — 2026-04-14

### New

- **`@` quick-insert in Agent Chat** — reference workspace files directly from the composer.

### Fixed

- Various bug fixes and stability improvements.

---

## v0.6.7 — 2026-04-10

### New
- **Agent Chat image support** — attach images directly in Agent Chat for visual context and multimodal workflows
- **Uno custom skills** — Uno now supports user-defined skills, enabling personalized automation tailored to your workflow

### Improved
- Install scripts now show a real-time download progress bar (macOS/Linux and Windows)
- Windows installer supports local package mode: `.\install.ps1 clawuno-0.6.7-windows-x64.zip`
- macOS/Linux installer supports local package mode: `bash install.sh clawuno-0.6.7-macos-arm64.tar.gz`
- Release packages now available on [GitHub Releases](https://github.com/clawuno/clawuno/releases) as an independent download mirror

---

## v0.6.6 — 2026-04-08

_No release notes._

---

<!-- New releases are prepended above this line by publish-release.sh -->
