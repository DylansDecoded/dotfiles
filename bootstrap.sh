#!/usr/bin/env bash
# Fresh-Mac entrypoint. Safe to re-run (idempotent).
#
#   curl -fsSL https://raw.githubusercontent.com/DylansDecoded/dotfiles/main/bootstrap.sh | bash
#
# Handles the chicken-and-egg setup that must exist before `just` can run, then
# hands off to the Justfile for everything else.
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
REPO_URL="${REPO_URL:-https://github.com/DylansDecoded/dotfiles.git}"

log() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }

# 1. Xcode Command Line Tools (provides git, compilers).
if ! xcode-select -p >/dev/null 2>&1; then
  log "Installing Xcode Command Line Tools — complete the GUI prompt, then re-run this script."
  xcode-select --install || true
  exit 1
fi

# 2. Homebrew.
if ! command -v brew >/dev/null 2>&1; then
  log "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# 3. Minimal toolchain needed to run the Justfile. The 1Password app ships here too
#    (not just the CLI) so you can enable Settings -> Developer -> "Integrate with
#    1Password CLI" before the op-gated secrets/ssh steps run.
log "Installing bootstrap toolchain (just stow age sops jq 1password-cli + 1Password app)"
brew install just stow age sops jq 1password-cli
brew install --cask 1password

# 4. Clone (or update) the repo.
if [ ! -d "$DOTFILES_DIR/.git" ]; then
  log "Cloning $REPO_URL -> $DOTFILES_DIR"
  git clone "$REPO_URL" "$DOTFILES_DIR"
else
  log "Repo already present at $DOTFILES_DIR"
fi

# 5. Hand off to the Justfile.
cd "$DOTFILES_DIR"
log "Running 'just install' — see README for what each step does"
just install
