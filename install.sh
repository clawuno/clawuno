#!/bin/bash
# ============================================================================
# Clawuno — Installer
#
# Mode 1 — One-click Linux install (downloads latest from CDN):
#   curl -fsSL https://releases.clawuno.com/install.sh | bash
#
# Mode 2 — Local package (from GitHub Releases or manual download):
#   bash install.sh clawuno-0.8.0-linux-x64.tar.gz [--dir ~/clawuno] [--port 9700]
#
# What it does:
#   Mode 1: Detects platform → fetches latest.json → downloads package → installs
#   Mode 2: Uses the provided local .tar.gz directly → installs
# ============================================================================

set -euo pipefail

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    echo "ERROR: shasum or sha256sum is required to verify the release." >&2
    return 1
  fi
}

verify_signed_release_manifest() {
  local releases_base="$1" version="$2" verify_dir manifest_file signature_file signature_binary public_key
  case "$version" in ''|*[!A-Za-z0-9._+-]*) echo "ERROR: Invalid release version metadata." >&2; return 1 ;; esac
  command -v openssl >/dev/null 2>&1 || {
    echo "ERROR: openssl is required to authenticate release metadata." >&2
    return 1
  }
  verify_dir=$(mktemp -d "${TMPDIR:-/tmp}/clawuno-manifest-XXXXXX") || return 1
  manifest_file="$verify_dir/manifest.json"
  signature_file="$verify_dir/manifest.sig"
  signature_binary="$verify_dir/manifest.sig.bin"
  public_key="$verify_dir/release-public.pem"
  if ! curl -fsSL "$releases_base/releases/manifests/${version}.json" -o "$manifest_file" ||
     ! curl -fsSL "$releases_base/releases/manifests/${version}.json.sig" -o "$signature_file"; then
    echo "ERROR: Could not download signed release metadata for $version." >&2
    rm -rf "$verify_dir"
    return 1
  fi
  cat > "$public_key" <<'CLAWUNO_RELEASE_PUBLIC_KEY'
-----BEGIN PUBLIC KEY-----
MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAuGQehM2A7B7skKZx7y4f
lEnMZllxBh8DCt4jFlXaQw6+7aXpTjAOWM2m8io+hoxbQU3Vd5ig6ftzeXl5N4rX
Xt+vQz/qRSD+TdSfabpuqZZiJrz7iI2FncEIBO3mkAOMU0zeXhoJTzag92+YpcQL
k8ig89YvXIMQaKgqoMfPLsDiIgzZUCIYPkp+3G6MeDfRAVOX2LrZL2uKhE64mIXQ
QEWE/VlqS+FlPTB/U6EK4UPTxsb1NGK9+IxR5wmwPvlM0k3YquHfUiAflCDwzT6z
lYlXrOsUmgxSiJgYob2UIN2TBeGWlcEwWgls6cWtEPsCPDIFIdT02RKSGDshQnmh
906rDO33Fn7qWxuuipW6bSmrIJ+zKIW3Xm6poBhI+Vze+IerrF8vhgpCxKvTxX/l
1Sxo+tGAKr0FJKG7pol8r42ZHt7i2QLRBNqkb+uzIzwU8tp7CuQB+YB1OVbIIPrH
ulGkRTvXr0injiulsXDy1KYruajtsmRAKaQiWccAEa+/AgMBAAE=
-----END PUBLIC KEY-----
CLAWUNO_RELEASE_PUBLIC_KEY
  if ! openssl base64 -d -A -in "$signature_file" -out "$signature_binary" 2>/dev/null ||
     ! openssl dgst -sha256 -verify "$public_key" -signature "$signature_binary" "$manifest_file" >/dev/null 2>&1; then
    echo "ERROR: Release metadata signature verification failed." >&2
    rm -rf "$verify_dir"
    return 1
  fi
  VERIFIED_RELEASE_MANIFEST=$(cat "$manifest_file")
  rm -rf "$verify_dir"
}

validate_release_archive() {
  local archive="$1" first_root="" entry root
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    case "$entry" in /*|*\\*) echo "ERROR: Unsafe archive path: $entry" >&2; return 1 ;; esac
    case "/$entry/" in */../*) echo "ERROR: Unsafe archive path: $entry" >&2; return 1 ;; esac
    root=${entry%%/*}
    [ -n "$root" ] && [ "$root" != "." ] || { echo "ERROR: Archive has no top-level release directory." >&2; return 1; }
    if [ -z "$first_root" ]; then first_root="$root"; fi
    [ "$root" = "$first_root" ] || { echo "ERROR: Archive contains multiple top-level entries." >&2; return 1; }
  done < <(tar tzf "$archive")
  [ -n "$first_root" ] || { echo "ERROR: Release archive is empty." >&2; return 1; }
}

install_linux_docker() {
  local version="" arg previous="" install_docker=false
  local -a forwarded=()
  for arg in "$@"; do
    if [ "$arg" = "--help" ]; then
      echo "Clawuno Linux Docker installer"
      echo "Options: --instance NAME --port PORT --dir PATH --version VERSION --yes --install-docker"
      echo "Default: install one instance, then use sudo clawuno upgrade."
      return
    fi
    if [ "$arg" = "--install-docker" ]; then install_docker=true; continue; fi
    [ "$previous" = "--version" ] && version="$arg"
    previous="$arg"
    forwarded+=("$arg")
    case "$arg" in *.tar.gz|*.zip) echo "ERROR: Linux uses Docker. Load an offline OCI image and use the Docker deployment bundle, not a native archive." >&2; return 1 ;; esac
  done
  [ "$(uname -m)" = "x86_64" ] || { echo "ERROR: Linux currently supports x86_64 only." >&2; return 1; }
  for arg in python3 curl openssl; do
    command -v "$arg" >/dev/null || { echo "ERROR: Install the host prerequisite '$arg', then rerun this command." >&2; return 1; }
  done
  python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3,9) else 1)' || {
    echo "ERROR: Python 3.9+ is required." >&2; return 1;
  }
  if [ -z "$version" ]; then
    version=$(curl --proto '=https' --proto-redir '=https' -fsSL https://releases.clawuno.com/latest.json |
      python3 -c 'import json,sys; v=json.load(sys.stdin)["version"]; import re; assert re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+",v); print(v)')
  fi
  echo "Checking the signed Clawuno release..."
  verify_signed_release_manifest https://releases.clawuno.com "$version"
  local descriptor
  descriptor=$(printf '%s' "$VERIFIED_RELEASE_MANIFEST" | python3 -c '
import json,sys,re
m=json.load(sys.stdin)
d=m.get("platforms",{}).get("linux-docker",{})
if d.get("kind")!="docker-v1" or d.get("manager_api")!=1: sys.exit("No compatible Linux Docker release is available yet.")
if not re.fullmatch(r"https://releases\.clawuno\.com/releases/[A-Za-z0-9._-]+\.tar\.gz",d["url"]): sys.exit("Invalid bundle URL")
if not re.fullmatch(r"[a-f0-9]{64}",d["sha256"]): sys.exit("Invalid bundle checksum")
if not (type(d["size"]) is int and 0<d["size"]<=10485760): sys.exit("Invalid bundle size")
print(json.dumps(d))')
  if ! command -v docker >/dev/null; then
    if [ "$install_docker" != true ]; then
      echo "Docker is required. Install Docker from Ubuntu system packages? [y/N]"
      local answer=""
      read -r answer </dev/tty || { echo "Use --install-docker to explicitly authorize prerequisite installation." >&2; return 1; }
      case "$answer" in y|Y|yes|YES) ;; *) echo "Cancelled. Docker was not installed."; return 1 ;; esac
    fi
    if ! grep -q '^ID=ubuntu$' /etc/os-release || ! grep -q '^VERSION_ID="24.04"$' /etc/os-release; then
      echo "Automatic Docker setup supports Ubuntu 24.04. Install Docker Engine + Compose v2 for your distribution, then retry." >&2
      return 1
    fi
    if dpkg-query -W -f='${Status}' docker-ce docker-ce-cli 2>/dev/null | grep -q 'install ok installed'; then
      echo "An existing Docker installation needs repair. It will not be replaced automatically." >&2; return 1
    fi
    root_run apt-get update
    root_run apt-get install -y --no-upgrade --no-install-recommends docker.io docker-compose-v2
    root_run systemctl enable --now docker
  fi
  docker compose version >/dev/null || { echo "Install/repair Docker Compose v2, then retry. Existing Docker was not replaced." >&2; return 1; }
  root_run docker info >/dev/null || { echo "Docker is not running or is inaccessible. Start Docker, then retry." >&2; return 1; }
  local temp archive url
  temp=$(mktemp -d /tmp/clawuno-docker-bootstrap-XXXXXX)
  archive="$temp/deploy.tar.gz"
  url=$(printf '%s' "$descriptor" | python3 -c 'import json,sys; print(json.load(sys.stdin)["url"])')
  echo "Downloading verified deployment tools..."
  if ! curl --proto '=https' --proto-redir '=https' --max-filesize 10485760 -fSL "$url" -o "$archive"; then rm -rf "$temp"; return 1; fi
  local status=0
  root_run python3 -c '
import hashlib,io,json,pathlib,subprocess,sys,tarfile,tempfile
def check(condition,message):
  if not condition: sys.exit(message)
d=json.loads(sys.argv[1]); raw=pathlib.Path(sys.argv[2]).read_bytes()
check(len(raw)==d["size"] and hashlib.sha256(raw).hexdigest()==d["sha256"], "Deployment bundle checksum mismatch")
allowed={"clawuno","release.py","compose.yaml","seccomp.json","release-signing-public.pem","README.md","LICENSE.playwright"}
with tempfile.TemporaryDirectory(prefix="clawuno-bootstrap-root-") as target:
  seen=set(); total=0
  with tarfile.open(fileobj=io.BytesIO(raw),mode="r:gz") as archive:
    for member in archive:
      prefix="clawuno-linux-deploy/"
      if member.isdir() and member.name.rstrip("/")==prefix.rstrip("/"): continue
      name=member.name.removeprefix(prefix)
      check(member.name.startswith(prefix) and name in allowed and name not in seen and member.isfile(), "Unsafe deployment bundle")
      total+=member.size; check(0<=member.size<=1048576 and total<=10485760, "Oversized deployment bundle")
      seen.add(name); file=pathlib.Path(target)/name
      file.write_bytes(archive.extractfile(member).read()); file.chmod(0o700 if name=="clawuno" else 0o600)
  check(seen==allowed, "Incomplete deployment bundle")
  result=subprocess.run([sys.executable,str(pathlib.Path(target)/"clawuno"),"bootstrap",*sys.argv[3:]])
  sys.exit(result.returncode)
' "$descriptor" "$archive" "${forwarded[@]}" || status=$?
  rm -rf "$temp"
  return "$status"
}

root_run() {
  if [ "$(id -u)" = 0 ]; then "$@"; else sudo -- "$@"; fi
}

# Linux always uses the Docker path, including repeated installation. The old
# native implementation below remains only for historical verifier fixtures.
if [ "$(uname -s)" = Linux ]; then
  install_linux_docker "$@"
  exit $?
fi

# ── Mode 2: Local package provided as first argument ─────────
# If the first argument is a .tar.gz or .zip file, skip the download entirely
if [[ "${1:-}" == *.tar.gz ]]; then
  LOCAL_PKG="$1"
  shift  # remove the package path; remaining args passed to install.sh

  if [ ! -f "$LOCAL_PKG" ]; then
    echo ""
    echo "ERROR: File not found: $LOCAL_PKG"
    echo ""
    exit 1
  fi

  echo ""
  echo "========================================"
  echo "  Clawuno — Installer"
  echo "========================================"
  echo ""
  echo "  Package: $(basename "$LOCAL_PKG")"
  echo ""

  CHECKSUM_FILE="${LOCAL_PKG}.sha256"
  if [ ! -f "$CHECKSUM_FILE" ]; then
    echo "ERROR: Local release requires its sibling checksum file: $CHECKSUM_FILE"
    exit 1
  fi
  EXPECTED_LOCAL_SHA=$(awk 'NR == 1 { print $1 }' "$CHECKSUM_FILE")
  case "$EXPECTED_LOCAL_SHA" in
    *[!0-9A-Fa-f]*|'') echo "ERROR: Invalid SHA-256 checksum file: $CHECKSUM_FILE"; exit 1 ;;
  esac
  [ "${#EXPECTED_LOCAL_SHA}" -eq 64 ] || { echo "ERROR: Invalid SHA-256 checksum file: $CHECKSUM_FILE"; exit 1; }
  ACTUAL_LOCAL_SHA=$(sha256_file "$LOCAL_PKG")
  [ "$(printf '%s' "$ACTUAL_LOCAL_SHA" | tr '[:upper:]' '[:lower:]')" = "$(printf '%s' "$EXPECTED_LOCAL_SHA" | tr '[:upper:]' '[:lower:]')" ] || {
    echo "ERROR: Local release SHA-256 verification failed."
    exit 1
  }

  # Remove macOS quarantine if present (silently — not all systems have xattr)
  xattr -r -d com.apple.quarantine "$LOCAL_PKG" 2>/dev/null || true

  TMP_DIR=$(mktemp -d /tmp/clawuno-install-XXXXXX)
  trap 'rm -rf "$TMP_DIR"' EXIT
  echo "  Extracting..."
  validate_release_archive "$LOCAL_PKG"
  tar xzf "$LOCAL_PKG" -C "$TMP_DIR"

  RELEASE_DIR=$(find "$TMP_DIR" -maxdepth 1 -mindepth 1 -type d | head -1)
  if [ -z "$RELEASE_DIR" ] || [ ! -f "$RELEASE_DIR/install.sh" ]; then
    echo "ERROR: Invalid release package."
    rm -rf "$TMP_DIR"
    exit 1
  fi

  chmod +x "$RELEASE_DIR/install.sh"
  "$RELEASE_DIR/install.sh" "$@"
  _status=$?
  rm -rf "$TMP_DIR"
  trap - EXIT
  exit "$_status"
fi

# ── Version comparison ────────────────────────────────────────
# version_gt A B — returns 0 (true) if A is strictly newer than B.
version_gt() {
  local a="${1%%+*}" b="${2%%+*}"
  local core_a core_b pre_a="" pre_b=""
  core_a="${a%%-*}"
  core_b="${b%%-*}"
  [[ "$core_a" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] || return 1
  [[ "$core_b" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] || return 0
  local IFS=.
  # shellcheck disable=SC2206
  local pa=($core_a) pb=($core_b)
  local i
  for i in 0 1 2; do
    local na="${pa[$i]:-0}" nb="${pb[$i]:-0}"
    if [ "$na" -gt "$nb" ]; then return 0; fi
    if [ "$na" -lt "$nb" ]; then return 1; fi
  done
  [[ "$a" == *-* ]] && pre_a="${a#*-}"
  [[ "$b" == *-* ]] && pre_b="${b#*-}"
  [ -z "$pre_a" ] && [ -n "$pre_b" ] && return 0
  [ -n "$pre_a" ] && [ -z "$pre_b" ] && return 1
  [ -z "$pre_a" ] && return 1
  local IFS=. ia ib max j
  # shellcheck disable=SC2206
  local ids_a=($pre_a) ids_b=($pre_b)
  max=${#ids_a[@]}; [ "${#ids_b[@]}" -gt "$max" ] && max=${#ids_b[@]}
  for ((j=0; j<max; j++)); do
    ia="${ids_a[$j]:-}"; ib="${ids_b[$j]:-}"
    [ "$ia" = "$ib" ] && continue
    [ -z "$ia" ] && return 1
    [ -z "$ib" ] && return 0
    if [[ "$ia" =~ ^[0-9]+$ ]] && [[ "$ib" =~ ^[0-9]+$ ]]; then
      ((10#$ia > 10#$ib)) && return 0 || return 1
    fi
    [[ "$ia" =~ ^[0-9]+$ ]] && return 1
    [[ "$ib" =~ ^[0-9]+$ ]] && return 0
    [[ "$ia" > "$ib" ]] && return 0 || return 1
  done
  return 1
}

RELEASES_BASE="https://releases.clawuno.com"
MANIFEST_URL="${RELEASES_BASE}/latest.json"

# ── Detect platform ───────────────────────────────────────────
OS_NAME=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$OS_NAME" in
  darwin)
    echo ""
    echo "Clawuno for macOS is distributed as a signed Apple Silicon app."
    echo "Download the DMG from: https://clawuno.com"
    echo ""
    echo "The command-line installer is for Linux. No files were changed."
    echo ""
    exit 1
    ;;
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
for cmd in curl tar openssl; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: Required command not found: $cmd"
    exit 1
  fi
done
if ! command -v shasum >/dev/null 2>&1 && ! command -v sha256sum >/dev/null 2>&1; then
  echo "ERROR: shasum or sha256sum is required to verify the release."
  exit 1
fi

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

# Parse version and download URL for this platform.
#
# Why not python3: /usr/bin/python3 on macOS is a Command Line Tools stub
# that dies with "xcrun: error: invalid active developer path" on any Mac
# without CLT. Requiring CLT to install Clawuno is unacceptable for end
# users.
#
# Why not plutil: macOS pre-13 ships a plutil that doesn't understand
# stdin JSON input or `raw` output — both needed here. The matrix of
# "works on modern macOS but not Big Sur" is a debugging minefield.
#
# So: parse with sed + awk/grep. The manifest schema is stable (we
# control the producer), 2-space indented, so extraction is simple and
# portable across all POSIX shells.

# Extract the top-level "version" string.
parse_version() {
  printf '%s\n' "$manifest" \
    | sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    | head -n 1
}

# Extract a string field from the block under `platforms.<platform_key>`.
# `grep -A 3` captures the next 3 lines after the key match — enough to
# cover `"url": ...` and `"sha256": ...` in the two-line field block.
# Empty result on missing platform.
parse_platform_field() {
  local platform_key="$1" field="$2"
  printf '%s\n' "$manifest" \
    | grep -A 3 "\"${platform_key}\":" \
    | grep "\"${field}\"" \
    | sed -n "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" \
    | head -n 1
}

VERSION=$(parse_version)
case "$VERSION" in ''|*[!A-Za-z0-9._+-]*) echo "ERROR: Invalid release version metadata."; exit 1 ;; esac
verify_signed_release_manifest "$RELEASES_BASE" "$VERSION"
manifest="$VERIFIED_RELEASE_MANIFEST"
SIGNED_VERSION=$(parse_version)
[ "$SIGNED_VERSION" = "$VERSION" ] || {
  echo "ERROR: latest.json and signed release metadata disagree."
  exit 1
}
DOWNLOAD_URL=$(parse_platform_field "$PLATFORM_KEY" "url")
EXPECTED_SHA256=$(parse_platform_field "$PLATFORM_KEY" "sha256")

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
case "$DOWNLOAD_URL" in
  https://releases.clawuno.com/*) ;;
  *) echo "ERROR: Untrusted release download URL: $DOWNLOAD_URL"; exit 1 ;;
esac
case "$EXPECTED_SHA256" in
  *[!0-9A-Fa-f]*|'') echo "ERROR: Invalid SHA-256 in release metadata."; exit 1 ;;
esac
[ "${#EXPECTED_SHA256}" -eq 64 ] || { echo "ERROR: Invalid SHA-256 in release metadata."; exit 1; }

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

    # Detect whether we can read from the user's terminal.
    # In `curl ... | bash` mode stdin is the pipe (no tty).
    # /dev/tty lets us read directly from the terminal if it exists.
    if [ -r /dev/tty ] && [ -t 1 ]; then
      echo "  Reinstalling will:"
      echo "    - Restore program files to a clean state"
      echo "    - Preserve all your data, settings, and workspaces"
      echo "    - Create a pre-install backup automatically"
      echo ""
      read -r -p "  Reinstall? [y/N] " confirm < /dev/tty
      if [ "$(echo "$confirm" | tr '[:upper:]' '[:lower:]')" != "y" ]; then
        echo "  Aborted."
        exit 0
      fi
      echo ""
    else
      # No terminal available (e.g. non-interactive pipe). Cannot prompt safely.
      echo "  To reinstall, download the package and run install.sh locally:"
      echo "    https://github.com/clawuno/clawuno/releases/latest"
      echo ""
      exit 0
    fi
  else
    echo "  Current version ($INSTALLED_VERSION) is newer than latest release ($VERSION). Nothing to do."
    echo ""
    exit 0
  fi
fi
echo ""

# ── Download ──────────────────────────────────────────────────
TMP_DIR=$(mktemp -d /tmp/clawuno-install-XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT
FILENAME=$(basename "$DOWNLOAD_URL")
TAR_PATH="$TMP_DIR/$FILENAME"

echo "  Downloading $FILENAME..."
curl -fL --progress-bar "$DOWNLOAD_URL" -o "$TAR_PATH" || {
  echo ""
  echo "ERROR: Download failed."
  rm -rf "$TMP_DIR"
  exit 1
}

# ── Verify SHA256 ─────────────────────────────────────────────
if [ -z "$EXPECTED_SHA256" ]; then
  echo "ERROR: Release metadata is missing SHA-256 for $PLATFORM_KEY."
  exit 1
fi
echo "  Verifying integrity..."
ACTUAL_SHA256=$(sha256_file "$TAR_PATH")
if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
    echo ""
    echo "ERROR: SHA256 verification failed."
    echo "  Expected: $EXPECTED_SHA256"
    echo "  Actual:   $ACTUAL_SHA256"
    echo ""
    echo "The downloaded file may be corrupted. Please try again."
  exit 1
fi
echo "  Integrity verified."

echo ""

# ── Extract and install ───────────────────────────────────────
echo "  Extracting..."
validate_release_archive "$TAR_PATH"
tar xzf "$TAR_PATH" -C "$TMP_DIR"

RELEASE_DIR=$(find "$TMP_DIR" -maxdepth 1 -mindepth 1 -type d | head -1)
if [ -z "$RELEASE_DIR" ] || [ ! -f "$RELEASE_DIR/install.sh" ]; then
  echo "ERROR: Invalid release package."
  rm -rf "$TMP_DIR"
  exit 1
fi

chmod +x "$RELEASE_DIR/install.sh"

# Pass through any arguments (e.g. --dir, --port), preserving the result while
# this wrapper's EXIT trap owns and removes the extraction directory.
"$RELEASE_DIR/install.sh" "$@"
