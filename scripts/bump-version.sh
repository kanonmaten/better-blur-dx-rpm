#!/usr/bin/env bash
# Bump packaging/ to the newest tagged Better Blur DX release.
#
# Rewrites, in lockstep:
#   packaging/kwin-effects-better-blur-dx.spec   Version, %global src_sha256, Release->0, %changelog
#   packaging/_service                            download_url url + filename
#
# The latest release comes from the GitHub API (via gh, so it works with the
# Actions token and without hitting anonymous rate limits). The tarball is
# small, so the checksum is computed by downloading it once.
#
# KWin updates need no bump: OBS rebuilds the package on its own when
# kwin6-devel changes in Tumbleweed.
#
# Changelog author: $PACKAGER (default "kanonmaten <86723077+kanonmaten@users.noreply.github.com>").
#
# Usage:
#   scripts/bump-version.sh [VERSION]     # default: upstream's latest release
#   scripts/bump-version.sh --commit ...  # also `git add` + `git commit`
#
# Exit status: 0 and prints "bumped <old> -> <new>" on a change,
#              0 and prints "up to date (<version>)" when already current.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG="kwin-effects-better-blur-dx"
SPEC="$REPO_ROOT/packaging/$PKG.spec"
SERVICE="$REPO_ROOT/packaging/_service"
UPSTREAM="xarblu/kwin-effects-better-blur-dx"

commit=0
want=""
for arg in "$@"; do
  case "$arg" in
    --commit) commit=1 ;;
    -*) echo "unknown flag: $arg" >&2; exit 2 ;;
    *)  want="${arg#v}" ;;
  esac
done

current=$(sed -n 's/^Version:[[:space:]]*//p' "$SPEC")
[ -n "$current" ] || { echo "cannot read Version from $SPEC" >&2; exit 1; }

if [ -n "$want" ]; then
  new="$want"
else
  tag=$(gh api "repos/$UPSTREAM/releases/latest" --jq .tag_name)
  [ -n "$tag" ] || { echo "no latest release for $UPSTREAM" >&2; exit 1; }
  new="${tag#v}"
fi

if [ "$new" = "$current" ]; then
  echo "up to date ($current)"
  exit 0
fi

# Guard against an accidental downgrade (e.g. a bad VERSION arg).
if [ "$(printf '%s\n%s\n' "$current" "$new" | sort -V | tail -1)" != "$new" ]; then
  echo "refusing to move $current -> $new (not newer)" >&2
  exit 1
fi

url="https://github.com/$UPSTREAM/archive/refs/tags/v${new}.tar.gz"
fname="$PKG-${new}.tar.gz"
sha=$(curl -fsSL "$url" | sha256sum | cut -d' ' -f1)

echo "bumping $current -> $new"
echo "  sha256   $sha"
echo "  url      $url"

# --- rewrite the spec ------------------------------------------------------
tmp=$(mktemp)
awk -v new="$new" -v sha="$sha" '
  /^%global src_sha256 / { print "%global src_sha256 " sha; next }
  /^Version:[[:space:]]/  { print "Version:        " new; next }
  /^Release:[[:space:]]/  { print "Release:        0"; next }
  { print }
' "$SPEC" > "$tmp"

entry="* $(LC_ALL=C date '+%a %b %d %Y') ${PACKAGER:-kanonmaten <86723077+kanonmaten@users.noreply.github.com>} - ${new}-0
- Update to upstream ${new}
  https://github.com/$UPSTREAM/releases/tag/v${new}"
awk -v e="$entry" '
  { print }
  /^%changelog$/ && !done { print e; print ""; done=1 }
' "$tmp" > "$SPEC"
rm -f "$tmp"

# --- rewrite _service ------------------------------------------------------
sed -i \
  -e "s#<param name=\"url\">.*</param>#<param name=\"url\">${url}</param>#" \
  -e "s#<param name=\"filename\">.*</param>#<param name=\"filename\">${fname}</param>#" \
  "$SERVICE"

echo "bumped $current -> $new"

if [ "$commit" -eq 1 ]; then
  cd "$REPO_ROOT"
  git add "packaging/$PKG.spec" packaging/_service
  git commit -m "$PKG ${new}: update to upstream release

SHA256 ${sha} (verified in %prep at build time)."
  echo "committed"
fi
