#!/usr/bin/env bash
# Build ComfyCinema in Release for iPhone, Mac, or both.
#
#   ./release.sh                 interactive TUI (arrow keys + space + enter)
#   ./release.sh iphone          iPhone only, no TUI
#   ./release.sh mac             Mac only, no TUI (asks about /Applications)
#   ./release.sh both            iPhone + Mac, no TUI
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
PREFS_FILE="$DERIVED_DATA/.release-prefs"
INSTALL_DIR="/Applications"

# ── Options (1 = on, 0 = off) ────────────────────────────────────────────────
opt_iphone=1
opt_launch=1
opt_mac=1
opt_install=1
opt_open=0

cli_target=""
cli_install=""
device=""
IPHONE_UDID=""
IPHONE_NAME=""
BUILD_PID=""

# ── Output helpers ───────────────────────────────────────────────────────────
C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_CYAN=$'\033[36m'
FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)

info() { printf '%s==>%s %s\n' "$C_CYAN$C_BOLD" "$C_RESET" "$*"; }
ok()   { printf ' %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
fail() { printf ' %s✗ %s%s\n' "$C_RED" "$*" "$C_RESET" >&2; }
die()  { fail "$*"; exit 1; }

usage() { sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

cleanup() {
  if [[ -n "$BUILD_PID" ]]; then kill "$BUILD_PID" 2>/dev/null || true; fi
  if [[ -t 1 ]]; then tput cnorm 2>/dev/null || true; fi
}
trap cleanup EXIT
trap 'printf "\n"; exit 130' INT TERM

# ── Args ─────────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    iphone|ios)   cli_target="iphone" ;;
    mac|macos)    cli_target="mac" ;;
    both|all)     cli_target="both" ;;
    --install)    cli_install=1 ;;
    --no-install) cli_install=0 ;;
    --open)       opt_open=1 ;;
    --device)     shift; device="${1:-}"; [[ -n "$device" ]] || die "--device needs a value" ;;
    --no-launch)  opt_launch=0 ;;
    -h|--help)    usage 0 ;;
    *)            printf 'Unknown argument: %s\n\n' "$1" >&2; usage 1 ;;
  esac
  shift
done

# ── iPhone detection ─────────────────────────────────────────────────────────
detect_iphone() {
  # Sets IPHONE_UDID / IPHONE_NAME for the requested (or first paired) physical iPhone.
  IPHONE_UDID=""; IPHONE_NAME=""
  local json found
  json="$(mktemp)"
  if xcrun devicectl list devices --json-output "$json" >/dev/null 2>&1; then
    found="$(/usr/bin/python3 - "$json" "$device" <<'PY' || true
import json, sys
data = json.load(open(sys.argv[1]))
want = sys.argv[2].lower()
for d in data.get("result", {}).get("devices", []):
    hw, props, conn = d.get("hardwareProperties", {}), d.get("deviceProperties", {}), d.get("connectionProperties", {})
    if hw.get("reality") != "physical" or hw.get("platform") != "iOS":
        continue
    udid, name = hw.get("udid", ""), props.get("name", "")
    if (want and want in (udid.lower(), name.lower(), d.get("identifier", "").lower())) \
       or (not want and conn.get("pairingState") == "paired"):
        print(f"{udid}\t{name}")
        break
PY
)"
    if [[ -n "$found" ]]; then
      IPHONE_UDID="${found%%$'\t'*}"
      IPHONE_NAME="${found#*$'\t'}"
    fi
  fi
  rm -f "$json"
}

# ── Remembered choices (TUI only) ────────────────────────────────────────────
load_prefs() {
  [[ -f "$PREFS_FILE" ]] || return 0
  local k v
  while IFS='=' read -r k v; do
    case "$k" in
      opt_iphone|opt_launch|opt_mac|opt_install|opt_open)
        [[ "$v" == [01] ]] && printf -v "$k" '%s' "$v" ;;
    esac
  done <"$PREFS_FILE"
  return 0
}

save_prefs() {
  mkdir -p "$DERIVED_DATA"
  printf 'opt_iphone=%s\nopt_launch=%s\nopt_mac=%s\nopt_install=%s\nopt_open=%s\n' \
    "$opt_iphone" "$opt_launch" "$opt_mac" "$opt_install" "$opt_open" >"$PREFS_FILE"
}

# ── TUI ──────────────────────────────────────────────────────────────────────
ROWS=5
cur=0
menu_lines=0
status_msg=""

row_info() {  # sets R_LABEL R_VAL R_SUB R_ENABLED for row $1
  case "$1" in
    0) R_LABEL="iPhone";                          R_VAL=$opt_iphone;  R_SUB=0; R_ENABLED=$([[ -n "$IPHONE_UDID" ]] && echo 1 || echo 0) ;;
    1) R_LABEL="Launch on iPhone after install";  R_VAL=$opt_launch;  R_SUB=1; R_ENABLED=$opt_iphone ;;
    2) R_LABEL="Mac";                             R_VAL=$opt_mac;     R_SUB=0; R_ENABLED=1 ;;
    3) R_LABEL="Install to /Applications";        R_VAL=$opt_install; R_SUB=1; R_ENABLED=$opt_mac ;;
    4) R_LABEL="Open after install";              R_VAL=$opt_open;    R_SUB=1; R_ENABLED=$(( opt_mac && opt_install )) ;;
  esac
}

row_enabled() { row_info "$1"; [[ "$R_ENABLED" == 1 ]]; }

toggle_row() {
  case "$cur" in
    0) opt_iphone=$((1 - opt_iphone)) ;;
    1) opt_launch=$((1 - opt_launch)) ;;
    2) opt_mac=$((1 - opt_mac)) ;;
    3) opt_install=$((1 - opt_install)) ;;
    4) opt_open=$((1 - opt_open)) ;;
  esac
}

move_cursor() {  # move_cursor +1|-1, skipping disabled rows
  local n=$cur _
  for _ in 1 2 3 4 5; do
    n=$(( (n + $1 + ROWS) % ROWS ))
    if row_enabled "$n"; then cur=$n; return; fi
  done
}

draw_menu() {
  local lines=() i pointer box text phone
  if [[ -n "$IPHONE_UDID" ]]; then
    phone="📱 ${IPHONE_NAME:-iPhone} connected"
  else
    phone="${C_YELLOW}📱 No iPhone found — plug it in & unlock, then press r${C_RESET}"
  fi

  lines+=("${C_BOLD}🎬 ComfyCinema · $CONFIGURATION build${C_RESET}")
  lines+=("${C_DIM}$phone${C_RESET}")
  lines+=("")
  for ((i = 0; i < ROWS; i++)); do
    row_info "$i"
    [[ $i -eq $cur ]] && pointer="${C_CYAN}❯${C_RESET}" || pointer=" "
    if [[ "$R_VAL" == 1 ]]; then box="${C_GREEN}◉${C_RESET}"; else box="◯"; fi
    text="$R_LABEL"
    [[ "$R_SUB" == 1 ]] && text="  └ $text"
    if [[ "$R_ENABLED" != 1 ]]; then
      lines+=(" $pointer ${C_DIM}◯ $text${C_RESET}")
    elif [[ $i -eq $cur ]]; then
      lines+=(" $pointer $box ${C_BOLD}$text${C_RESET}")
    else
      lines+=(" $pointer $box $text")
    fi
    [[ $i -eq 1 ]] && lines+=("")
  done
  lines+=("")
  lines+=("${C_DIM}↑/↓ or j/k move · space toggle · r rescan iPhone · enter build · q quit${C_RESET}")
  lines+=("$status_msg")

  if (( menu_lines > 0 )); then printf '\033[%dA' "$menu_lines"; fi
  for text in "${lines[@]}"; do printf '\033[2K%s\n' "$text"; done
  menu_lines=${#lines[@]}
}

run_tui() {
  [[ -t 0 && -t 1 ]] || die "Not a terminal — pass iphone, mac or both instead."

  printf '%sLooking for your iPhone…%s' "$C_DIM" "$C_RESET"
  detect_iphone
  printf '\r\033[2K'

  load_prefs
  [[ -n "$IPHONE_UDID" ]] || opt_iphone=0
  cur=0; row_enabled 0 || cur=2

  tput civis
  local key rest
  while true; do
    draw_menu
    status_msg=""
    IFS= read -rsn1 key || exit 1
    case "$key" in
      $'\033')
        IFS= read -rsn2 rest || true
        case "$rest" in
          '[A'|'OA') move_cursor -1 ;;
          '[B'|'OB') move_cursor 1 ;;
        esac ;;
      k) move_cursor -1 ;;
      j) move_cursor 1 ;;
      ' ') row_enabled "$cur" && toggle_row ;;
      r|R)
        status_msg="${C_DIM}Scanning…${C_RESET}"; draw_menu
        detect_iphone
        if [[ -n "$IPHONE_UDID" ]]; then status_msg="${C_GREEN}Found ${IPHONE_NAME}${C_RESET}"
        else opt_iphone=0; status_msg="${C_YELLOW}Still no iPhone${C_RESET}"; fi ;;
      q|Q) tput cnorm; printf 'Bye 👋\n'; exit 0 ;;
      '')
        if (( opt_iphone || opt_mac )); then break; fi
        status_msg="${C_RED}Pick at least one: iPhone or Mac${C_RESET}" ;;
    esac
  done
  tput cnorm
  save_prefs
  echo
}

# ── Running steps with a spinner ─────────────────────────────────────────────
build_step() {  # Summarise the latest xcodebuild action from the log, e.g. "SwiftCompile · MoviesAPICore · HomeView.swift"
  local line action target file
  line="$(tail -n 300 "$1" 2>/dev/null \
    | grep -E '^(SwiftCompile|CompileSwift|SwiftEmitModule|SwiftDriver|CompileC|Ld|CodeSign|CompileAssetCatalog|ProcessInfoPlistFile|CopySwiftLibs|ProcessProductPackaging|GenerateAssetSymbols|ExtractAppIntentsMetadata|ValidateEmbeddedBinary|Validate|CopyStringsFile|CompileXCStrings|Resolve Package Graph|Fetching|Cloning|Computing)' \
    | tail -n 1)" || true
  [[ -n "$line" ]] || { printf 'preparing…'; return; }
  action="${line%% *}"
  target="$(printf '%s' "$line" | sed -n "s/.*(in target '\([^']*\)'.*/\1/p")"
  if [[ "$line" == *'Compiling\ '* ]]; then
    # "SwiftCompile normal arm64 Compiling\ A.swift,\ B.swift /path/A.swift ..." → "A.swift +1"
    local names count
    names="${line#*Compiling\\ }"; names="${names%% /*}"
    count=$(printf '%s' "$names" | tr -cd ',' | wc -c | tr -d ' ')
    file="${names%%,*}"
    (( count > 0 )) && file="$file +$count"
  else
    file="$(printf '%s' "$line" | grep -oE '/[^/ ]+\.(swift|m|mm|c|xcassets|xcstrings|plist|app|appex|dylib|o)( |$)' | tail -n 1 | tr -d '/ ')" || true
  fi
  printf '%s' "$action${target:+ · $target}${file:+ · $file}"
}

spin() {  # spin <label> <log> <step-fn|""> <cmd...>
  local label="$1" log="$2" stepfn="$3"; shift 3
  local t0=$SECONDS rc=0
  mkdir -p "$(dirname "$log")"

  if [[ ! -t 1 ]]; then
    info "$label…"
    "$@" >"$log" 2>&1 || rc=$?
    [[ $rc -eq 0 ]] && ok "$label" || fail "$label"
    return $rc
  fi

  "$@" >"$log" 2>&1 &
  BUILD_PID=$!
  tput civis
  local i=0 step="" cols max
  cols=$(tput cols 2>/dev/null || echo 80)
  while kill -0 "$BUILD_PID" 2>/dev/null; do
    if [[ -n "$stepfn" && $((i % 3)) -eq 0 ]]; then step="$($stepfn "$log")"; fi
    max=$(( cols - ${#label} - 14 ))
    (( max < 0 )) && max=0
    (( ${#step} > max )) && step="${step:0:max}"
    printf '\r\033[2K %s%s%s %s %s%ss%s%s' \
      "$C_CYAN" "${FRAMES[i % 10]}" "$C_RESET" "$label" \
      "$C_DIM" "$((SECONDS - t0))" "${step:+  $step}" "$C_RESET"
    sleep 0.1
    i=$((i + 1))
  done
  wait "$BUILD_PID" || rc=$?
  BUILD_PID=""
  printf '\r\033[2K'
  tput cnorm
  if [[ $rc -eq 0 ]]; then ok "$label ${C_DIM}($((SECONDS - t0))s)${C_RESET}"; else fail "$label"; fi
  return $rc
}

show_errors() {  # show_errors <log>
  local errs
  errs="$(grep -E 'error:' "$1" | grep -v 'dependency scanning failure' | sort -u | head -n 15)" || true
  [[ -n "$errs" ]] || errs="$(tail -n 15 "$1")"
  printf '%s\n' "$errs" | sed "s|$PROJECT_DIR/||; s/^/   /" >&2
  printf '   %sFull log: %s%s\n' "$C_DIM" "$1" "$C_RESET" >&2
}

xcbuild() {  # xcbuild <destination>
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$1" \
    -derivedDataPath "$DERIVED_DATA" \
    -allowProvisioningUpdates \
    build
}

# ── iPhone ───────────────────────────────────────────────────────────────────
build_iphone() {
  echo
  printf '%s📱 iPhone%s\n' "$C_BOLD" "$C_RESET"
  [[ -n "$IPHONE_UDID" ]] || detect_iphone
  [[ -n "$IPHONE_UDID" ]] || { fail "No paired iPhone found${device:+ matching '$device'} — plug it in & unlock it"; return 1; }

  local log="$DERIVED_DATA/iPhone-build.log"
  spin "Building for ${IPHONE_NAME:-iPhone}" "$log" build_step xcbuild "id=$IPHONE_UDID" \
    || { show_errors "$log"; return 1; }

  local app="$DERIVED_DATA/Build/Products/$CONFIGURATION-iphoneos/$APP_NAME.app"
  [[ -d "$app" ]] || { fail "Built app not found at $app"; return 1; }

  log="$DERIVED_DATA/iPhone-install.log"
  spin "Installing on ${IPHONE_NAME:-iPhone}" "$log" "" \
    xcrun devicectl device install app --device "$IPHONE_UDID" "$app" \
    || { show_errors "$log"; return 1; }

  if [[ "$opt_launch" == 1 ]]; then
    spin "Launching" "$DERIVED_DATA/iPhone-launch.log" "" \
      xcrun devicectl device process launch --terminate-existing --device "$IPHONE_UDID" "$BUNDLE_ID" \
      || printf '   %s(phone probably locked — the app is installed though)%s\n' "$C_DIM" "$C_RESET"
  fi
}

# ── Mac ──────────────────────────────────────────────────────────────────────
quit_installed_mac_app() {
  local exe="$INSTALL_DIR/$APP_NAME.app/Contents/MacOS/"
  pgrep -f "$exe" >/dev/null 2>&1 || return 0
  pkill -f "$exe" || true
  local _
  for _ in {1..20}; do
    pgrep -f "$exe" >/dev/null 2>&1 || return 0
    sleep 0.25
  done
  pkill -9 -f "$exe" 2>/dev/null || true
}

install_mac_app() {  # install_mac_app <built.app>
  local dest="$INSTALL_DIR/$APP_NAME.app"
  quit_installed_mac_app
  rm -rf "$dest"
  ditto "$1" "$dest"
}

build_mac() {
  echo
  printf '%s💻 Mac%s\n' "$C_BOLD" "$C_RESET"
  local log="$DERIVED_DATA/Mac-build.log"
  spin "Building for Mac" "$log" build_step xcbuild "platform=macOS" \
    || { show_errors "$log"; return 1; }

  local app="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
  [[ -d "$app" ]] || { fail "Built app not found at $app"; return 1; }

  if [[ "$opt_install" == 1 ]]; then
    spin "Installing to $INSTALL_DIR (quitting running copy)" "$DERIVED_DATA/Mac-install.log" "" \
      install_mac_app "$app" || { show_errors "$DERIVED_DATA/Mac-install.log"; return 1; }
    if [[ "$opt_open" == 1 ]]; then
      open "$INSTALL_DIR/$APP_NAME.app" && ok "Opened $APP_NAME"
    fi
  else
    ok "App is at ${C_DIM}${app#"$PROJECT_DIR/"}${C_RESET}"
  fi
}

# ── Main ─────────────────────────────────────────────────────────────────────
ask_yes_no() {  # ask_yes_no "Question" default(y/n)
  local reply hint="[y/N]"
  [[ "$2" == "y" ]] && hint="[Y/n]"
  read -r -p "$1 $hint " reply || true
  reply="${reply:-$2}"
  [[ "$reply" =~ ^[Yy] ]]
}

if [[ -z "$cli_target" ]]; then
  run_tui
else
  case "$cli_target" in
    iphone) opt_iphone=1; opt_mac=0 ;;
    mac)    opt_iphone=0; opt_mac=1 ;;
    both)   opt_iphone=1; opt_mac=1 ;;
  esac
  if [[ "$opt_mac" == 1 ]]; then
    if [[ -n "$cli_install" ]]; then
      opt_install=$cli_install
    elif ask_yes_no "Install the Mac build to $INSTALL_DIR?" y; then
      opt_install=1
    else
      opt_install=0
    fi
  fi
fi

start=$SECONDS
failed=()
if [[ "$opt_iphone" == 1 ]]; then build_iphone || failed+=("iPhone"); fi
if [[ "$opt_mac" == 1 ]]; then build_mac || failed+=("Mac"); fi

echo
if [[ ${#failed[@]} -eq 0 ]]; then
  printf '%s🎬 All done in %ss%s\n' "$C_BOLD$C_GREEN" "$((SECONDS - start))" "$C_RESET"
else
  printf '%s✗ Failed: %s%s  %s(%ss)%s\n' "$C_BOLD$C_RED" "${failed[*]}" "$C_RESET" "$C_DIM" "$((SECONDS - start))" "$C_RESET"
  exit 1
fi
