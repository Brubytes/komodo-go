#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: ./scripts/run_test.sh <test-file> [additional args...]" >&2
  exit 1
fi

if [[ -f .env ]]; then
  set -a
  # shellcheck source=/dev/null
  source .env
  set +a
fi

flutter_args=()
has_backend_test=false
has_concurrency_flag=false

for arg in "$@"; do
  case "${arg}" in
    test/integration/backend*) has_backend_test=true ;;
    --concurrency | --concurrency=*) has_concurrency_flag=true ;;
  esac
done

if [[ "${has_backend_test}" == true && "${has_concurrency_flag}" == false ]]; then
  # Backend contracts reset one shared database and must not run in parallel.
  flutter_args+=(--concurrency=1)
fi

flutter_args+=("$@")
exec fvm flutter test "${flutter_args[@]}"
