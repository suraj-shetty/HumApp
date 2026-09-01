#!/bin/bash
#
# Architectural containment checks. See docs/v1-musickit/ARCHITECTURE.md §1.
#
# Two rules hold this codebase's layering together. Both are grep-able on
# purpose — an architectural rule nobody can verify is a wish, not a rule.
#
#   1. Only Services/Adapters/* may import MusicKit.
#      This is what lets every screen build and run in the Simulator against
#      fakes, despite MusicKit not functioning there at all (DECISIONS M-09).
#
#   2. Only DesignSystem/GlassSurface.swift may call .glassEffect().
#      This makes the brief's "content views never render as glass" acceptance
#      criterion mechanically checkable instead of a matter of discipline.
#
# Run standalone from the repo root, or as an Xcode run-script build phase.

set -uo pipefail

ROOT="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$ROOT" || exit 1

status=0

# --- Rule 1: MusicKit stays in the adapters -------------------------------
offenders=$(grep -rln --include='*.swift' 'import MusicKit' Hum 2>/dev/null \
            | grep -v '^Hum/Services/Adapters/')
if [ -n "$offenders" ]; then
  while IFS= read -r f; do
    line=$(grep -n 'import MusicKit' "$f" | head -1 | cut -d: -f1)
    echo "$f:${line}: error: 'import MusicKit' is confined to Hum/Services/Adapters/ (ARCHITECTURE.md §1). Map MusicKit types to Domain types at the adapter boundary."
  done <<< "$offenders"
  status=1
fi

# --- Rule 2: glass stays in GlassSurface.swift ----------------------------
hits=$(grep -rn --include='*.swift' 'glassEffect' Hum 2>/dev/null \
       | grep -v '^Hum/DesignSystem/GlassSurface.swift:')
if [ -n "$hits" ]; then
  while IFS= read -r h; do
    f=${h%%:*}; rest=${h#*:}; line=${rest%%:*}
    echo "$f:${line}: error: '.glassEffect()' is confined to Hum/DesignSystem/GlassSurface.swift (ARCHITECTURE.md §6). Glass is chrome-only; content views render opaque."
  done <<< "$hits"
  status=1
fi

if [ "$status" -eq 0 ]; then
  echo "containment: ok (MusicKit confined to adapters; glassEffect confined to GlassSurface.swift)"
fi
exit "$status"
