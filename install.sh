#!/usr/bin/env bash
#
# install.sh — one-line convenience installer for 38specialK
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/weefarm/38specialK/main/install.sh | bash
#
# What it does:
#   1. Verifies Go 1.25+ is installed (required to build the sk binary)
#   2. Runs `go install github.com/weefarm/38specialK/cmd/sk@latest`
#   3. Ensures $GOPATH/bin (or $GOBIN) is on $PATH for the current shell
#   4. Runs `sk init` to write the starter config (~/.config/sk/slugs.yaml)
#   5. Prints clear next steps: edit the config, then run `sk install >> ~/.bashrc`
#
# Safe to re-run. Does NOT clobber an existing config (sk init refuses without --force).
# Does NOT require sudo and errors out if invoked as root (sk is a per-user tool).
#
# Project: https://github.com/weefarm/38specialK
# License: GPL-3.0-or-later

set -euo pipefail

# --- Guards ------------------------------------------------------------------

# Refuse to run as root — sk is a per-user tool and `go install` as root puts
# the binary in /root/go/bin, which is not on the invoking user's PATH.
if [[ $EUID -eq 0 ]]; then
  echo "Error: do not run this script as root or via sudo." >&2
  echo "38specialK is a per-user tool. Run it as your normal user:" >&2
  echo "  curl -fsSL https://raw.githubusercontent.com/weefarm/38specialK/main/install.sh | bash" >&2
  exit 1
fi

# --- Helpers -----------------------------------------------------------------

err()   { echo "Error: $*" >&2; exit 1; }
info()  { echo "  $*"; }
ok()    { echo "  ✓ $*"; }

# --- Pre-flight checks -------------------------------------------------------

echo "38specialK installer"
echo ""

# Check for Go 1.25+
if ! command -v go &>/dev/null; then
  err "Go is not installed or not on PATH. Install Go 1.25+ first:
  https://go.dev/doc/install"
fi

GO_VERSION=$(go version 2>/dev/null | awk '{print $3}' | sed 's/go//')
GO_MAJOR=$(echo "$GO_VERSION" | cut -d. -f1)
GO_MINOR=$(echo "$GO_VERSION" | cut -d. -f2)

if [[ "$GO_MAJOR" -lt 1 ]] || ([[ "$GO_MAJOR" -eq 1 ]] && [[ "$GO_MINOR" -lt 25 ]]); then
  err "Go $GO_VERSION found, but 38specialK requires Go 1.25+. Upgrade Go:
  https://go.dev/doc/install"
fi
ok "Go $GO_VERSION detected"

# --- Install the sk binary ---------------------------------------------------

echo ""
echo "Installing sk binary via go install..."
if ! go install github.com/weefarm/38specialK/cmd/sk@latest; then
  err "go install failed. Check your network connection and Go setup."
fi
ok "sk installed"

# --- Ensure GOPATH/bin is on PATH --------------------------------------------

GOBIN="${GOBIN:-$(go env GOPATH)/bin}"
if [[ -z "$GOBIN" ]] || [[ "$GOBIN" == "null" ]]; then
  GOBIN="$HOME/go/bin"
fi

# Detect the user's shell rc file
SHELL_RC="$HOME/.bashrc"
if [[ -n "${ZSH_VERSION:-}" ]] && [[ -f "$HOME/.zshrc" ]]; then
  SHELL_RC="$HOME/.zshrc"
fi

PATH_EXPORT_LINE="export PATH=\"\$PATH:$GOBIN\""

if ! echo "$PATH" | tr ':' '\n' | grep -qx "$GOBIN"; then
  # Add the export to the user's shell rc so it persists across sessions
  if [[ -f "$SHELL_RC" ]] && ! grep -qF "$PATH_EXPORT_LINE" "$SHELL_RC"; then
    echo "" >> "$SHELL_RC"
    echo "# Added by 38specialK install script" >> "$SHELL_RC"
    echo "$PATH_EXPORT_LINE" >> "$SHELL_RC"
    ok "added $GOBIN to PATH in $SHELL_RC"
  elif [[ -f "$SHELL_RC" ]] && grep -qF "$PATH_EXPORT_LINE" "$SHELL_RC"; then
    ok "$GOBIN already in PATH via $SHELL_RC"
  else
    # No shell rc file found — warn the user
    echo "" >&2
    echo "Warning: could not find $SHELL_RC to add $GOBIN to PATH." >&2
    echo "Add this line to your shell rc manually:" >&2
    echo "" >&2
    echo "  $PATH_EXPORT_LINE" >&2
    echo "" >&2
  fi
  # Make sk available for the rest of this script
  PATH="$PATH:$GOBIN"
else
  ok "$GOBIN is already on PATH"
fi

# Verify sk is callable
if ! command -v sk &>/dev/null; then
  err "sk was installed to $GOBIN but is not on PATH. Add this to your shell rc:
  $PATH_EXPORT_LINE
Then run: source $SHELL_RC"
fi
ok "sk command available: $(command -v sk)"

# --- Run sk init (write starter config) --------------------------------------

echo ""
echo "Writing starter config..."
if ! sk init; then
  # sk init refuses to overwrite an existing config — that's fine on re-runs
  CONFIG_PATH="${XDG_CONFIG_HOME:-$HOME/.config}/sk/slugs.yaml"
  if [[ -f "$CONFIG_PATH" ]]; then
    ok "existing config found at $CONFIG_PATH (not overwritten)"
    info "to reset it: sk init --force"
  else
    err "sk init failed for an unknown reason."
  fi
else
  ok "starter config written to ${XDG_CONFIG_HOME:-$HOME/.config}/sk/slugs.yaml"
fi

# --- Next steps --------------------------------------------------------------

echo ""
echo "Install complete."
echo ""
echo "Next steps:"
echo "  1. Reload your shell so the PATH change takes effect:"
echo "       source $SHELL_RC"
echo "  2. Edit your config to match your namespaces:"
echo "       \$EDITOR ~/.config/sk/slugs.yaml"
echo "  3. Install shell functions into your shell rc:"
echo "       sk install >> $SHELL_RC"
echo "  4. Reload again to pick up the slug functions:"
echo "       source $SHELL_RC"
echo ""
echo "You can now use slugs like 'kclo o' instead of 'kubectl get pods -n cloudflare -o wide'."
echo "Run 'sk list' to see your configured slugs."
echo ""
echo "Docs: https://github.com/weefarm/38specialK"
