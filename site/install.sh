#!/usr/bin/env bash
# ♛ Miss M — one-line installer
# Usage:  curl -fsSL https://elevarel.github.io/miss-m/install.sh | bash
#
# What this does:
#   1. Verifies macOS 14.0+ and the Xcode Command Line Tools
#   2. Clones (or updates) the Miss M repo under ~/.missm/src
#   3. Builds the app with xcodebuild
#   4. Installs Miss M.app into /Applications (or ~/Applications if /Applications is not writable)
#   5. Prints next steps
#
# No sudo is used. Nothing is written outside ~/.missm, ~/Applications, and /Applications.

set -euo pipefail

readonly REPO_URL="${MISSM_REPO:-https://github.com/elevarel/miss-m.git}"
readonly BRANCH="${MISSM_BRANCH:-main}"
readonly SRC_DIR="${HOME}/.missm/src"
readonly BUILD_DIR="${HOME}/.missm/build"
readonly APP_NAME="Miss M.app"
readonly MIN_MACOS_MAJOR=14

# ── Styling ──────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; ROSE=$'\033[38;5;205m'; DEEP=$'\033[38;5;162m'
  GREEN=$'\033[32m'; RED=$'\033[31m'; RESET=$'\033[0m'
else
  BOLD=""; DIM=""; ROSE=""; DEEP=""; GREEN=""; RED=""; RESET=""
fi

banner() {
  printf "\n%s♛ Miss M%s %s— your personal AI assistant for macOS%s\n\n" "$ROSE$BOLD" "$RESET" "$DIM" "$RESET"
}
step() { printf "%s➜%s %s\n" "$DEEP" "$RESET" "$1"; }
ok()   { printf "%s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
die()  { printf "%s✗%s %s\n" "$RED" "$RESET" "$1" >&2; exit 1; }

banner

# ── 1. Checks ────────────────────────────────────────────────────────────────
step "Checking system requirements..."

[[ "$(uname -s)" == "Darwin" ]] || die "Miss M is macOS-only. Detected: $(uname -s)"

macos_version="$(sw_vers -productVersion)"
macos_major="${macos_version%%.*}"
if (( macos_major < MIN_MACOS_MAJOR )); then
  die "Miss M requires macOS ${MIN_MACOS_MAJOR}.0+. You are on ${macos_version}."
fi
ok "macOS ${macos_version}"

if ! xcode-select -p >/dev/null 2>&1; then
  step "Installing Xcode Command Line Tools (Apple prompt will appear)..."
  xcode-select --install || true
  printf "  %sWhen the installer finishes, re-run this command.%s\n" "$DIM" "$RESET"
  exit 0
fi
ok "Xcode Command Line Tools present"

command -v git >/dev/null 2>&1 || die "git not found."
command -v xcodebuild >/dev/null 2>&1 || die "xcodebuild not found. Install the full Xcode from the App Store."
ok "Toolchain ready"

# ── 2. Fetch source ──────────────────────────────────────────────────────────
mkdir -p "$(dirname "$SRC_DIR")"
if [[ -d "$SRC_DIR/.git" ]]; then
  step "Updating Miss M source (${BRANCH})..."
  git -C "$SRC_DIR" fetch --quiet origin "$BRANCH"
  git -C "$SRC_DIR" checkout --quiet "$BRANCH"
  git -C "$SRC_DIR" reset --quiet --hard "origin/${BRANCH}"
else
  step "Cloning Miss M into ${SRC_DIR}..."
  git clone --quiet --branch "$BRANCH" --depth 1 "$REPO_URL" "$SRC_DIR"
fi
ok "Source ready"

# ── 3. Build ─────────────────────────────────────────────────────────────────
step "Building Miss M (this can take a minute on first run)..."
pushd "$SRC_DIR" >/dev/null

xcodebuild \
  -project MissM.xcodeproj \
  -scheme MissM \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  -quiet \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

built_app="$(find "$BUILD_DIR/Build/Products" -maxdepth 3 -name 'MissM.app' -type d | head -n1 || true)"
[[ -n "$built_app" ]] || die "Build succeeded but MissM.app was not found."
ok "Built $built_app"

popd >/dev/null

# ── 4. Install ───────────────────────────────────────────────────────────────
if [[ -w "/Applications" ]]; then
  install_dir="/Applications"
else
  install_dir="${HOME}/Applications"
  mkdir -p "$install_dir"
fi

dest="${install_dir}/${APP_NAME}"
step "Installing to ${dest}..."
# Kill a running instance so we can replace the bundle
pkill -f "${APP_NAME}/Contents/MacOS/MissM" 2>/dev/null || true
pkill -f "MissM.app/Contents/MacOS/MissM" 2>/dev/null || true
rm -rf "$dest"
cp -R "$built_app" "$dest"
ok "Installed"

# ── 5. Done ──────────────────────────────────────────────────────────────────
printf "\n%sMiss M is ready.%s\n\n" "$BOLD$ROSE" "$RESET"
printf "  Open from Spotlight:   %sMiss M%s\n" "$BOLD" "$RESET"
printf "  Or launch now:         %sopen \"%s\"%s\n\n" "$DIM" "$dest" "$RESET"
printf "  On first launch she will ask for your Anthropic API key.\n"
printf "  Get one free at %shttps://console.anthropic.com/%s\n\n" "$DIM" "$RESET"
printf "  Update later:  %scurl -fsSL https://elevarel.github.io/miss-m/install.sh | bash%s\n" "$DIM" "$RESET"
printf "  Uninstall:     %srm -rf \"%s\" \"${HOME}/.missm\"%s\n\n" "$DIM" "$dest" "$RESET"

open "$dest" >/dev/null 2>&1 || true
