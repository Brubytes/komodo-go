#!/usr/bin/env bash
set -euo pipefail

# Dart-Code launches tests using a Flutter-compatible argument list like:
#   test [options...] <path/to/test.dart>
# Patrol requires:
#   patrol test -t <path/to/test.dart> [options...]

args=("$@")

# Drop the leading 'test' subcommand if present.
if [[ ${#args[@]} -gt 0 && "${args[0]}" == "test" ]]; then
  args=("${args[@]:1}")
fi

# Find the last *.dart argument and treat it as the target.
target=""
for ((i=${#args[@]}-1; i>=0; i--)); do
  if [[ "${args[i]}" == *.dart ]]; then
    target="${args[i]}"
    unset 'args[i]'
    break
  fi
done

if [[ -z "$target" ]]; then
  echo "flutter_test_to_patrol.sh: could not find a .dart target in args: $*" >&2
  exit 2
fi

# Re-pack args (preserve order) after unset, stripping/normalizing arguments that
# are added by IDE tooling but not understood by Patrol.
filtered=()
device_id=""
saw_device=0

for ((i=0; i<${#args[@]}; i++)); do
  a="${args[i]:-}"

  # Skip empty entries (may exist due to unset earlier).
  if [[ -z "$a" ]]; then
    continue
  fi

  # VS Code / Dart-Code may inject Flutter-test-specific flags that Patrol does not support.
  case "$a" in
    --machine|--machine=*)
      continue
      ;;
  esac

  # VS Code may also inject an additional device (for example: "-d macos").
  # Patrol accepts multiple -d/--device, but we want to keep the first explicit
  # device passed in launch.json (the iOS simulator UDID) and ignore extras.
  if [[ "$a" == "-d" || "$a" == "--device" ]]; then
    next="${args[i+1]:-}"
    if [[ $saw_device -eq 0 ]]; then
      saw_device=1
      device_id="$next"
      filtered+=("$a" "$next")
    fi
    i=$((i+1))
    continue
  fi

  if [[ "$a" == --device=* ]]; then
    value="${a#--device=}"
    if [[ $saw_device -eq 0 ]]; then
      saw_device=1
      device_id="$value"
      filtered+=("$a")
    fi
    continue
  fi

  filtered+=("$a")
done

# If we're targeting an iOS Simulator by UDID, try to boot it first so that
# it shows up in `flutter devices`.
if [[ -n "$device_id" && "$device_id" == *-* ]] && command -v xcrun >/dev/null 2>&1; then
  open -a Simulator >/dev/null 2>&1 || true
  xcrun simctl boot "$device_id" >/dev/null 2>&1 || true
fi

if [[ "${KOMODO_PATROL_WRAPPER_DEBUG:-}" == "1" ]]; then
  echo "flutter_test_to_patrol.sh -> patrol test -t $target ${filtered[*]}" >&2
fi

exec patrol test -t "$target" "${filtered[@]}"
