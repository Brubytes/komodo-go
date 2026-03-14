#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: ./scripts/run_backend_tests_serial.sh [test-file...]

Runs real-backend contract test files serially.

- With no arguments, runs all files matching test/integration/backend/*_test.dart
- With one or more file paths, runs only those files in the given order

Examples:
  ./scripts/run_backend_tests_serial.sh
  ./scripts/run_backend_tests_serial.sh test/integration/backend/providers_contract_test.dart
  ./scripts/run_backend_tests_serial.sh \
    test/integration/backend/repo_contract_test.dart \
    test/integration/backend/providers_contract_test.dart
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

cd "${repo_root}"

shopt -s nullglob

if [[ $# -gt 0 ]]; then
  test_files=("$@")
else
  test_files=(test/integration/backend/*_test.dart)
fi

if [[ ${#test_files[@]} -eq 0 ]]; then
  echo "No backend test files found." >&2
  exit 1
fi

for test_file in "${test_files[@]}"; do
  if [[ ! -f "${test_file}" ]]; then
    echo "Backend test file not found: ${test_file}" >&2
    exit 1
  fi
done

total=${#test_files[@]}
current=0

for test_file in "${test_files[@]}"; do
  ((current+=1))
  echo
  echo "[${current}/${total}] Running ${test_file}"
  "${script_dir}/run_test.sh" "${test_file}"
done

echo
echo "Completed ${total} backend test file(s) serially."