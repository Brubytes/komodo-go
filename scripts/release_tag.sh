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
- Optionally create GitHub PR to main for version-bump branches (using gh)
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

ensure_gh_available_and_authenticated() {
  command -v gh >/dev/null 2>&1 || abort "GitHub CLI ('gh') not found. Install it first."
  gh auth status >/dev/null 2>&1 || abort "GitHub CLI is not authenticated. Run 'gh auth login' first."
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

FORCE_NO_TAGS="n"
if [[ "$current_branch" == "main" ]]; then
  echo
  echo "Main branch detected."
  echo "Typical release sequence:"
  echo "1) create rc tag"
  echo "2) wait for Codemagic verify"
  echo "3) create v tag"
else
  echo
  echo "You are on '$current_branch' (not main)."
  echo "Recommended on non-main branches:"
  echo "1) bump pubspec version only (no tags)"
  echo "2) push branch and merge PR to main"
  echo "3) run this script again on main for rc/v tags"
  echo
  echo "Choose branch mode:"
  echo "1) PR prep mode (force no tags) [recommended]"
  echo "2) Manual mode (allow tags on this branch)"
  echo "3) abort"
  read -r -p "Choose option [1-3] (default 1): " non_main_choice
  non_main_choice="${non_main_choice:-1}"
  case "$non_main_choice" in
    1)
      FORCE_NO_TAGS="y"
      ;;
    2)
      ;;
    3)
      exit 0
      ;;
    *)
      abort "Invalid selection '$non_main_choice'."
      ;;
  esac
fi

if confirm "Fetch latest tags from origin first?" "y"; then
  git fetch --tags origin
fi

echo
if [[ "$FORCE_NO_TAGS" == "y" ]]; then
  echo "Version change (PR prep mode, tags will be skipped):"
else
  echo "Version change:"
fi
echo "1) patch (x.y.Z+build)"
echo "2) minor (x.Y.0+build)"
echo "3) major (X.0.0+build)"
echo "4) custom (enter x.y.z)"
echo "5) keep current version (no pubspec change)"
if [[ "$current_branch" == "main" && "$FORCE_NO_TAGS" != "y" ]]; then
  echo "Hint: for tagging an already-merged release, choose 5."
  read -r -p "Choose option [1-5] (default 5): " version_choice
  version_choice="${version_choice:-5}"
else
  read -r -p "Choose option [1-5]: " version_choice
fi

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
if [[ "$FORCE_NO_TAGS" == "y" ]]; then
  tag_choice="4"
  echo "Tag mode: PR prep mode active -> forcing 'no tags'."
else
  echo "Tag mode:"
  echo "1) release candidate only (rc-<version>-N, verify build) [recommended first]"
  echo "2) release only (v<version>, real release) [after RC passed]"
  echo "3) both rc and release tags (not recommended for normal flow)"
  echo "4) no tags (version commit only, good for PRs)"
  read -r -p "Choose option [1-4] (default 1): " tag_choice
  tag_choice="${tag_choice:-1}"
fi

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
  echo
  echo "Warning: this will create tags from non-main branch '$current_branch'."
  echo "If this commit is not merged into main yet, tags may point to the wrong commit."
  confirm "Continue creating tags from '$current_branch'?" "n" || exit 1
fi

if [[ "${#TAGS[@]}" -gt 0 ]]; then
  for tag in "${TAGS[@]}"; do
    if git rev-parse --verify --quiet "refs/tags/$tag" >/dev/null; then
      abort "Tag '$tag' already exists."
    fi
  done
fi

echo
echo "Planned actions:"
if [[ "$SHOULD_BUMP" == "y" ]]; then
  echo "- Update $PUBSPEC_PATH: $CUR_VERSION -> $NEW_VERSION"
  echo "- Commit: chore(release): bump version to $NEW_VERSION"
else
  echo "- Keep $PUBSPEC_PATH version at $CUR_VERSION"
fi
if [[ "${#TAGS[@]}" -gt 0 ]]; then
  for tag in "${TAGS[@]}"; do
    echo "- Create tag: $tag"
  done
fi
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

if [[ "${#TAGS[@]}" -gt 0 ]]; then
  for tag in "${TAGS[@]}"; do
    if [[ "$tag" == rc-* ]]; then
      git tag -a "$tag" -m "Release candidate $tag"
    else
      git tag -a "$tag" -m "Release $tag"
    fi
  done
fi

echo
echo "Created:"
if [[ "$SHOULD_BUMP" == "y" ]]; then
  echo "- Commit: $(git rev-parse --short HEAD)"
fi
if [[ "${#TAGS[@]}" -gt 0 ]]; then
  for tag in "${TAGS[@]}"; do
    echo "- Tag: $tag"
  done
fi

PUSHED="n"
if confirm "Push commit/tag changes to origin now?" "n"; then
  if [[ "$SHOULD_BUMP" == "y" ]]; then
    git push origin "$current_branch"
  fi
  if [[ "${#TAGS[@]}" -gt 0 ]]; then
    for tag in "${TAGS[@]}"; do
      git push origin "$tag"
    done
  fi
  PUSHED="y"
  echo "Pushed successfully."
else
  echo "Nothing pushed. Push manually when ready."
fi

if [[ "$tag_choice" == "4" ]]; then
  echo "Tip: after merge to main, run again with 'keep current version' + rc/v tag mode."
fi

if [[ "$current_branch" != "main" && "$tag_choice" == "4" && "$SHOULD_BUMP" == "y" ]]; then
  if confirm "Create GitHub PR from '$current_branch' to 'main' now?" "y"; then
    ensure_gh_available_and_authenticated
    REPO_SLUG="$(github_repo_slug_from_origin || true)"
    [[ -n "${REPO_SLUG:-}" ]] || abort "Could not determine GitHub repo from 'origin' remote."

    if [[ "$PUSHED" != "y" ]]; then
      if confirm "Branch is not pushed yet. Push '$current_branch' now?" "y"; then
        git push -u origin "$current_branch"
        PUSHED="y"
      else
        abort "Cannot create PR without pushing branch '$current_branch'."
      fi
    fi

    PR_BASE="main"
    read -r -p "PR base branch [$PR_BASE]: " pr_base_input
    if [[ -n "$pr_base_input" ]]; then
      PR_BASE="$pr_base_input"
    fi

    existing_pr_url="$(gh pr list \
      --repo "$REPO_SLUG" \
      --state open \
      --base "$PR_BASE" \
      --head "$current_branch" \
      --json url \
      --jq '.[0].url' 2>/dev/null || true)"

    if [[ -n "$existing_pr_url" ]]; then
      echo "Open PR already exists: $existing_pr_url"
    else
      PR_TITLE="chore(release): bump version to $NEW_VERSION"
      read -r -p "PR title [$PR_TITLE]: " pr_title_input
      if [[ -n "$pr_title_input" ]]; then
        PR_TITLE="$pr_title_input"
      fi

      printf -v PR_BODY \
        'Release prep:\n- bump pubspec version to %s\n\nNext:\n1. merge this PR\n2. run ./scripts/release_tag.sh on main\n3. create rc tag first, then v tag after verify passes\n' \
        "$NEW_VERSION"

      gh pr create \
        --repo "$REPO_SLUG" \
        --base "$PR_BASE" \
        --head "$current_branch" \
        --title "$PR_TITLE" \
        --body "$PR_BODY"
    fi
  fi
fi

declare -a RELEASE_TAGS=()
if [[ "${#TAGS[@]}" -gt 0 ]]; then
  for tag in "${TAGS[@]}"; do
    if [[ "$tag" == v* ]]; then
      RELEASE_TAGS+=("$tag")
    fi
  done
fi

if [[ "${#RELEASE_TAGS[@]}" -gt 0 ]] && confirm "Create GitHub Release for v-tag(s)?" "n"; then
  ensure_gh_available_and_authenticated

  REPO_SLUG="$(github_repo_slug_from_origin || true)"
  [[ -n "${REPO_SLUG:-}" ]] || abort "Could not determine GitHub repo from 'origin' remote."

  if [[ "$PUSHED" != "y" ]]; then
    if confirm "Release tags are not pushed yet. Push now?" "y"; then
      if [[ "$SHOULD_BUMP" == "y" ]]; then
        git push origin "$current_branch"
      fi
      if [[ "${#TAGS[@]}" -gt 0 ]]; then
        for tag in "${TAGS[@]}"; do
          git push origin "$tag"
        done
      fi
      PUSHED="y"
      echo "Pushed successfully."
    else
      abort "Cannot create GitHub Release without pushing the tag."
    fi
  fi

  if [[ "${#RELEASE_TAGS[@]}" -gt 0 ]]; then
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
fi
