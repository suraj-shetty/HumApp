#!/bin/bash
#
# Architectural containment checks. See docs/v1-musickit/ARCHITECTURE.md §1.
#
# Two rules hold this codebase's layering together. Both are checkable on
# purpose — an architectural rule nobody can verify is a wish, not a rule.
#
#   1. Only Services/Adapters/* may import MusicKit.
#      This is what lets every screen build and run in the Simulator against
#      preview services, despite MusicKit not functioning there at all
#      (DECISIONS M-09).
#
#   2. Only DesignSystem/GlassSurface.swift may call .glassEffect().
#      This makes the brief's "content views never render as glass" acceptance
#      criterion mechanically checkable instead of a matter of discipline.
#
# Both checks strip `//` line comments before matching. Without that, prose
# *about* the rules trips the rules — a doc comment reading "this file may not
# import MusicKit" would fail the build it is explaining.
#
# Run standalone from the repo root, or as an Xcode run-script build phase.

set -uo pipefail

ROOT="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$ROOT" || exit 1

status=0

# Print `file:line: error: message` for every match of $2 in files under Hum/,
# excluding paths matching $3. $1 is the human-readable message.
check() {
  local message="$1" pattern="$2" exclude="$3" found=0

  while IFS= read -r file; do
    [[ "$file" =~ $exclude ]] && continue
    # Strip line comments so documentation cannot trip the check, then keep
    # original line numbers via grep -n on the filtered stream.
    while IFS=: read -r line _; do
      [ -z "$line" ] && continue
      echo "$file:${line}: error: $message"
      found=1
    done < <(sed 's://.*::' "$file" | grep -nE "$pattern")
  done < <(find Hum -name '*.swift' -type f | sort)

  return $found
}

check \
  "'import MusicKit' is confined to Hum/Services/Adapters/ (ARCHITECTURE.md §1). Map MusicKit types to Domain types at the adapter boundary." \
  '^[[:space:]]*(@[A-Za-z_]+[[:space:]]+)*import[[:space:]]+MusicKit([[:space:]]|$)' \
  '^Hum/Services/Adapters/' || status=1

check \
  "'.glassEffect()' is confined to Hum/DesignSystem/GlassSurface.swift (ARCHITECTURE.md §6). Glass is chrome-only; content views render opaque." \
  '\.glassEffect[[:space:]]*\(' \
  '^Hum/DesignSystem/GlassSurface\.swift$' || status=1

if [ "$status" -eq 0 ]; then
  echo "containment: ok (MusicKit confined to adapters; glassEffect confined to GlassSurface.swift)"
fi
exit "$status"
