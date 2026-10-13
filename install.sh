#!/bin/bash
# ============================================================================
# Clawuno — Installer
#
# Mode 1 — One-click Linux install (downloads latest from CDN):
#   curl -fsSL https://releases.clawuno.com/install.sh | bash
#
# Linux uses the signed Docker deployment path on both x86-64 and ARM64.
#
# What it does:
#   Mode 1: Detects platform → fetches latest.json → downloads package → installs
#   Other platforms retain their existing package path below.
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

write_release_public_key() {
  cat > "$1" <<'CLAWUNO_RELEASE_PUBLIC_KEY'
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
}

verify_signed_json() {
  local document_url="$1" signature_url="$2" description="$3"
  local verify_dir document_file signature_file signature_binary public_key
  command -v openssl >/dev/null 2>&1 || {
    echo "ERROR: openssl is required to authenticate release metadata." >&2
    return 1
  }
  verify_dir=$(mktemp -d "${TMPDIR:-/tmp}/clawuno-manifest-XXXXXX") || return 1
  document_file="$verify_dir/document.json"
  signature_file="$verify_dir/manifest.sig"
  signature_binary="$verify_dir/manifest.sig.bin"
  public_key="$verify_dir/release-public.pem"
  if ! curl --proto '=https' --proto-redir '=https' -fsSL "$document_url" -o "$document_file" ||
     ! curl --proto '=https' --proto-redir '=https' -fsSL "$signature_url" -o "$signature_file"; then
    echo "ERROR: Could not download signed $description." >&2
    rm -rf "$verify_dir"
    return 1
  fi
  write_release_public_key "$public_key"
  if ! openssl base64 -d -A -in "$signature_file" -out "$signature_binary" 2>/dev/null ||
     ! openssl dgst -sha256 -verify "$public_key" -signature "$signature_binary" "$document_file" >/dev/null 2>&1; then
    echo "ERROR: $description signature verification failed." >&2
    rm -rf "$verify_dir"
    return 1
  fi
  VERIFIED_SIGNED_JSON=$(cat "$document_file")
  rm -rf "$verify_dir"
}

verify_signed_release_manifest() {
  local releases_base="$1" version="$2"
  case "$version" in ''|*[!A-Za-z0-9._+-]*) echo "ERROR: Invalid release version metadata." >&2; return 1 ;; esac
  verify_signed_json \
    "$releases_base/releases/manifests/${version}.json" \
    "$releases_base/releases/manifests/${version}.json.sig" \
    "release metadata for $version"
  VERIFIED_RELEASE_MANIFEST="$VERIFIED_SIGNED_JSON"
}

linux_architecture() {
  case "${1:-$(uname -m)}" in
    x86_64|amd64) printf 'amd64\n' ;;
    aarch64|arm64) printf 'arm64\n' ;;
    *) echo "ERROR: Linux supports x86_64 and ARM64; found ${1:-$(uname -m)}." >&2; return 1 ;;
  esac
}

prepare_r2_offline_image() {
  local releases_base="$1" version="$2" temp="$3" released_image="$4" architecture="${5:-$(linux_architecture)}"
  local descriptor_url signature_url descriptor archive_url archive image_ref actual_image
  descriptor_url="$releases_base/releases/offline/${version}-linux-${architecture}.json"
  signature_url="${descriptor_url}.sig"
  echo "Checking the signed China mainland image mirror..."
  verify_signed_json "$descriptor_url" "$signature_url" "offline image metadata for $version"
  descriptor=$(printf '%s' "$VERIFIED_SIGNED_JSON" | python3 -c '
import json,re,sys
d=json.load(sys.stdin)
def check(value,message):
  if not value: sys.exit(message)
check(d.get("schema")==1 and d.get("kind")=="clawuno-linux-offline-image-v1", "Unsupported offline image metadata")
check(d.get("version")==sys.argv[1], "Offline image version mismatch")
check(d.get("platform")==f"linux/{sys.argv[3]}", "Offline image platform mismatch")
check(re.fullmatch(r"https://releases\.clawuno\.com/releases/offline/[A-Za-z0-9._-]+\.tar\.gz", d.get("archive_url","")), "Invalid offline image URL")
check(re.fullmatch(r"[a-f0-9]{64}", d.get("archive_sha256","")), "Invalid offline image checksum")
check(type(d.get("archive_size")) is int and 0 < d["archive_size"] <= 5 * 1024**3, "Invalid offline image size")
check(re.fullmatch(r"sha256:[a-f0-9]{64}", d.get("image_config_digest","")), "Invalid offline image config digest")
check(d.get("image_ref")==f"clawuno-offline:{sys.argv[1]}-{sys.argv[3]}", "Invalid offline image reference")
check(re.fullmatch(r"ghcr\.io/clawuno/clawuno@sha256:[a-f0-9]{64}", d.get("source_image","")), "Invalid source image")
check(d.get("source_image")==sys.argv[2], "Offline image does not match the signed release")
print(json.dumps(d,separators=(",",":")))
' "$version" "$released_image" "$architecture") || return 1
  python3 -c '
import json,os,sys
d=json.loads(sys.argv[1]); target=sys.argv[2]
space=os.statvfs(target).f_bavail * os.statvfs(target).f_frsize
required=d["archive_size"] + 512 * 1024**2
if space < required: sys.exit(f"Insufficient temporary space: need at least {required // 1048576} MiB free")
' "$descriptor" "$temp" || return 1
  archive_url=$(printf '%s' "$descriptor" | python3 -c 'import json,sys; print(json.load(sys.stdin)["archive_url"])')
  archive="$temp/image.tar.gz"
  echo "Downloading the verified Clawuno image from the release CDN..."
  if ! curl --proto '=https' --proto-redir '=https' --retry 5 \
      --connect-timeout 20 --max-filesize 5368709120 -fL "$archive_url" -o "$archive"; then
    echo "ERROR: Offline image download failed. No deployment data was changed." >&2
    return 1
  fi
  python3 -c '
import hashlib,json,pathlib,sys
d=json.loads(sys.argv[1]); p=pathlib.Path(sys.argv[2])
size=p.stat().st_size
if size != d["archive_size"]: sys.exit("Offline image size mismatch")
h=hashlib.sha256()
with p.open("rb") as f:
  for chunk in iter(lambda:f.read(8*1024*1024),b""): h.update(chunk)
if h.hexdigest()!=d["archive_sha256"]: sys.exit("Offline image checksum mismatch")
' "$descriptor" "$archive" || return 1
  python3 -c '
import json,re,sys,tarfile
d=json.loads(sys.argv[1]); archive=sys.argv[2]
with tarfile.open(archive,"r:gz") as tf:
  def read(name):
    f=tf.extractfile(name)
    if f is None: raise SystemExit("Offline archive metadata is missing")
    return json.load(f)
  try:
    entry=read("index.json").get("manifests",[])[0]
    digest=None
    for _ in range(3):
      value=entry.get("digest","")
      if not re.fullmatch(r"sha256:[a-f0-9]{64}",value): break
      doc=read("blobs/sha256/"+value[7:])
      digest=(doc.get("config") or {}).get("digest")
      if digest: break
      entries=doc.get("manifests",[])
      entry=next((x for x in entries if x.get("platform",{}).get("os")=="linux" and x.get("platform",{}).get("architecture")==sys.argv[3]), entries[0] if entries else {})
  except (KeyError,IndexError):
    config=read("manifest.json")[0].get("Config","")
    digest="sha256:"+config[:-5] if re.fullmatch(r"[a-f0-9]{64}\.json",config) else None
if digest!=d["image_config_digest"]: raise SystemExit("Offline image config digest mismatch")
' "$descriptor" "$archive" "$architecture" || return 1
  echo "Loading the verified Clawuno image..."
  root_run docker load --input "$archive" >/dev/null || return 1
  image_ref=$(printf '%s' "$descriptor" | python3 -c 'import json,sys; print(json.load(sys.stdin)["image_ref"])')
  actual_image=$(root_run docker image inspect "$image_ref" --format '{{.Id}}' 2>/dev/null || true)
  if ! printf '%s\n' "$actual_image" | grep -Eq '^sha256:[a-f0-9]{64}$'; then
    echo "ERROR: Docker did not expose the loaded image." >&2
    return 1
  fi
  root_run docker image inspect "$image_ref" --format '{{json .}}' | python3 -c '
import json,sys
d=json.load(sys.stdin); labels=d.get("Config",{}).get("Labels") or {}
if d.get("Os")!="linux" or d.get("Architecture")!=sys.argv[1]: sys.exit("Loaded image platform mismatch")
if labels.get("io.clawuno.distribution")!="docker-v1": sys.exit("Loaded image is not a Clawuno Docker release")
' "$architecture" || return 1
  PREPARED_IMAGE_ID="$actual_image"
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

find_existing_docker_package() {
  local package
  if command -v dpkg-query >/dev/null 2>&1; then
    for package in docker-ce docker-ce-cli docker-ce-rootless-extras docker.io docker-compose docker-compose-v2 docker-compose-plugin docker-doc docker-buildx docker-buildx-plugin podman-docker containerd containerd.io runc moby-engine; do
      if [ "$(dpkg-query -W -f='${db:Status-Abbrev}' "$package" 2>/dev/null || true)" = "ii " ]; then
        echo "$package"
        return 0
      fi
    done
  fi
  if command -v rpm >/dev/null 2>&1; then
    for package in docker-ce docker-ce-cli docker-ce-rootless-extras docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine docker-selinux docker-engine-selinux docker-compose-plugin docker-buildx-plugin podman podman-docker containerd containerd.io runc moby-engine; do
      if rpm -q "$package" >/dev/null 2>&1; then
        echo "$package"
        return 0
      fi
    done
  fi
  return 1
}

find_existing_docker_repository() {
  local distribution="$1"
  case "$distribution" in
    ubuntu|debian)
      if grep -Rqs 'download\.docker\.com' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null ||
         [ -e /etc/apt/keyrings/docker.asc ]; then
        echo "/etc/apt (Docker repository or key)"
        return 0
      fi
      ;;
    fedora|centos|rhel)
      if grep -Rqs 'download\.docker\.com' /etc/yum.repos.d 2>/dev/null; then
        echo "/etc/yum.repos.d (Docker repository)"
        return 0
      fi
      ;;
  esac
  return 1
}

install_docker_apt_repository() {
  local distribution="$1" codename="$2" temp repository_status architecture
  architecture=$(linux_architecture)
  [ -n "$codename" ] || {
    echo "ERROR: Could not determine the $distribution release codename. Install Docker Engine and Compose v2 manually: https://docs.docker.com/engine/install/$distribution/" >&2
    return 1
  }
  if ! repository_status=$(curl --proto '=https' --proto-redir '=https' --max-filesize 1048576 -sSL \
      -o /dev/null -w '%{http_code}' "https://download.docker.com/linux/$distribution/dists/$codename/Release"); then
    echo "ERROR: Could not reach Docker's official repository. Check DNS, TLS and proxy settings, then retry." >&2
    return 1
  fi
  if [ "$repository_status" != 200 ]; then
    if [ "$repository_status" = 404 ]; then
      echo "ERROR: Docker does not publish an official repository for this $distribution release ($codename). Install Docker Engine and Compose v2 manually: https://docs.docker.com/engine/install/$distribution/" >&2
    else
      echo "ERROR: Docker's official repository returned HTTP $repository_status. Retry later or install Docker manually: https://docs.docker.com/engine/install/$distribution/" >&2
    fi
    return 1
  fi
  temp=$(mktemp -d /tmp/clawuno-docker-repository-XXXXXX)
  if ! curl --proto '=https' --proto-redir '=https' -fsSL \
      "https://download.docker.com/linux/$distribution/gpg" -o "$temp/docker.asc"; then
    rm -rf "$temp"
    echo "ERROR: Could not download Docker's repository signing key." >&2
    return 1
  fi
  cat > "$temp/docker.sources" <<EOF
Types: deb
URIs: https://download.docker.com/linux/$distribution
Suites: $codename
Components: stable
Architectures: $architecture
Signed-By: /etc/apt/keyrings/docker.asc
EOF
  if ! root_run apt-get update ||
     ! root_run apt-get install -y --no-install-recommends ca-certificates ||
     ! root_run install -m 0755 -d /etc/apt/keyrings ||
     ! root_run install -m 0644 "$temp/docker.asc" /etc/apt/keyrings/docker.asc ||
     ! root_run install -m 0644 "$temp/docker.sources" /etc/apt/sources.list.d/docker.sources ||
     ! root_run apt-get update ||
     ! root_run apt-get install -y --no-remove docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
    root_run rm -f /etc/apt/sources.list.d/docker.sources /etc/apt/keyrings/docker.asc || true
    rm -rf "$temp"
    echo "ERROR: Docker package installation failed. Existing packages were not removed, and the repository files added by this attempt were removed. Review Docker's instructions: https://docs.docker.com/engine/install/$distribution/" >&2
    return 1
  fi
  rm -rf "$temp"
}

install_docker_rpm_repository() {
  local distribution="$1" version="$2" releasever repository_status architecture
  architecture=$(linux_architecture)
  [ "$architecture" = amd64 ] && architecture=x86_64 || architecture=aarch64
  local repository="https://download.docker.com/linux/$distribution/docker-ce.repo"
  releasever=${version%%.*}
  case "$releasever" in ''|*[!0-9]*)
    echo "ERROR: Could not determine the $distribution release version. Install Docker Engine and Compose v2 manually: https://docs.docker.com/engine/install/$distribution/" >&2
    return 1
    ;;
  esac
  if ! repository_status=$(curl --proto '=https' --proto-redir '=https' --max-filesize 1048576 -sSL \
      -o /dev/null -w '%{http_code}' "https://download.docker.com/linux/$distribution/$releasever/$architecture/stable/repodata/repomd.xml"); then
    echo "ERROR: Could not reach Docker's official repository. Check DNS, TLS and proxy settings, then retry." >&2
    return 1
  fi
  if [ "$repository_status" != 200 ]; then
    if [ "$repository_status" = 404 ]; then
      echo "ERROR: Docker does not publish an official repository for this $distribution release ($version). Install Docker Engine and Compose v2 manually: https://docs.docker.com/engine/install/$distribution/" >&2
    else
      echo "ERROR: Docker's official repository returned HTTP $repository_status. Retry later or install Docker manually: https://docs.docker.com/engine/install/$distribution/" >&2
    fi
    return 1
  fi
  if ! root_run dnf -y install dnf-plugins-core; then
    echo "ERROR: Docker package installation failed. Existing packages were not removed. Review Docker's instructions: https://docs.docker.com/engine/install/$distribution/" >&2
    return 1
  fi
  # DNF5 changed config-manager's repository syntax; retain the DNF4 fallback.
  if ! root_run dnf config-manager addrepo "--from-repofile=$repository" 2>/dev/null &&
     ! root_run dnf config-manager --add-repo "$repository"; then
    root_run rm -f /etc/yum.repos.d/docker-ce.repo || true
    echo "ERROR: Docker's package repository could not be configured. Review Docker's instructions: https://docs.docker.com/engine/install/$distribution/" >&2
    return 1
  fi
  if ! root_run dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
    root_run rm -f /etc/yum.repos.d/docker-ce.repo || true
    echo "ERROR: Docker package installation failed. Existing packages were not removed, and the repository file added by this attempt was removed. Review Docker's instructions: https://docs.docker.com/engine/install/$distribution/" >&2
    return 1
  fi
}

install_docker_from_official_repository() {
  local os_release_file="${1:-/etc/os-release}"
  local ID="" VERSION_ID="" VERSION_CODENAME="" NAME="Linux" existing
  [ -r "$os_release_file" ] || {
    echo "ERROR: Cannot identify this Linux distribution. Install Docker Engine and Compose v2, then retry: https://docs.docker.com/engine/install/" >&2
    return 1
  }
  # os-release is the system-provided source of distribution identity.
  # shellcheck disable=SC1090
  . "$os_release_file"
  if existing=$(find_existing_docker_package); then
    echo "ERROR: Existing or conflicting package '$existing' must be reviewed before installing Docker. It will not be replaced or removed automatically." >&2
    return 1
  fi
  case "$ID" in
    ubuntu|debian)
      command -v apt-get >/dev/null 2>&1 || {
        echo "ERROR: apt-get is unavailable. Install Docker manually: https://docs.docker.com/engine/install/$ID/" >&2
        return 1
      }
      if existing=$(find_existing_docker_repository "$ID"); then
        echo "ERROR: Existing Docker repository configuration was found at $existing. It will not be overwritten automatically." >&2
        return 1
      fi
      echo "Installing Docker Engine and Compose v2 for ${NAME:-$ID} from Docker's official package repository..."
      install_docker_apt_repository "$ID" "${VERSION_CODENAME:-}"
      ;;
    fedora|centos|rhel)
      command -v dnf >/dev/null 2>&1 || {
        echo "ERROR: dnf is unavailable. Install Docker manually: https://docs.docker.com/engine/install/$ID/" >&2
        return 1
      }
      if existing=$(find_existing_docker_repository "$ID"); then
        echo "ERROR: Existing Docker repository configuration was found at $existing. It will not be overwritten automatically." >&2
        return 1
      fi
      echo "Installing Docker Engine and Compose v2 for ${NAME:-$ID} from Docker's official package repository..."
      install_docker_rpm_repository "$ID" "${VERSION_ID:-}"
      ;;
    *)
      echo "ERROR: Automatic Docker setup is not available for ${NAME:-$ID}. Install Docker Engine and Compose v2 for this distribution, then retry: https://docs.docker.com/engine/install/" >&2
      return 1
      ;;
  esac
  command -v systemctl >/dev/null 2>&1 || {
    echo "ERROR: Docker was installed, but systemd is unavailable. Start the Docker daemon using this distribution's service manager, then retry." >&2
    return 1
  }
  root_run systemctl enable --now docker
}

confirm_docker_install() {
  local preauthorized="$1" input="${2:-/dev/tty}" answer=""
  [ "$preauthorized" = true ] && return 0
  echo "Docker is required. Install Docker Engine and Compose v2 from Docker's official package repository? [y/N]"
  read -r answer <"$input" || {
    echo "Use --install-docker to explicitly authorize prerequisite installation." >&2
    return 1
  }
  case "$answer" in y|Y|yes|YES) return 0 ;; *) echo "Cancelled. Docker was not installed."; return 1 ;; esac
}

verify_docker_runtime() {
  docker compose version >/dev/null || {
    echo "Install/repair Docker Compose v2, then retry. Existing Docker was not replaced." >&2
    return 1
  }
  root_run docker info >/dev/null || {
    echo "Docker is not running or is inaccessible. Start Docker, then retry." >&2
    return 1
  }
}

install_linux_docker() {
  local version="" install_docker=false image_source="registry"
  local -a forwarded=()
  while [ "$#" -gt 0 ]; do
    if [ "$1" = "--help" ]; then
      echo "Clawuno Linux Docker installer"
      echo "Options: --instance NAME --port PORT --dir PATH --version VERSION --yes --install-docker"
      echo "Default: install one instance, then use sudo clawuno upgrade."
      return
    fi
    case "$1" in
      --install-docker)
        install_docker=true
        shift
        ;;
      --image-source)
        [ "$#" -ge 2 ] || { echo "ERROR: --image-source requires a value." >&2; return 1; }
        image_source="$2"
        shift 2
        ;;
      --version)
        [ "$#" -ge 2 ] || { echo "ERROR: --version requires a value." >&2; return 1; }
        version="$2"
        forwarded+=("$1" "$2")
        shift 2
        ;;
      *.tar.gz|*.zip)
        echo "ERROR: Linux uses Docker. Load an offline OCI image and use the Docker deployment bundle, not a native archive." >&2
        return 1
        ;;
      *)
        forwarded+=("$1")
        shift
        ;;
    esac
  done
  [ "$image_source" = registry ] || [ "$image_source" = r2 ] || {
    echo "ERROR: Unsupported image source '$image_source'." >&2
    return 1
  }
  local architecture
  architecture=$(linux_architecture) || return 1
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
arch=sys.argv[1]
variants=d.get("architectures")
if variants is None:
  if arch!="amd64": sys.exit("This release does not include a Linux ARM64 image.")
  selected={"image":d.get("image"),"download_size":d.get("download_size"),"required_space":d.get("required_space")}
else:
  if set(variants)!={"amd64","arm64"}: sys.exit("Release must contain exactly amd64 and arm64 images")
  image_pattern=r"[A-Za-z0-9][A-Za-z0-9._:/-]*@sha256:[a-f0-9]{64}"
  if not re.fullmatch(image_pattern,d.get("image","")): sys.exit("Invalid Linux OCI index image")
  repo=d["image"].split("@",1)[0]
  for name in ("amd64","arm64"):
    variant=variants.get(name)
    if type(variant) is not dict or not re.fullmatch(image_pattern,variant.get("image","")): sys.exit(f"Invalid {name} image")
    for key in ("download_size","required_space"):
      if type(variant.get(key)) is not int or variant[key]<=0: sys.exit(f"Invalid {name} image budget")
    if variant["required_space"]<variant["download_size"]: sys.exit(f"Invalid {name} free-space budget")
    if variant["image"].split("@",1)[0]!=repo: sys.exit("Linux index and child images must use one repository")
  selected=variants.get(arch) or {}
if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._:/-]*@sha256:[a-f0-9]{64}",selected.get("image","")): sys.exit("Invalid architecture image")
for key in ("download_size","required_space"):
  if type(selected.get(key)) is not int or selected[key]<=0: sys.exit("Invalid architecture image budget")
if selected["required_space"]<selected["download_size"]: sys.exit("Invalid architecture free-space budget")
if variants is not None:
  if d.get("download_size")!=max(v.get("download_size",0) for v in variants.values()) or d.get("required_space")!=max(v.get("required_space",0) for v in variants.values()): sys.exit("Top-level Linux image budget mismatch")
print(json.dumps({**d,**selected,"architecture":arch,"index_image":d.get("image")}))' "$architecture")
  if ! command -v docker >/dev/null; then
    confirm_docker_install "$install_docker"
    install_docker_from_official_repository
  fi
  verify_docker_runtime
  local temp archive url image_id=""
  temp=$(mktemp -d /tmp/clawuno-docker-bootstrap-XXXXXX)
  if [ "$image_source" = r2 ]; then
    local released_image
    released_image=$(printf '%s' "$descriptor" | python3 -c 'import json,sys; print(json.load(sys.stdin)["image"])')
    if ! prepare_r2_offline_image https://releases.clawuno.com "$version" "$temp" "$released_image" "$architecture"; then
      rm -rf "$temp"
      return 1
    fi
    image_id="$PREPARED_IMAGE_ID"
    # The host CLI accepts either --version (registry resolution) or a local
    # content-addressed image ID. The mirror has already authenticated the
    # exact version, so use only the image ID for bootstrap.
    local -a local_forwarded=()
    local skip_next=false item
    for item in "${forwarded[@]}"; do
      if [ "$skip_next" = true ]; then skip_next=false; continue; fi
      if [ "$item" = "--version" ]; then skip_next=true; continue; fi
      local_forwarded+=("$item")
    done
    forwarded=("$image_id" "${local_forwarded[@]}")
  fi
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
