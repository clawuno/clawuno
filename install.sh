#!/bin/bash
# ============================================================================
# Clawuno — One-Click Installer
#
# This script is hosted at https://releases.clawuno.com/install.sh
# Users run it with:
#   curl -fsSL https://releases.clawuno.com/install.sh | bash
#
# What it does:
#   1. Detects platform (macOS arm64/x64, Linux x64/arm64)
#   2. Fetches latest version from releases.clawuno.com/latest.json
#   3. Downloads the release package and verifies SHA256
#   4. Runs install.sh from the package
# ============================================================================

set -euo pipefail

# ── Version comparison ────────────────────────────────────────
# version_gt A B — returns 0 (true) if A is strictly newer than B.
version_gt() {
  local a="$1" b="$2"
  local core_a core_b
  core_a="${a%%-*}"
  core_b="${b%%-*}"
  local IFS=.
  # shellcheck disable=SC2206
  local pa=($core_a) pb=($core_b)
  local i
  for i in 0 1 2; do
    local na="${pa[$i]:-0}" nb="${pb[$i]:-0}"
    if [ "$na" -gt "$nb" ]; then return 0; fi
    if [ "$na" -lt "$nb" ]; then return 1; fi
  done
  # Core equal: release > pre-release
  local a_pre b_pre
  a_pre=$(echo "$a" | grep -c '\-' || true)
  b_pre=$(echo "$b" | grep -c '\-' || true)
  if [ "$a_pre" -eq 0 ] && [ "$b_pre" -gt 0 ]; then return 0; fi
  return 1
}

RELEASES_BASE="https://releases.clawuno.com"
MANIFEST_URL="${RELEASES_BASE}/latest.json"

# ── Detect platform ───────────────────────────────────────────
OS_NAME=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$OS_NAME" in
  darwin) PLATFORM="macos" ;;
  linux)  PLATFORM="linux" ;;
  *)
    echo ""
    echo "ERROR: Unsupported platform: $OS_NAME"
    echo "  Clawuno supports macOS and Linux."
    echo ""
    exit 1
    ;;
esac

case "$ARCH" in
  x86_64)  ARCH_NORM="x64" ;;
  aarch64) ARCH_NORM="arm64" ;;
  arm64)   ARCH_NORM="arm64" ;;
  *)
    echo ""
    echo "ERROR: Unsupported architecture: $ARCH"
    echo ""
    exit 1
    ;;
esac

PLATFORM_KEY="${PLATFORM}-${ARCH_NORM}"

echo ""
echo "========================================"
echo "  Clawuno — Installer"
echo "========================================"
echo ""
echo "  Platform: $PLATFORM_KEY"
echo ""

# ── Check dependencies ────────────────────────────────────────
for cmd in curl shasum tar; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: Required command not found: $cmd"
    exit 1
  fi
done

# ── Fetch latest.json ─────────────────────────────────────────
echo "  Checking latest version..."
manifest=$(curl -fsSL "$MANIFEST_URL" 2>/dev/null) || {
  echo ""
  echo "ERROR: Could not fetch version manifest from:"
  echo "  $MANIFEST_URL"
  echo ""
  echo "Check your internet connection and try again."
  echo ""
  exit 1
}

# Parse version and download URL for this platform (use python3 for reliable JSON parsing)
VERSION=$(echo "$manifest" | python3 -c "import sys,json; print(json.load(sys.stdin)['version'])")
DOWNLOAD_URL=$(echo "$manifest" | python3 -c "import sys,json; d=json.load(sys.stdin)['platforms'].get('${PLATFORM_KEY}',{}); print(d.get('url',''))")
EXPECTED_SHA256=$(echo "$manifest" | python3 -c "import sys,json; d=json.load(sys.stdin)['platforms'].get('${PLATFORM_KEY}',{}); print(d.get('sha256',''))")

if [ -z "$VERSION" ]; then
  echo ""
  echo "ERROR: Could not parse version from manifest."
  echo ""
  exit 1
fi

if [ -z "$DOWNLOAD_URL" ]; then
  echo ""
  echo "ERROR: No release available for platform: $PLATFORM_KEY"
  echo "  Check https://clawuno.com for supported platforms."
  echo ""
  exit 1
fi

echo "  Latest version: $VERSION"

# ── Check if already installed (find clawuno CLI in PATH) ─────
if command -v clawuno &>/dev/null; then
  CLAWUNO_BIN=$(command -v clawuno)
  # Resolve symlink to find install dir
  CLAWUNO_REAL=$(readlink "$CLAWUNO_BIN" 2>/dev/null || echo "$CLAWUNO_BIN")
  INSTALL_DIR=$(cd "$(dirname "$CLAWUNO_REAL")/.." 2>/dev/null && pwd || true)
  INSTALLED_VERSION=$(cat "$INSTALL_DIR/VERSION" 2>/dev/null || echo "unknown")

  echo ""
  echo "  Existing installation detected at $INSTALL_DIR (v$INSTALLED_VERSION)"

  if version_gt "$VERSION" "$INSTALLED_VERSION"; then
    echo "  Upgrading: $INSTALLED_VERSION → $VERSION"
    echo ""
    # Delegate to the installed clawuno upgrade command,
    # which handles download + install properly
    exec "$CLAWUNO_BIN" upgrade --yes
  elif [ "$INSTALLED_VERSION" = "$VERSION" ]; then
    echo "  Already up to date."
    echo ""
    read -r -p "  Reinstall anyway? [y/N] " confirm
    if [ "$(echo "$confirm" | tr '[:upper:]' '[:lower:]')" != "y" ]; then
      echo "  Aborted."
      exit 0
    fi
    echo ""
  else
    echo "  Current version ($INSTALLED_VERSION) is newer than latest release ($VERSION). Nothing to do."
    echo ""
    exit 0
  fi
fi
echo ""

# ── Download ──────────────────────────────────────────────────
TMP_DIR=$(mktemp -d /tmp/clawuno-install-XXXXXX)
FILENAME=$(basename "$DOWNLOAD_URL")
TAR_PATH="$TMP_DIR/$FILENAME"

echo "  Downloading $FILENAME..."
curl -fsSL --progress-bar "$DOWNLOAD_URL" -o "$TAR_PATH" || {
  echo ""
  echo "ERROR: Download failed."
  rm -rf "$TMP_DIR"
  exit 1
}

# ── Verify SHA256 ─────────────────────────────────────────────
if [ -n "$EXPECTED_SHA256" ]; then
  echo "  Verifying integrity..."
  ACTUAL_SHA256=$(shasum -a 256 "$TAR_PATH" | awk '{print $1}')
  if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
    echo ""
    echo "ERROR: SHA256 verification failed."
    echo "  Expected: $EXPECTED_SHA256"
    echo "  Actual:   $ACTUAL_SHA256"
    echo ""
    echo "The downloaded file may be corrupted. Please try again."
    rm -rf "$TMP_DIR"
    exit 1
  fi
  echo "  Integrity verified."
fi

echo ""

# ── Extract and install ───────────────────────────────────────
echo "  Extracting..."
tar xzf "$TAR_PATH" -C "$TMP_DIR"

RELEASE_DIR=$(find "$TMP_DIR" -maxdepth 1 -mindepth 1 -type d | head -1)
if [ -z "$RELEASE_DIR" ] || [ ! -f "$RELEASE_DIR/install.sh" ]; then
  echo "ERROR: Invalid release package."
  rm -rf "$TMP_DIR"
  exit 1
fi

chmod +x "$RELEASE_DIR/install.sh"

# Pass through any arguments (e.g. --dir, --port)
exec "$RELEASE_DIR/install.sh" "$@"

# (exec replaces this process — cleanup of $TMP_DIR is handled by install.sh
#  which receives --_tmp is not passed here since install.sh cleans its own extract dir)
