#!/usr/bin/env bash
# Fresh-Mac entrypoint. Safe to re-run (idempotent).
#
#   curl -fsSL https://raw.githubusercontent.com/DylansDecoded/dotfiles/main/bootstrap.sh | bash
#
# Installs what must exist before mise can run, then hands off to `mise bootstrap`.
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
REPO_URL="${REPO_URL:-https://github.com/DylansDecoded/dotfiles.git}"
MACHINE="${MACHINE:-macos}"

log() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }

# 1. Xcode Command Line Tools (provides git, compilers).
if ! xcode-select -p >/dev/null 2>&1; then
  log "Installing Xcode Command Line Tools — complete the GUI prompt, then re-run this script."
  xcode-select --install || true
  exit 1
fi

# 2. Homebrew. Find existing installs even before shell profiles are deployed.
brew_env() {
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}
brew_env
if ! command -v brew >/dev/null 2>&1; then
  log "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  brew_env
fi

# 3. Secrets toolchain. The 1Password app ships here too (not just the CLI) so you can
#    enable Settings -> Developer -> "Integrate with 1Password CLI" before `mise run secrets`.
log "Installing bootstrap toolchain (age sops jq 1password-cli + 1Password app)"
brew install age sops jq 1password-cli
brew install --cask 1password

# 4. mise, from the official installer so it can `mise self-update`.
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
if ! command -v mise >/dev/null 2>&1; then
  log "Installing mise"
  curl -fsSL https://mise.run | sh
fi

# 5. Clone (or update) the repo, including submodules (e.g. advisor-strategy skill).
if [ ! -e "$DOTFILES_DIR/.git" ]; then
  log "Cloning $REPO_URL -> $DOTFILES_DIR"
  git clone --recurse-submodules "$REPO_URL" "$DOTFILES_DIR"
else
  log "Repo already present at $DOTFILES_DIR"
  git -C "$DOTFILES_DIR" submodule update --init --recursive
fi

# 6. Pin this host's overlay (mise.<machine>.toml) once; the file stays untracked.
mkdir -p "$HOME/.config/mise"
if [ ! -e "$HOME/.config/mise/miserc.toml" ]; then
  printf 'env = ["%s"]\n' "$MACHINE" > "$HOME/.config/mise/miserc.toml"
fi

# 7. Links dotfiles, installs [tools], then runs the bootstrap task (mise-tasks/bootstrap).
cd "$DOTFILES_DIR"
mise trust mise.toml
mise trust "mise.$MACHINE.toml"
log "Running 'mise bootstrap' — see README for what each step does"
mise bootstrap --yes
