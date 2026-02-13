#!/usr/bin/env bash
set -euo pipefail

PUBSPEC_PATH="pubspec.yaml"

abort() {
  echo "Error: $*" >&2
  exit 1
}

confirm() {
  local prompt="$1"
  local default="${2:-n}"
  local suffix
  local reply

  if [[ "$default" == "y" ]]; then
    suffix="[Y/n]"
  else
    suffix="[y/N]"
  fi

  read -r -p "$prompt $suffix " reply
  reply="${reply,,}"
  if [[ -z "$reply" ]]; then
    reply="$default"
  fi
  [[ "$reply" == "y" || "$reply" == "yes" ]]
}

require_clean_worktree() {
  if [[ -n "$(git status --porcelain)" ]]; then
    abort "Working tree is not clean. Commit or stash changes before running release tagging."
  fi
}

read_pubspec_version() {
  local version_line
  local value

  version_line="$(grep -E '^version:' "$PUBSPEC_PATH" | head -n 1 || true)"
  [[ -n "$version_line" ]] || abort "Could not find a 'version:' entry in $PUBSPEC_PATH."

  value="$(printf '%s' "$version_line" | sed -E 's/^version:[[:space:]]*//; s/[[:space:]]+#.*$//; s/[[:space:]]*$//')"
  if [[ "$value" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(\+([0-9]+))?$ ]]; then
    CUR_MAJOR="${BASH_REMATCH[1]}"
    CUR_MINOR="${BASH_REMATCH[2]}"
    CUR_PATCH="${BASH_REMATCH[3]}"
    CUR_BUILD="${BASH_REMATCH[5]:-0}"
    CUR_SEMVER="${CUR_MAJOR}.${CUR_MINOR}.${CUR_PATCH}"
    CUR_VERSION="$value"
    return
  fi

  abort "Unsupported version format '$value' in $PUBSPEC_PATH. Expected x.y.z or x.y.z+build."
}

write_pubspec_version() {
  local new_version="$1"
  local tmp_file

  tmp_file="$(mktemp)"
  awk -v version="$new_version" '
    BEGIN { replaced = 0 }
    {
      if (!replaced && $0 ~ /^version:[[:space:]]*/) {
        print "version: " version
        replaced = 1
        next
      }
      print
    }
    END {
      if (!replaced) {
        exit 1
      }
    }
  ' "$PUBSPEC_PATH" > "$tmp_file" || {
    rm -f "$tmp_file"
    abort "Failed to update version in $PUBSPEC_PATH."
  }
  mv "$tmp_file" "$PUBSPEC_PATH"
}

next_rc_tag_for_semver() {
  local semver="$1"
  local tag
  local suffix
  local max_suffix=0

  while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue
    suffix="${tag#rc-${semver}-}"
    if [[ "$suffix" =~ ^[0-9]+$ ]] && (( suffix > max_suffix )); then
      max_suffix="$suffix"
    fi
  done < <(git tag -l "rc-${semver}-*")

  echo "rc-${semver}-$((max_suffix + 1))"
}

[[ -f "$PUBSPEC_PATH" ]] || abort "$PUBSPEC_PATH not found. Run this script from the repository root."
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || abort "Not inside a git repository."

require_clean_worktree
read_pubspec_version

current_branch="$(git rev-parse --abbrev-ref HEAD)"
echo "Current branch: $current_branch"
echo "Current pubspec version: $CUR_VERSION"

if [[ "$current_branch" != "main" ]]; then
  confirm "Branch is '$current_branch', not 'main'. Continue anyway?" "n" || exit 1
fi

if confirm "Fetch latest tags from origin first?" "y"; then
  git fetch --tags origin
fi

echo
echo "Version change:"
echo "1) patch"
echo "2) minor"
echo "3) major"
echo "4) custom"
echo "5) keep current version"
read -r -p "Choose option [1-5]: " version_choice

NEW_SEMVER="$CUR_SEMVER"
NEW_BUILD="$CUR_BUILD"
SHOULD_BUMP="n"

case "$version_choice" in
  1)
    NEW_SEMVER="${CUR_MAJOR}.${CUR_MINOR}.$((CUR_PATCH + 1))"
    NEW_BUILD="$((CUR_BUILD + 1))"
    SHOULD_BUMP="y"
    ;;
  2)
    NEW_SEMVER="${CUR_MAJOR}.$((CUR_MINOR + 1)).0"
    NEW_BUILD="$((CUR_BUILD + 1))"
    SHOULD_BUMP="y"
    ;;
  3)
    NEW_SEMVER="$((CUR_MAJOR + 1)).0.0"
    NEW_BUILD="$((CUR_BUILD + 1))"
    SHOULD_BUMP="y"
    ;;
  4)
    read -r -p "Enter custom version (x.y.z): " custom_semver
    [[ "$custom_semver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || abort "Invalid custom version '$custom_semver'."
    NEW_SEMVER="$custom_semver"
    NEW_BUILD="$((CUR_BUILD + 1))"
    SHOULD_BUMP="y"
    ;;
  5)
    ;;
  *)
    abort "Invalid selection '$version_choice'."
    ;;
esac

if [[ "$SHOULD_BUMP" == "y" ]]; then
  read -r -p "Build number [$NEW_BUILD]: " build_input
  if [[ -n "$build_input" ]]; then
    [[ "$build_input" =~ ^[0-9]+$ ]] || abort "Build number must be numeric."
    NEW_BUILD="$build_input"
  fi
  NEW_VERSION="${NEW_SEMVER}+${NEW_BUILD}"
else
  NEW_VERSION="$CUR_VERSION"
fi

echo
echo "Tag mode:"
echo "1) release candidate only (rc-<version>-N)"
echo "2) release only (v<version>)"
echo "3) both rc and release tags"
read -r -p "Choose option [1-3]: " tag_choice

declare -a TAGS=()
if [[ "$tag_choice" == "1" || "$tag_choice" == "3" ]]; then
  TAGS+=("$(next_rc_tag_for_semver "$NEW_SEMVER")")
fi
if [[ "$tag_choice" == "2" || "$tag_choice" == "3" ]]; then
  TAGS+=("v${NEW_SEMVER}")
fi
[[ "${#TAGS[@]}" -gt 0 ]] || abort "Invalid tag selection '$tag_choice'."

for tag in "${TAGS[@]}"; do
  if git rev-parse --verify --quiet "refs/tags/$tag" >/dev/null; then
    abort "Tag '$tag' already exists."
  fi
done

echo
echo "Planned actions:"
if [[ "$SHOULD_BUMP" == "y" ]]; then
  echo "- Update $PUBSPEC_PATH: $CUR_VERSION -> $NEW_VERSION"
  echo "- Commit: chore(release): bump version to $NEW_VERSION"
else
  echo "- Keep $PUBSPEC_PATH version at $CUR_VERSION"
fi
for tag in "${TAGS[@]}"; do
  echo "- Create tag: $tag"
done

confirm "Proceed?" "y" || exit 0

if [[ "$SHOULD_BUMP" == "y" ]]; then
  write_pubspec_version "$NEW_VERSION"
  git add "$PUBSPEC_PATH"
  git commit -m "chore(release): bump version to $NEW_VERSION"
fi

for tag in "${TAGS[@]}"; do
  if [[ "$tag" == rc-* ]]; then
    git tag -a "$tag" -m "Release candidate $tag"
  else
    git tag -a "$tag" -m "Release $tag"
  fi
done

echo
echo "Created:"
if [[ "$SHOULD_BUMP" == "y" ]]; then
  echo "- Commit: $(git rev-parse --short HEAD)"
fi
for tag in "${TAGS[@]}"; do
  echo "- Tag: $tag"
done

if confirm "Push commit/tag changes to origin now?" "n"; then
  if [[ "$SHOULD_BUMP" == "y" ]]; then
    git push origin "$current_branch"
  fi
  for tag in "${TAGS[@]}"; do
    git push origin "$tag"
  done
  echo "Pushed successfully."
else
  echo "Nothing pushed. Push manually when ready."
fi
