#!/bin/bash
# SessionStart hook: make gstack available in this repo.
#
# gstack lives at ~/.claude/skills/gstack (its documented global location), not
# in the repo. Claude Code on the web hands out a fresh container per session,
# so without this hook /office-hours and friends disappear every time. This
# reinstalls them, and is a fast no-op once the container has a copy.
#
# Runs synchronously: skills are discovered when the session starts, so an
# async install would finish too late for the session that triggered it.
set -euo pipefail

GSTACK_DIR="$HOME/.claude/skills/gstack"

log() { echo "[gstack] $*"; }

# Playwright's Chromium download is blocked by the web sandbox's proxy, but the
# container ships a Chromium already. Alias the revision gstack's Playwright
# expects to the one on disk so ./setup's browser check passes.
shim_playwright_chromium() {
  local bp="${PLAYWRIGHT_BROWSERS_PATH:-}"
  [ -n "$bp" ] && [ -d "$bp" ] || return 0

  local want
  want=$(node -e "
    const b = require('$GSTACK_DIR/node_modules/playwright-core/browsers.json');
    const c = b.browsers.find(x => x.name === 'chromium');
    if (c) process.stdout.write(String(c.revision));
  " 2>/dev/null) || return 0
  [ -n "$want" ] || return 0
  [ -e "$bp/chromium-$want" ] && return 0

  local have
  have=$(ls -d "$bp"/chromium-[0-9]* 2>/dev/null | sed 's|.*/chromium-||' | sort -n | tail -1)
  [ -n "$have" ] || return 0

  log "aliasing Playwright chromium-$want -> chromium-$have (downloads are blocked here)"

  # Chromium's payload dir is chrome-linux64 (x64) or chrome-linux (arm64);
  # link both names at the target so either lookup resolves.
  local src
  for src in "$bp/chromium-$have"/chrome-linux64 "$bp/chromium-$have"/chrome-linux; do
    [ -d "$src" ] || continue
    mkdir -p "$bp/chromium-$want"
    ln -sfn "$src" "$bp/chromium-$want/chrome-linux64"
    ln -sfn "$src" "$bp/chromium-$want/chrome-linux"
    touch "$bp/chromium-$want/INSTALLATION_COMPLETE" "$bp/chromium-$want/DEPENDENCIES_VALIDATED"
    break
  done

  local shell_src="$bp/chromium_headless_shell-$have"
  if [ -d "$shell_src" ] && [ ! -e "$bp/chromium_headless_shell-$want" ]; then
    local bin
    bin=$(find "$shell_src" -maxdepth 2 -type f \( -name headless_shell -o -name chrome-headless-shell \) | head -1)
    if [ -n "$bin" ]; then
      mkdir -p "$bp/chromium_headless_shell-$want/chrome-headless-shell-linux64" \
               "$bp/chromium_headless_shell-$want/chrome-linux"
      ln -sfn "$bin" "$bp/chromium_headless_shell-$want/chrome-headless-shell-linux64/chrome-headless-shell"
      ln -sfn "$bin" "$bp/chromium_headless_shell-$want/chrome-linux/headless_shell"
      touch "$bp/chromium_headless_shell-$want/INSTALLATION_COMPLETE" \
            "$bp/chromium_headless_shell-$want/DEPENDENCIES_VALIDATED"
    fi
  fi
}

if [ -d "$GSTACK_DIR/bin" ] && [ -x "$GSTACK_DIR/browse/dist/browse" ]; then
  log "already installed ($(cat "$GSTACK_DIR/VERSION" 2>/dev/null || echo unknown))"
  exit 0
fi

# Outside the web sandbox, gstack is the developer's own install to make —
# don't clone into their home directory unasked.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ] && [ "${GSTACK_AUTO_INSTALL:-}" != "1" ]; then
  log "not installed. Install it with:"
  log "  git clone --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack"
  log "  cd ~/.claude/skills/gstack && ./setup --team"
  exit 0
fi

if ! command -v bun >/dev/null 2>&1; then
  log "bun is not installed — skipping gstack install (see https://bun.sh)"
  exit 0
fi

if [ ! -d "$GSTACK_DIR/.git" ]; then
  log "installing to $GSTACK_DIR ..."
  rm -rf "$GSTACK_DIR"
  mkdir -p "$(dirname "$GSTACK_DIR")"
  git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git "$GSTACK_DIR" >/dev/null
fi

# Chromium needs the revision alias in place before ./setup probes it, and the
# probe needs node_modules, so install deps first when this is a cold clone.
if [ ! -d "$GSTACK_DIR/node_modules/playwright-core" ]; then
  (cd "$GSTACK_DIR" && bun install --frozen-lockfile >/dev/null 2>&1) || true
fi
shim_playwright_chromium

# GSTACK_SKIP_FONTS: the emoji-font install shells out to apt, which the
# sandbox has no working path for. Only affects emoji rendering in /make-pdf.
if (cd "$GSTACK_DIR" && GSTACK_SKIP_FONTS=1 ./setup --team >/tmp/gstack-setup.log 2>&1); then
  log "ready ($(cat "$GSTACK_DIR/VERSION" 2>/dev/null || echo unknown)) — try /office-hours"
else
  log "setup failed; last lines of /tmp/gstack-setup.log:"
  tail -20 /tmp/gstack-setup.log >&2 || true
fi
