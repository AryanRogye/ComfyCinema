#!/usr/bin/env bash
# Build ComfyCinema in Release for iPhone, Mac, or both.
#
#   ./release.sh                 interactive menu
#   ./release.sh iphone          iPhone only
#   ./release.sh mac             Mac only (asks about /Applications)
#   ./release.sh both            iPhone + Mac
#
# Flags:
#   --install / --no-install     Mac: copy (or don't) to /Applications without asking
#   --open                       Mac: launch the app after installing
#   --device <name|udid>         iPhone: pick a specific device (default: first paired iPhone)
#   --no-launch                  iPhone: install but don't launch
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$PROJECT_DIR/MoviesAPIClient.xcodeproj"
SCHEME="MoviesAPIClient"
CONFIGURATION="Release"
APP_NAME="ComfyCinema"
BUNDLE_ID="com.aryanrogye.MoviesAPIClient"
DERIVED_DATA="$PROJECT_DIR/build/release"
INSTALL_DIR="/Applications"

target=""
mac_install=""      # "", yes, no
mac_open="no"
device=""
ios_launch="yes"

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
die()   { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

usage() { sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    iphone|ios)   target="iphone" ;;
    mac|macos)    target="mac" ;;
    both|all)     target="both" ;;
    --install)    mac_install="yes" ;;
    --no-install) mac_install="no" ;;
    --open)       mac_open="yes" ;;
    --device)     shift; device="${1:-}"; [[ -n "$device" ]] || die "--device needs a value" ;;
    --no-launch)  ios_launch="no" ;;
    -h|--help)    usage 0 ;;
    *)            printf 'Unknown argument: %s\n\n' "$1" >&2; usage 1 ;;
  esac
  shift
done

ask_yes_no() {  # ask_yes_no "Question" default(y/n)
  local prompt="$1" def="$2" reply
  local hint="[y/N]"; [[ "$def" == "y" ]] && hint="[Y/n]"
  read -r -p "$prompt $hint " reply || true
  reply="${reply:-$def}"
  [[ "$reply" =~ ^[Yy] ]]
}

if [[ -z "$target" ]]; then
  bold "What do you want to build (Release)?"
  echo "  1) iPhone"
  echo "  2) Mac"
  echo "  3) Both"
  read -r -p "Choose [1-3]: " choice
  case "$choice" in
    1) target="iphone" ;;
    2) target="mac" ;;
    3) target="both" ;;
    *) die "Invalid choice: $choice" ;;
  esac
fi

# Ask up front so you can walk away while it builds.
if [[ "$target" != "iphone" && -z "$mac_install" ]]; then
  if ask_yes_no "Install the Mac build to $INSTALL_DIR?" y; then
    mac_install="yes"
    ask_yes_no "Open it after installing?" n && mac_open="yes"
  else
    mac_install="no"
  fi
fi

run_build() {  # run_build <destination> <label>
  local dest="$1" label="$2"
  local log="$DERIVED_DATA/$label-build.log"
  mkdir -p "$DERIVED_DATA"
  info "Building $APP_NAME ($CONFIGURATION) for ${label}…  (log: $log)"
  local cmd=(xcodebuild
    -project "$PROJECT"
    -scheme "$SCHEME"
    -configuration "$CONFIGURATION"
    -destination "$dest"
    -derivedDataPath "$DERIVED_DATA"
    -allowProvisioningUpdates
    build)
  if command -v xcbeautify >/dev/null 2>&1; then
    "${cmd[@]}" 2>&1 | tee "$log" | xcbeautify --quiet || die "$label build failed — see $log"
  else
    "${cmd[@]}" >"$log" 2>&1 || { grep -E "error:|\*\* BUILD FAILED" "$log" | tail -20 >&2; die "$label build failed — see $log"; }
  fi
  ok "$label build succeeded"
}

find_iphone() {
  # Prints the UDID of the requested (or first paired, available) physical iPhone.
  local json; json="$(mktemp)"
  xcrun devicectl list devices --json-output "$json" >/dev/null 2>&1 || { rm -f "$json"; return 1; }
  /usr/bin/python3 - "$json" "$device" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
want = sys.argv[2].lower()
for d in data.get("result", {}).get("devices", []):
    hw, props, conn = d.get("hardwareProperties", {}), d.get("deviceProperties", {}), d.get("connectionProperties", {})
    if hw.get("reality") != "physical" or hw.get("platform") != "iOS":
        continue
    udid, name = hw.get("udid", ""), props.get("name", "")
    if want:
        if want in (udid.lower(), name.lower(), d.get("identifier", "").lower()):
            print(udid); sys.exit(0)
    elif conn.get("pairingState") == "paired":
        print(udid); sys.exit(0)
sys.exit(1)
PY
  local rc=$?
  rm -f "$json"
  return $rc
}

build_iphone() {
  local udid
  udid="$(find_iphone)" || die "No paired iPhone found${device:+ matching '$device'}. Plug it in / unlock it and try again."
  run_build "id=$udid" "iPhone"

  local app="$DERIVED_DATA/Build/Products/$CONFIGURATION-iphoneos/$APP_NAME.app"
  [[ -d "$app" ]] || die "Built app not found at $app"

  info "Installing on iPhone ($udid)…"
  xcrun devicectl device install app --device "$udid" "$app" >/dev/null \
    || die "Install failed (is the phone unlocked?)"
  ok "Installed on iPhone"

  if [[ "$ios_launch" == "yes" ]]; then
    info "Launching on iPhone…"
    xcrun devicectl device process launch --terminate-existing --device "$udid" "$BUNDLE_ID" >/dev/null \
      && ok "Launched on iPhone" \
      || printf '  (could not launch — phone probably locked; app is installed though)\n'
  fi
}

quit_running_mac_app() {
  local installed="$INSTALL_DIR/$APP_NAME.app"
  if pgrep -f "$installed/Contents/MacOS/" >/dev/null 2>&1; then
    info "Killing running $APP_NAME from ${INSTALL_DIR}…"
    pkill -f "$installed/Contents/MacOS/" || true
    for _ in {1..20}; do
      pgrep -f "$installed/Contents/MacOS/" >/dev/null 2>&1 || break
      sleep 0.25
    done
    pkill -9 -f "$installed/Contents/MacOS/" 2>/dev/null || true
  fi
}

build_mac() {
  run_build "platform=macOS" "Mac"

  local app="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
  [[ -d "$app" ]] || die "Built app not found at $app"

  if [[ "$mac_install" == "yes" ]]; then
    local dest="$INSTALL_DIR/$APP_NAME.app"
    quit_running_mac_app
    info "Copying to ${dest}…"
    rm -rf "$dest"
    ditto "$app" "$dest"
    ok "Installed to $dest"
    if [[ "$mac_open" == "yes" ]]; then
      open "$dest"
      ok "Opened $APP_NAME"
    fi
  else
    ok "Mac app is at: $app"
  fi
}

start=$SECONDS
case "$target" in
  iphone) build_iphone ;;
  mac)    build_mac ;;
  both)   build_iphone; build_mac ;;
esac
bold "All done in $((SECONDS - start))s 🎬"
