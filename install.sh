#!/bin/bash
# =============================================================================
# SCRIPT: install_chdman.sh
# DESCRIPTION: Installs chdman globally on macOS (Intel + Apple Silicon)
# FEATURES:
#   - Bulletproof: validates each step and exits on failure
#   - Idempotent: safe to re-run multiple times
#   - Verbose: prints progress for every step
#   - Cross-arch: detects Intel (/usr/local) vs Apple Silicon (/opt/homebrew)
# USAGE: chmod +x install_chdman.sh && ./install_chdman.sh
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# -----------------------------------------------------------------------
# COLORS — makes output easier to scan
# -----------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
log_ok()      { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# -----------------------------------------------------------------------
# GUARD: macOS only
# -----------------------------------------------------------------------
if [[ "$(uname -s)" != "Darwin" ]]; then
    log_error "This script is for macOS only. Detected OS: $(uname -s)"
    exit 1
fi

echo ""
echo "============================================================"
echo "   chdman Installer for macOS (Intel + Apple Silicon)"
echo "============================================================"
echo ""

# -----------------------------------------------------------------------
# STEP 1 — Detect architecture and set Homebrew prefix
# -----------------------------------------------------------------------
log_info "Detecting system architecture..."
ARCH="$(uname -m)"
if [[ "$ARCH" == "arm64" ]]; then
    BREW_PREFIX="/opt/homebrew"
    log_ok "Apple Silicon (arm64) detected. Homebrew prefix: $BREW_PREFIX"
elif [[ "$ARCH" == "x86_64" ]]; then
    BREW_PREFIX="/usr/local"
    log_ok "Intel (x86_64) detected. Homebrew prefix: $BREW_PREFIX"
else
    log_error "Unknown architecture: $ARCH"
    exit 1
fi

GLOBAL_BIN_DIR="$BREW_PREFIX/bin"

# -----------------------------------------------------------------------
# STEP 2 — Ensure Homebrew is installed
# -----------------------------------------------------------------------
log_info "Checking for Homebrew..."
if command -v brew &>/dev/null; then
    log_ok "Homebrew already installed at: $(command -v brew)"
else
    log_warn "Homebrew not found. Installing now..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
        || { log_error "Homebrew installation failed."; exit 1; }

    # Apple Silicon shells may need the brew shellenv evaluated post-install
    if [[ -x "$BREW_PREFIX/bin/brew" ]]; then
        eval "$("$BREW_PREFIX/bin/brew" shellenv)"
    fi

    log_ok "Homebrew installed successfully."
fi

# Sanity-check: brew must be callable after the block above
if ! command -v brew &>/dev/null; then
    log_error "brew command still not found after installation. Check your PATH."
    exit 1
fi

# -----------------------------------------------------------------------
# STEP 3 — Update Homebrew
# -----------------------------------------------------------------------
log_info "Updating Homebrew..."
brew update && log_ok "Homebrew updated." \
    || log_warn "brew update returned non-zero (non-fatal, continuing)."

# -----------------------------------------------------------------------
# STEP 4 — Install or upgrade rom-tools
# -----------------------------------------------------------------------
log_info "Checking for rom-tools..."
if brew list rom-tools &>/dev/null; then
    log_warn "rom-tools already installed. Attempting upgrade..."
    brew upgrade rom-tools \
        && log_ok "rom-tools upgraded." \
        || log_warn "No upgrade available or upgrade failed (non-fatal)."
else
    log_info "Installing rom-tools via Homebrew..."
    brew install rom-tools \
        || { log_error "Failed to install rom-tools."; exit 1; }
    log_ok "rom-tools installed successfully."
fi

# -----------------------------------------------------------------------
# STEP 5 — Locate the chdman binary installed by Homebrew
# -----------------------------------------------------------------------
log_info "Locating chdman binary..."
CHDMAN_SOURCE="$(brew --prefix rom-tools)/bin/chdman"

if [[ ! -x "$CHDMAN_SOURCE" ]]; then
    log_error "chdman binary not found at expected path: $CHDMAN_SOURCE"
    log_error "Run 'brew info rom-tools' to inspect the installed files."
    exit 1
fi
log_ok "chdman found at: $CHDMAN_SOURCE"

# -----------------------------------------------------------------------
# STEP 6 — Create or refresh the global symlink
# -----------------------------------------------------------------------
SYMLINK_TARGET="$GLOBAL_BIN_DIR/chdman"
log_info "Linking chdman into $GLOBAL_BIN_DIR ..."

# ln -sf replaces an existing symlink safely (idempotent)
if ln -sf "$CHDMAN_SOURCE" "$SYMLINK_TARGET" 2>/dev/null; then
    log_ok "Symlink created: $SYMLINK_TARGET -> $CHDMAN_SOURCE"
else
    log_warn "Could not write to $GLOBAL_BIN_DIR without elevated privileges. Retrying with sudo..."
    sudo ln -sf "$CHDMAN_SOURCE" "$SYMLINK_TARGET" \
        || { log_error "sudo ln failed. Check permissions on $GLOBAL_BIN_DIR"; exit 1; }
    log_ok "Symlink created (via sudo): $SYMLINK_TARGET -> $CHDMAN_SOURCE"
fi

# -----------------------------------------------------------------------
# STEP 7 — Verify the installation end-to-end
# -----------------------------------------------------------------------
log_info "Verifying chdman is reachable in PATH..."
if command -v chdman &>/dev/null; then
    RESOLVED="$(command -v chdman)"
    VERSION="$(chdman | head -1 2>/dev/null || true)"
    log_ok "chdman is globally available at: $RESOLVED"
    [[ -n "$VERSION" ]] && log_ok "Version string: $VERSION"
else
    log_error "chdman is not in PATH after linking. Ensure $GLOBAL_BIN_DIR is in your PATH."
    log_error "Add this to your shell profile:  export PATH=\"$GLOBAL_BIN_DIR:\$PATH\""
    exit 1
fi

# -----------------------------------------------------------------------
# DONE
# -----------------------------------------------------------------------
echo ""
echo "============================================================"
echo -e "  ${GREEN}Installation complete!${NC} Run: chdman --help"
echo "============================================================"
echo ""
