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

### Windows — One-click (PowerShell)

```powershell
irm https://releases.clawuno.com/install.ps1 | iex
```

### Windows — Download from GitHub Releases

Download `install.ps1` and the Windows x64 package from the [Releases page](https://github.com/clawuno/clawuno/releases/latest), then run:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 clawuno-{version}-windows-x64.zip
```

The `-ExecutionPolicy Bypass` flag is required for locally downloaded scripts on Windows. The one-click `irm | iex` method above does not need this because it runs the script via pipeline.

**Requirements:** Apple Silicon with macOS 13.5+, Windows 10+ x64, or a supported x64 Linux distribution. No Docker, external database, system Node.js, or install-time runtime download is required.

---

## Upgrade

The macOS app updates through its built-in updater. Linux and Windows installations
can run `clawuno upgrade`. Upgrades preserve data and configuration.

---

## CLI Reference

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

This checks for common issues and applies safe automatic fixes (stale processes, missing permissions, unloaded services, port conflicts with its own old processes). Additional modes:

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
| Linux x64 | `clawuno-{version}-linux-x64.tar.gz` |
| Windows x64 | `clawuno-{version}-windows-x64.zip` |

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

To disable:

```bash
clawuno telemetry off
```

To re-enable: `clawuno telemetry on`. To view current state: `clawuno telemetry`.

---

## Security

To report a security vulnerability, see [SECURITY.md](SECURITY.md).

---

## License

Copyright © Clawuno. All rights reserved.
