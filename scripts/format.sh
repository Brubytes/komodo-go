#!/usr/bin/env bash
# Formats (or checks) all hand-written Dart code with the SDK pinned in .fvmrc.
#
#   scripts/format.sh           rewrite files in place
#   scripts/format.sh --check   list files that need formatting, exit 1 if any
#
# Locally this goes through `fvm`; in CI the pinned Flutter is already on PATH.
# Generated files (*.g.dart, *.freezed.dart, patrol's test_bundle.dart) are
# skipped because `dart format` has no exclude option.
set -euo pipefail

cd "$(dirname "$0")/.."

mode=(--output=write)
case "${1:-}" in
  '') ;;
  --check) mode=(--output=none --set-exit-if-changed) ;;
  *)
    echo "usage: scripts/format.sh [--check]" >&2
    exit 64
    ;;
esac

if [ -z "${CI:-}" ] && command -v fvm >/dev/null 2>&1; then
  dart_cmd=(fvm dart)
else
  dart_cmd=(dart)
fi

git ls-files -co --exclude-standard -z -- '*.dart' \
  | grep -zvE '(\.g\.dart|\.freezed\.dart)$|^integration_test/test_bundle\.dart$' \
  | xargs -0 "${dart_cmd[@]}" format "${mode[@]}"
