#!/bin/bash
# publish.sh — upload bottles + formulas to a GitHub release.
#
#   ./scripts/publish.sh <tag> [bottles-dir]
#
# Requires a GitHub token in $GITHUB_TOKEN (repo scope) or a git credential
# store entry for github.com. Uses the REST API directly so `gh` is optional.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

TAG="${1:?usage: publish.sh <tag> [bottles-dir]}"
OUT="${2:-$ROOT/out}"
REPO="${GITHUB_REPO:-shihuan1999/harmonybrew-riscv64-pkgs}"

TOKEN="${GITHUB_TOKEN:-}"
if [ -z "$TOKEN" ]; then
    # reuse git's credential store when no explicit token is given
    TOKEN="$(grep 'github.com' "$HOME/.git-credentials" 2>/dev/null | head -1 \
             | sed 's|https://||;s|@github.com||;s|^[^:]*:||')"
fi
[ -n "$TOKEN" ] || { echo "no GitHub token (set GITHUB_TOKEN)" >&2; exit 1; }
API="https://api.github.com/repos/$REPO"

api() { curl -fsS -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github+json" "$@"; }

[ -d "$OUT" ] || { echo "no such dir: $OUT" >&2; exit 1; }

# 1) create the release if it does not exist yet
REL_ID="$(api "$API/releases/tags/$TAG" 2>/dev/null | grep -oP '"id":\s*\K[0-9]+' | head -1 || true)"
if [ -z "$REL_ID" ]; then
    echo "creating release $TAG"
    REL_ID="$(api -X POST "$API/releases" \
        -d "{\"tag_name\":\"$TAG\",\"name\":\"Harmonybrew bottles $TAG\",\"body\":\"Prebuilt riscv64_ohos bottles.\"}" \
        | grep -oP '"id":\s*\K[0-9]+' | head -1)"
fi
[ -n "$REL_ID" ] || { echo "cannot create/find release" >&2; exit 1; }
echo "release id: $REL_ID"

UPLOAD="https://uploads.github.com/repos/$REPO/releases/$REL_ID/assets"

upload() {  # upload <file>
    local f="$1" name
    name="$(basename "$f")"
    printf '  %-52s ' "$name"
    local code
    code="$(curl -s -o /tmp/gh-up.log -w '%{http_code}' -X POST \
        -H "Authorization: token $TOKEN" \
        -H "Content-Type: application/octet-stream" \
        --data-binary "@$f" "$UPLOAD?name=$name")"
    if [ "$code" = "201" ]; then echo "ok"
    elif [ "$code" = "422" ]; then echo "exists (skip)"
    else echo "FAILED ($code)"; tail -3 /tmp/gh-up.log; fi
}

echo "uploading bottles:"
for f in "$OUT"/*."${HBREW_TAG:-riscv64_ohos}".bottle.tar.gz; do
    [ -f "$f" ] && upload "$f"
done
echo "uploading formulas:"
for f in "$OUT"/*.rb; do
    [ -f "$f" ] && upload "$f"
done
[ -f "$OUT/INDEX.txt" ] && upload "$OUT/INDEX.txt"

echo "done: https://github.com/$REPO/releases/tag/$TAG"
