# Clawuno

**The Agent OS for professional individuals and teams.**

Clawuno lets you build, run, and manage AI agents that execute real work — autonomously, on your own machine.

---

## Install

### macOS — Apple Silicon app

Download the signed DMG from [clawuno.com](https://clawuno.com), open it,
and drag Clawuno to Applications. Clawuno 0.8.0 and later require Apple Silicon;
the 0.7.x line is the final Intel-compatible release.

### Linux — One-click

```bash
curl -fsSL https://releases.clawuno.com/install.sh | bash
```

### Windows — Desktop app

Download the signed Windows x64 Setup from [clawuno.com/download/windows](https://clawuno.com/download/windows) and run it directly. The single installer contains Desktop, WebView2, EngineHost, and Engine; no ZIP extraction, PowerShell script, system Node.js, or separate Engine installation is required.

**Requirements:**

- macOS: Apple Silicon with macOS 13.5 or later.
- Windows: Windows 11 x64. The installer includes all required app and Engine runtimes.
- Linux: a supported x64 Linux distribution with Docker Engine and the Docker Compose plugin.

No external database or system Node.js is required.

---

## Upgrade

The macOS and Windows apps update through their built-in updaters. Linux installations
upgrade through the host `clawuno` command. Upgrades preserve data and configuration.

The first Windows Desktop release is a one-time transition from the 0.8.0 Engine-only package. Its old `clawuno upgrade` command cannot install the new Setup EXE: uninstall the old program while preserving `%USERPROFILE%\clawuno`, then run the signed Windows Setup. Later Windows Desktop versions update in the app.

---

## Linux Engine CLI Reference

These commands are provided by the Linux Docker host deployment. macOS and Windows Desktop users manage installation and updates from the app instead.

```bash
clawuno start       # Start the service
clawuno stop        # Stop the service
clawuno restart     # Restart the service
clawuno status      # Show version, port, and running state
clawuno logs        # Tail the application log
clawuno doctor      # Diagnose and auto-fix common issues
clawuno upgrade     # Upgrade to the latest version
clawuno upgrade /path/to/clawuno-*.tar.gz   # Upgrade from a local file
```

### Troubleshooting

If Clawuno is not working as expected, run:

```bash
clawuno doctor
```

On Linux Engine deployments, this checks for common issues and applies safe automatic fixes (stale processes, missing permissions, unloaded services, port conflicts with its own old processes). Additional modes:

```bash
clawuno doctor --check      # Diagnose only, no fixes
clawuno doctor --fix        # Interactive fixes (e.g. port conflicts with other apps)
clawuno doctor --report     # Generate a redacted diagnostic report for support
```

When reporting an issue, attach the diagnostic report file from the `diagnostics/` directory of your Clawuno install.

---

## Releases

All releases are available on the [Releases page](https://github.com/clawuno/clawuno/releases).

Each release includes platform-specific packages:

| Platform | File |
|----------|------|
| macOS Apple Silicon | Signed DMG from [clawuno.com](https://clawuno.com) |
| Linux x64 | `clawuno-{version}-linux-docker.tar.gz` |
| Windows x64 | Signed `Clawuno-{version}-windows-x64-Setup.exe` from [clawuno.com/download/windows](https://clawuno.com/download/windows) |

---

## Documentation

- [Getting started](https://clawuno.com/docs)
- [Changelog](CHANGELOG.md)

---

## Anonymous Usage Data

Clawuno sends a small amount of anonymous data to help us understand how the
product is used and prioritize improvements. We collect:

- A randomly generated installation ID (UUID)
- Your operating system and architecture (e.g. `darwin` / `arm64`)
- Your Clawuno version
- Country code, derived from your IP address at request time

We do **not** collect, log, or store:

- Your IP address (used only momentarily by our edge to derive country, then discarded)
- Your name, email, or any account information
- Anything from your sessions, agents, workspaces, or files

Three events are sent: when an installation starts, when the first admin is
created (= installation succeeded), and after each successful upgrade. Data is
stored on Cloudflare D1 in the European Union.

On Linux Engine deployments, disable telemetry with:

```bash
clawuno telemetry off
```

To re-enable it, run `clawuno telemetry on`. To view the current state, run `clawuno telemetry`. macOS and Windows Desktop do not install a global `clawuno` CLI by default.

---

## Security

To report a security vulnerability, see [SECURITY.md](SECURITY.md).

---

## License

Copyright © Clawuno. All rights reserved.
