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

if ! echo "$PATH" | tr ':' '\n' | grep -qx "$GOBIN"; then
  echo ""
  echo "Warning: $GOBIN is not on your PATH." >&2
  echo "Add this line to your ~/.bashrc (or ~/.zshrc):" >&2
  echo "" >&2
  echo "  export PATH=\"\$PATH:$GOBIN\"" >&2
  echo "" >&2
  echo "Then run: source ~/.bashrc" >&2
  PATH="$PATH:$GOBIN"
fi
ok "sk is on PATH at $GOBIN"

# Verify sk is callable
if ! command -v sk &>/dev/null; then
  err "sk was installed but is not on PATH. Add $GOBIN to your PATH and re-run."
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
echo "  1. Edit your config:  \$EDITOR ~/.config/sk/slugs.yaml"
echo "  2. Install shell functions into your shell rc:"
echo "       sk install >> ~/.bashrc"
echo "  3. Reload your shell:"
echo "       source ~/.bashrc"
echo ""
echo "You can now use slugs like 'kclo o' instead of 'kubectl get pods -n cloudflare -o wide'."
echo "Run 'sk list' to see your configured slugs."
echo ""
echo "Docs: https://github.com/weefarm/38specialK"
