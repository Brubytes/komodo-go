#!/usr/bin/env bash
set -euo pipefail

PUBSPEC_PATH="pubspec.yaml"
SCRIPT_NAME="$(basename "$0")"

abort() {
  echo "Error: $*" >&2
  exit 1
}

print_help() {
  cat <<EOF
Usage:
  ./$SCRIPT_NAME
  ./$SCRIPT_NAME --help

What this script does:
- Optionally bump version in $PUBSPEC_PATH
- Optionally create rc/v tags from that version
- Optionally push commit/tags
- Optionally create GitHub Release for v-tags (using gh)

Recommended flow (with protected main):
1) On dev/release branch:
   - choose patch/minor/major/custom
   - choose "no tags (version commit only)"
   - open PR and merge to main
2) On main after merge:
   - choose "keep current version"
   - choose "release candidate only" (creates rc-x.y.z-N)
3) After RC verify passes:
   - choose "keep current version"
   - choose "release only" (creates vX.Y.Z)
   - optionally create GitHub Release

Version/build behavior:
- Tag controls release version name (v1.2.3 => 1.2.3)
- Store build numbers are auto-incremented in Codemagic
EOF
}

print_runtime_guide() {
  cat <<'EOF'
Release helper quick guide:
- Use "no tags (version commit only)" to prepare version bumps via PR.
- Use "release candidate only" on main to trigger Codemagic verify workflows (rc-*).
- Use "release only" on main after RC success to trigger real releases (v*).
- Codemagic uses tag version as build-name; build-number comes from stores.
EOF
  echo
}

github_repo_slug_from_origin() {
  local remote_url
  local repo_path
  local owner
  local name

  remote_url="$(git remote get-url origin 2>/dev/null || true)"
  [[ -n "$remote_url" ]] || return 1

  case "$remote_url" in
    git@github.com:*)
      repo_path="${remote_url#git@github.com:}"
      ;;
    https://github.com/*)
      repo_path="${remote_url#https://github.com/}"
      ;;
    http://github.com/*)
      repo_path="${remote_url#http://github.com/}"
      ;;
    *)
      return 1
      ;;
  esac

  repo_path="${repo_path%.git}"
  repo_path="${repo_path%/}"
  owner="$(printf '%s' "$repo_path" | cut -d/ -f1)"
  name="$(printf '%s' "$repo_path" | cut -d/ -f2)"
  [[ -n "$owner" && -n "$name" ]] || return 1
  echo "${owner}/${name}"
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
  reply="$(printf '%s' "$reply" | tr '[:upper:]' '[:lower:]')"
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

case "${1:-}" in
  -h|--help)
    print_help
    exit 0
    ;;
  "")
    ;;
  *)
    abort "Unknown argument '$1'. Use --help."
    ;;
esac

[[ -f "$PUBSPEC_PATH" ]] || abort "$PUBSPEC_PATH not found. Run this script from the repository root."
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || abort "Not inside a git repository."

require_clean_worktree
read_pubspec_version

print_runtime_guide

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
echo "1) patch (x.y.Z+build)"
echo "2) minor (x.Y.0+build)"
echo "3) major (X.0.0+build)"
echo "4) custom (enter x.y.z)"
echo "5) keep current version (no pubspec change)"
read -r -p "Choose option [1-5]: " version_choice

NEW_SEMVER="$CUR_SEMVER"
NEW_BUILD="$CUR_BUILD"
SHOULD_BUMP="n"

case "$version_choice" in
  1)
    NEW_SEMVER="${CUR_MAJOR}.${CUR_MINOR}.$((CUR_PATCH + 1))"
    NEW_BUILD="$CUR_BUILD"
    SHOULD_BUMP="y"
    ;;
  2)
    NEW_SEMVER="${CUR_MAJOR}.$((CUR_MINOR + 1)).0"
    NEW_BUILD="$CUR_BUILD"
    SHOULD_BUMP="y"
    ;;
  3)
    NEW_SEMVER="$((CUR_MAJOR + 1)).0.0"
    NEW_BUILD="$CUR_BUILD"
    SHOULD_BUMP="y"
    ;;
  4)
    read -r -p "Enter custom version (x.y.z): " custom_semver
    [[ "$custom_semver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || abort "Invalid custom version '$custom_semver'."
    NEW_SEMVER="$custom_semver"
    NEW_BUILD="$CUR_BUILD"
    SHOULD_BUMP="y"
    ;;
  5)
    ;;
  *)
    abort "Invalid selection '$version_choice'."
    ;;
esac

if [[ "$SHOULD_BUMP" == "y" ]]; then
  read -r -p "Pubspec build number [$NEW_BUILD] (optional): " build_input
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
echo "1) release candidate only (rc-<version>-N, verify build)"
echo "2) release only (v<version>, real release)"
echo "3) both rc and release tags (not recommended for normal flow)"
echo "4) no tags (version commit only, good for PRs)"
read -r -p "Choose option [1-4]: " tag_choice

declare -a TAGS=()
if [[ "$tag_choice" == "1" || "$tag_choice" == "3" ]]; then
  TAGS+=("$(next_rc_tag_for_semver "$NEW_SEMVER")")
fi
if [[ "$tag_choice" == "2" || "$tag_choice" == "3" ]]; then
  TAGS+=("v${NEW_SEMVER}")
fi
if [[ "$tag_choice" != "1" && "$tag_choice" != "2" && "$tag_choice" != "3" && "$tag_choice" != "4" ]]; then
  abort "Invalid tag selection '$tag_choice'."
fi

if [[ "$current_branch" != "main" && "$tag_choice" != "4" ]]; then
  confirm "You are on '$current_branch'. Create release tags from this non-main branch?" "n" || exit 1
fi

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
if [[ "${#TAGS[@]}" -eq 0 ]]; then
  echo "- No tags will be created"
fi
if [[ "$tag_choice" == "4" ]]; then
  echo "- Next step: open PR and merge this version bump before tagging"
fi

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

PUSHED="n"
if confirm "Push commit/tag changes to origin now?" "n"; then
  if [[ "$SHOULD_BUMP" == "y" ]]; then
    git push origin "$current_branch"
  fi
  for tag in "${TAGS[@]}"; do
    git push origin "$tag"
  done
  PUSHED="y"
  echo "Pushed successfully."
else
  echo "Nothing pushed. Push manually when ready."
fi

if [[ "$tag_choice" == "4" ]]; then
  echo "Tip: after merge to main, run again with 'keep current version' + rc/v tag mode."
fi

declare -a RELEASE_TAGS=()
for tag in "${TAGS[@]}"; do
  if [[ "$tag" == v* ]]; then
    RELEASE_TAGS+=("$tag")
  fi
done

if [[ "${#RELEASE_TAGS[@]}" -gt 0 ]] && confirm "Create GitHub Release for v-tag(s)?" "n"; then
  command -v gh >/dev/null 2>&1 || abort "GitHub CLI ('gh') not found. Install it first."
  gh auth status >/dev/null 2>&1 || abort "GitHub CLI is not authenticated. Run 'gh auth login' first."

  REPO_SLUG="$(github_repo_slug_from_origin || true)"
  [[ -n "${REPO_SLUG:-}" ]] || abort "Could not determine GitHub repo from 'origin' remote."

  if [[ "$PUSHED" != "y" ]]; then
    if confirm "Release tags are not pushed yet. Push now?" "y"; then
      if [[ "$SHOULD_BUMP" == "y" ]]; then
        git push origin "$current_branch"
      fi
      for tag in "${TAGS[@]}"; do
        git push origin "$tag"
      done
      PUSHED="y"
      echo "Pushed successfully."
    else
      abort "Cannot create GitHub Release without pushing the tag."
    fi
  fi

  for tag in "${RELEASE_TAGS[@]}"; do
    if gh release view "$tag" --repo "$REPO_SLUG" >/dev/null 2>&1; then
      abort "GitHub Release for tag '$tag' already exists."
    fi
    gh release create "$tag" \
      --repo "$REPO_SLUG" \
      --verify-tag \
      --generate-notes \
      --title "$tag"
    echo "Created GitHub Release: $tag"
  done
fi
