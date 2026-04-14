# Clawuno

**The Agent OS for professional individuals and teams.**

Clawuno lets you build, run, and manage AI agents that execute real work — autonomously, on your own machine.

---

## Install

### macOS — One-click

```bash
curl -fsSL https://releases.clawuno.com/install.sh | bash
```

### macOS — Download from GitHub Releases

Download `install.sh` and the package for your Mac from the [Releases page](https://github.com/clawuno/clawuno/releases/latest), then run:

```bash
# Apple Silicon (M1/M2/M3)
bash install.sh clawuno-0.6.8-macos-arm64.tar.gz

# Intel
bash install.sh clawuno-0.6.8-macos-x64.tar.gz
```

### Windows — One-click (PowerShell)

```powershell
irm https://releases.clawuno.com/install.ps1 | iex
```

### Windows — Download from GitHub Releases

Download `install.ps1` and `clawuno-0.6.8-windows-x64.zip` from the [Releases page](https://github.com/clawuno/clawuno/releases/latest), then run:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 clawuno-0.6.8-windows-x64.zip
```

The `-ExecutionPolicy Bypass` flag is required for locally downloaded scripts on Windows. The one-click `irm | iex` method above does not need this because it runs the script via pipeline.

**Requirements:** macOS 12+ or Windows 10+. No Docker, no external database, no Node.js required — the installer is self-contained.

---

## Upgrade

```bash
clawuno upgrade
```

Detects the latest version, downloads, and upgrades in place. All your data and configuration is preserved.

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
| macOS Apple Silicon | `clawuno-{version}-macos-arm64.tar.gz` |
| macOS Intel | `clawuno-{version}-macos-x64.tar.gz` |
| Windows x64 | `clawuno-{version}-windows-x64.zip` |

---

## Documentation

- [Getting started](https://clawuno.com/docs)
- [Changelog](CHANGELOG.md)

---

## Security

To report a security vulnerability, see [SECURITY.md](SECURITY.md).

---

## License

Copyright © Clawuno. All rights reserved.
