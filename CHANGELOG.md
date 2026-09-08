# Changelog

All notable changes to Clawuno are documented here.

---

## v0.8.0 — 2026-09-07

### New

- **Clawuno Anywhere for Feishu** — Connect organization bots, bind Uno in
  direct chats, run multiple agents in group chats, and follow live progress
  with recoverable setup diagnostics and permission checks.
- **Unified workspace shell** — Global Agents navigation, expandable Chat and
  Work activity, linked local folders, workspace rename, multiple Mini Apps,
  unified Files/Mini App/Browser/Git tabs, and a compact mobile experience.
- **Workspace Browser and Git** — Built-in browser runtimes provide agent web
  access and native macOS browser tabs with isolated profiles; Git status, diffs, staging, commits,
  nested repositories, and safe local branch switching are built into the
  workspace.
- **Richer document work** — Continuous Office preview, legacy Office format
  support, managed authoring runtimes, Excalidraw preview/edit/autosave/export,
  and built-in Office and visual-design skills.
- **Human-in-the-loop agent runs** — Durable interaction requests, multi-question
  cards, attention updates, chat forking, generated chat titles, compact run
  timelines, and on-demand tool details.
- **More capable Uno** — Per-user system identity, multiple chats, floating and
  sidecar modes, active-workspace switching, workspace-aware UI navigation,
  starter prompts, inbox, profiles, and Work notifications.

### Improved

- Agent definitions are global by default and can optionally be restricted to
  selected workspaces; legacy workspace agent definitions migrate safely.
- File editing coordinates user, agent, and external changes with revision-aware
  autosave and conflict handling.
- Installation and upgrades use signed manifests, transactional generations,
  complete bundled LibreOffice/Managed Chromium artifacts, safer backups, and
  hardened cross-platform release gates.

### Fixed

- Extensive fixes across Mac engine supervision, Browser profile isolation,
  Feishu reply deduplication, group-chat timelines, workspace navigation,
  Office/whiteboard synchronization, uploads, and agent runtime recovery.
- Sparkle build numbering supports upgrades from the previously published Mac app.

### Compatibility

- The Mac app now requires **Apple Silicon and macOS 13.5 or later**. Version
  0.7.x is the final Intel-compatible line, and Intel installations are excluded
  from 0.8.0 automatic updates. Linux x64 and Windows x64 remain supported.
- Linux is distributed through Docker, with bundled runtimes, a non-root Engine,
  persistent instance data, and isolated multi-instance deployment.

## v0.7.2 — 2026-07-06 (macOS only)

### New

- **Native macOS app** — Clawuno now ships as a signed, notarized
  DMG. The app owns Clawuno's lifecycle: launch it to start Clawuno,
  quit it to fully stop the engine. Splash screen while the engine
  boots, tray icon reflects engine state, standard menu bar with
  Check for Updates and Uninstall.
- **Resumable large-file uploads** — Uploads survive network hiccups
  and browser reloads via tus protocol, up to 5 GB per file.
- **Fullscreen workspace + multi-tab file browser** improvements
  carried over from ongoing work.

### Fixed

- Numerous reliability, upload, chat scroll, model discovery, and
  agent-switch fixes.

---

## v0.7.1 — 2026-05-14

### New

- **Multi-tab file browser in Workspace** — Open multiple files in tabs with full-screen mode.
- **Work / Run redesign** — Each Work has its own run history; re-run finished or failed works directly.
- **Uno per-user home directory** — Each user now has a personal Uno workspace.
- **Uno as work executor** — Uno can be assigned as the executing agent for works.
- **Uno Panel improvements** — View Uno work sessions, slide-out settings, Memory view/edit toggle.
- **Agent UI enhancements** — Memory + Reflections tabs, runtime stats, capability chips.
- **Time & timezone contract** — Agents interpret user-mentioned times in deployment timezone by default.
- **Web Fetch upgrades** — Markdown preserves images, tables, captions; new `mode=browser` for full-rendering sites.
- **MCP system alignment** — Local manifest and Forge registry env vars match the official MCP registry schema.

### Fixed

- Various stability and reliability improvements.

---

## v0.7.0 — 2026-04-21

### New

- **macOS Intel (x64) support** — Clawuno now runs on Intel Macs
  starting from macOS 11 (Big Sur). The installer automatically
  picks the right package for your architecture.

### Fixed

- Various bug fixes and stability improvements.

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
