#!/usr/bin/env bash
# Bump CURRENT_PROJECT_VERSION in src/Config/Version.xcconfig.
# Used as an Xcode Archive pre-action so every archive gets a new build number.
#
# Usage:
#   ./scripts/bump-build-number.sh           # bump only
#   ./scripts/bump-build-number.sh --commit  # bump and commit Version.xcconfig only
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_FILE="${ROOT}/src/Config/Version.xcconfig"

if [[ ! -f "${VERSION_FILE}" ]]; then
  echo "error: missing ${VERSION_FILE}" >&2
  exit 1
fi

current="$(
  awk -F'=' '/^CURRENT_PROJECT_VERSION[[:space:]]*=/ {
    gsub(/[[:space:]]/, "", $2)
    print $2
    exit
  }' "${VERSION_FILE}"
)"

if [[ -z "${current}" || ! "${current}" =~ ^[0-9]+$ ]]; then
  echo "error: could not parse CURRENT_PROJECT_VERSION from ${VERSION_FILE}" >&2
  exit 1
fi

next=$((current + 1))

# Portable in-place edit (macOS / BSD sed).
sed -i '' -E "s/^(CURRENT_PROJECT_VERSION[[:space:]]*=[[:space:]]*)${current}$/\\1${next}/" "${VERSION_FILE}"

echo "Build number: ${current} → ${next}"

if [[ "${1:-}" != "--commit" ]]; then
  exit 0
fi

if ! command -v git >/dev/null 2>&1; then
  echo "warning: git not found; skipped commit of build ${next}"
  exit 0
fi

cd "${ROOT}"
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "warning: not a git repo; skipped commit of build ${next}"
  exit 0
fi

git add -- "src/Config/Version.xcconfig"

if git diff --cached --quiet -- "src/Config/Version.xcconfig"; then
  echo "No Version.xcconfig changes to commit."
  exit 0
fi

# Do not fail the archive if the working tree has other issues; only commit this file.
if git commit -m "Bump build number to ${next}." -- "src/Config/Version.xcconfig"; then
  echo "Committed build number ${next}."
else
  echo "warning: git commit failed; build ${next} is on disk but not committed." >&2
  exit 0
fi
