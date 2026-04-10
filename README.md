# Clawuno

**The Agent OS for professional individuals and teams.**

Clawuno lets you build, run, and manage AI agents that execute real work — autonomously, on your own machine.

---

## Install

**macOS & Linux — one command:**

```bash
curl -fsSL https://releases.clawuno.com/install.sh | bash
```

Then open your browser at `http://localhost:9700`.

**Requirements:** macOS 12+ or Linux (x64/arm64). No Docker, no external database, no Node.js required — the installer is self-contained.

**Windows:** See [Windows installation](https://clawuno.com/docs/install#windows).

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
clawuno upgrade     # Upgrade to the latest version
clawuno upgrade /path/to/clawuno-*.tar.gz   # Upgrade from a local file
```

---

## Releases

All releases are available on the [Releases page](https://github.com/clawuno/clawuno/releases).

Each release includes platform-specific packages:

| Platform | File |
|----------|------|
| macOS Apple Silicon | `clawuno-{version}-macos-arm64.tar.gz` |
| macOS Intel | `clawuno-{version}-macos-x64.tar.gz` |
| Linux x64 | `clawuno-{version}-linux-x64.tar.gz` |
| Linux arm64 | `clawuno-{version}-linux-arm64.tar.gz` |

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
