#!/bin/bash
set -euo pipefail

# Only run in remote (Claude Code on the web) sessions.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-$(pwd)}"

echo "[session-start] Setting up nano-banana-2 environment..."

# Install Bun if not already present.
if ! command -v bun >/dev/null 2>&1; then
  echo "[session-start] Installing Bun..."
  curl -fsSL https://bun.sh/install | bash
  export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
  export PATH="$BUN_INSTALL/bin:$PATH"
fi

# Persist Bun on PATH for the session.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  {
    echo "export BUN_INSTALL=\"${BUN_INSTALL:-$HOME/.bun}\""
    echo "export PATH=\"${BUN_INSTALL:-$HOME/.bun}/bin:\$PATH\""
  } >> "$CLAUDE_ENV_FILE"
fi

# Install JS dependencies (uses bun.lock; fast and idempotent).
echo "[session-start] Installing JS dependencies via Bun..."
bun install --frozen-lockfile || bun install

# Install optional system tools used by transparent mode (-t flag).
# These are not required for normal generation, so failures here are
# logged but never abort the hook.
install_transparent_deps() {
  command -v apt-get >/dev/null 2>&1 || return 0
  if command -v ffmpeg >/dev/null 2>&1 && command -v magick >/dev/null 2>&1; then
    return 0
  fi
  echo "[session-start] Installing ffmpeg + imagemagick (optional, for -t flag)..."
  local sudo_cmd=""
  if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
    sudo_cmd="sudo"
  fi
  export DEBIAN_FRONTEND=noninteractive
  # Skip third-party sources that may be unsigned/unreachable in sandboxes.
  $sudo_cmd apt-get update -y -o Dir::Etc::sourceparts=/dev/null \
    -o APT::Get::List-Cleanup=0 || true
  $sudo_cmd apt-get install -y --no-install-recommends ffmpeg imagemagick || \
    echo "[session-start] Warning: could not install ffmpeg/imagemagick; -t flag will be unavailable."
}
install_transparent_deps

echo "[session-start] Done."
