#!/usr/bin/env bash
# Mirror skills that live in their own repos into this catalog, so skills.sh has
# something to index here. Each mirrored payload is byte-identical to the source
# release -- provenance goes in MIRRORS.md, never inside the skill directory, so
# "identical to upstream" stays a property you can actually check.
#
# One way only: the source repo is canonical. Nothing here is ever pushed back.
#
# Run it locally the same way CI does:
#   scripts/sync-mirrors.sh            # sync, report what changed
#   scripts/sync-mirrors.sh --check    # report only, change nothing (exit 1 if stale)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
CHECK_ONLY=""
[ "${1:-}" = "--check" ] && CHECK_ONLY=yes

# <source-repo>:<path-in-source>:<path-here>
MIRRORS="jesserobbins/greenroom:skills/greenroom:skills/greenroom"

api() {
  # GITHUB_TOKEN lifts the rate limit in CI; the public API works without it locally.
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    curl -sSfL -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" "$@"
  else
    curl -sSfL -H "Accept: application/vnd.github+json" "$@"
  fi
}

# newest_release <owner/repo>: the most recent release tag INCLUDING prereleases.
# /releases/latest deliberately skips prereleases and 404s on a repo that has only
# those -- which is exactly greenroom's situation, so it must not be used here.
newest_release() {
  api "https://api.github.com/repos/$1/releases?per_page=1" \
    | python3 -c 'import json,sys; r=json.load(sys.stdin); print(r[0]["tag_name"] if r else "")'
}

changed=0
stale=""

for entry in $MIRRORS; do
  src="${entry%%:*}"; rest="${entry#*:}"
  src_path="${rest%%:*}"; dest_path="${rest##*:}"
  dest="$REPO_ROOT/$dest_path"

  tag="$(newest_release "$src")"
  [ -n "$tag" ] || { echo "!! $src has no releases; skipping" >&2; continue; }

  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  api "https://api.github.com/repos/$src/tarball/$tag" -o "$work/src.tar.gz"
  tar -xzf "$work/src.tar.gz" -C "$work"
  # A GitHub tarball extracts under a single <owner>-<repo>-<sha>/ directory.
  top="$(find "$work" -mindepth 1 -maxdepth 1 -type d ! -name '*.tar.gz' | head -1)"
  payload="$top/$src_path"
  [ -d "$payload" ] || { echo "!! $src_path not found in $src@$tag" >&2; exit 1; }
  [ -f "$payload/SKILL.md" ] || { echo "!! $src_path has no SKILL.md in $src@$tag" >&2; exit 1; }

  if [ -d "$dest" ] && diff -rq "$payload" "$dest" >/dev/null 2>&1; then
    echo "ok   $dest_path is current with $src@$tag"
  else
    stale="$stale $dest_path"
    if [ -n "$CHECK_ONLY" ]; then
      echo "STALE $dest_path differs from $src@$tag"
    else
      rm -rf "$dest"; mkdir -p "$(dirname "$dest")"; cp -R "$payload" "$dest"
      echo "sync $dest_path <- $src@$tag"
      changed=1
    fi
  fi

  # The README carries a version label per entry; keep it in step automatically
  # rather than by hand, which is how it drifted twice in a day.
  version="${tag#v}"
  if [ -z "$CHECK_ONLY" ]; then
    python3 - "$REPO_ROOT/README.md" "$src" "$version" <<'PY'
import re, sys, pathlib
readme, src, version = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
name = src.split("/")[-1]
s = readme.read_text()
new = re.sub(rf"(### \[{re.escape(name)}\]\([^)]*\) — )`[^`]*`", rf"\1`{version}`", s)
if new != s:
    readme.write_text(new); print(f"sync README label for {name} -> {version}")
PY
  fi

  # Provenance lives OUTSIDE the payload so the mirror stays byte-identical.
  if [ -z "$CHECK_ONLY" ]; then
    printf '%s\n' "$dest_path <- https://github.com/$src @ $tag" >> "$work/mirrors.txt"
  fi
  rm -rf "$work"; trap - EXIT
done

if [ -n "$CHECK_ONLY" ]; then
  [ -z "$stale" ] || { echo; echo "stale mirrors:$stale"; exit 1; }
  echo "all mirrors current"
fi
exit 0
