#!/usr/bin/env bash
# Run after cloning, before building MoviesAPIClient.
# Requires Git, GNU Make, Node.js/npm, jq, and rsync. This script is never run by Xcode.
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_commit="bfb3440ff399a3be5d928117dea2e35769fa3cdb"
local_source="$project_root/references/uBlock"
cached_source="$project_root/.build/ublock-src"
destination="$project_root/MoviesAPIClient/Resources/uBOLite"

for command_name in git node npm jq rsync; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing $command_name. Install it, then run this script again." >&2
    exit 1
  fi
done

if command -v gmake >/dev/null 2>&1; then
  make_command="$(command -v gmake)"
elif command -v make >/dev/null 2>&1 && make --version 2>/dev/null | head -n 1 | grep -q 'GNU Make'; then
  make_command="$(command -v make)"
else
  echo "GNU Make is required. Install it, then run this script again." >&2
  exit 1
fi

if [[ -e "$local_source/.git" ]] &&
   [[ "$(git -C "$local_source" rev-parse HEAD)" == "$source_commit" ]]; then
  source_dir="$local_source"
else
  source_dir="$cached_source"
  if [[ ! -e "$source_dir/.git" ]]; then
    mkdir -p "$(dirname "$source_dir")"
    git clone --filter=blob:none --no-checkout https://github.com/gorhill/uBlock.git "$source_dir"
  fi
  git -C "$source_dir" checkout --detach "$source_commit"
fi

git -C "$source_dir" submodule update --init \
  platform/mv3/extension/lib/codemirror/codemirror-ubol \
  platform/mv3/extension/lib/s14e-serializer
"$make_command" -C "$source_dir" mv3-safari

built_extension="$source_dir/dist/build/uBOLite.safari"
for ruleset in ublock-filters easylist easyprivacy; do
  test -f "$built_extension/rulesets/main/$ruleset.json"
done

staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/moviesapiclient-ubol.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
rsync -a \
  --exclude='/log.txt' \
  --exclude='/rulesets/debug/' \
  --exclude='/rulesets/main/*.json' \
  "$built_extension/" "$staging_dir/"
mkdir -p "$staging_dir/rulesets/main"
for ruleset in ublock-filters easylist easyprivacy; do
  cp "$built_extension/rulesets/main/$ruleset.json" "$staging_dir/rulesets/main/"
done

node - "$staging_dir/manifest.json" <<'NODE'
const fs = require('fs');
const manifestPath = process.argv[2];
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
manifest.declarative_net_request.rule_resources =
  manifest.declarative_net_request.rule_resources.filter(rule => ['ublock-filters', 'easylist', 'easyprivacy'].includes(rule.id));
const rules = manifest.declarative_net_request.rule_resources;
if (rules.length !== 3 || rules.some(rule => !fs.existsSync(require('path').join(require('path').dirname(manifestPath), rule.path)))) {
  throw new Error('Missing required uBO Lite rulesets');
}
fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
NODE

test -f "$staging_dir/LICENSE.txt"
test -f "$staging_dir/rulesets/scripting/scriptlet/main/ublock-filters.js"
mkdir -p "$destination"
rsync -a --delete "$staging_dir/" "$destination/"
echo "Installed uBO Lite at $destination"
