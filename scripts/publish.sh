#!/bin/bash
# publish.sh — upload bottles + formulas to a GitHub release.
#
#   ./scripts/publish.sh <tag> [bottles-dir]
#
# Authentication
#   This environment's GitHub credential is a classic PAT that only
#   authenticates with HTTP Basic (-u user:token); the modern
#   "Authorization: Bearer" scheme is rejected here with 401. So we build a
#   user:token pair and use -u everywhere.
#
#   Credential source, in order:
#     1. $GITHUB_TOKEN, either "user:token" or a bare token
#     2. git's credential store entry for github.com
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

TAG="${1:?usage: publish.sh <tag> [bottles-dir]}"
OUT="${2:-$ROOT/out}"
REPO="${GITHUB_REPO:-shihuan1999/harmonybrew-riscv64-pkgs}"
TAGSUFFIX="${HBREW_TAG:-riscv64_ohos}"

store_cred() {
    grep 'github.com' "$HOME/.git-credentials" 2>/dev/null | head -1 \
        | sed 's|https://||;s|@github.com||'
}

CRED="${GITHUB_TOKEN:-}"
if [ -z "$CRED" ]; then
    CRED="$(store_cred)"
elif [ "${CRED#*:}" = "$CRED" ]; then
    # bare token given: borrow the username from the credential store
    user="$(store_cred | cut -d: -f1)"
    CRED="${user:-shihuan1999}:$CRED"
fi
[ -n "$CRED" ] || { echo "no GitHub credential (set GITHUB_TOKEN=user:token)" >&2; exit 1; }

API="https://api.github.com/repos/$REPO"
api() { curl -fsS -u "$CRED" -H "Accept: application/vnd.github+json" "$@"; }

[ -d "$OUT" ] || { echo "no such dir: $OUT" >&2; exit 1; }

# 1) create the release if it does not exist yet
REL_ID="$(api "$API/releases/tags/$TAG" 2>/dev/null \
          | grep -oP '"id":\s*\K[0-9]+' | head -1 || true)"
if [ -z "$REL_ID" ]; then
    echo "creating release $TAG"
    REL_ID="$(api -X POST "$API/releases" \
        -d "{\"tag_name\":\"$TAG\",\"name\":\"Harmonybrew bottles $TAG\",\"body\":\"Prebuilt $TAGSUFFIX bottles for OpenHarmony riscv64.\"}" \
        | grep -oP '"id":\s*\K[0-9]+' | head -1)"
fi
[ -n "$REL_ID" ] || { echo "cannot create/find release" >&2; exit 1; }
echo "release id: $REL_ID"

UPLOAD="https://uploads.github.com/repos/$REPO/releases/$REL_ID/assets"

upload() {  # upload <file>
    local f="$1" name code
    name="$(basename "$f")"
    printf '  %-50s ' "$name"
    code="$(curl -s -o /tmp/gh-up.log -w '%{http_code}' -X POST \
        -u "$CRED" \
        -H "Content-Type: application/octet-stream" \
        --data-binary "@$f" "$UPLOAD?name=$name")"
    case "$code" in
        201) echo "ok" ;;
        422) echo "exists (skip)" ;;
        *)   echo "FAILED ($code)"; tail -3 /tmp/gh-up.log ;;
    esac
}

echo "uploading bottles:"
for f in "$OUT"/*."$TAGSUFFIX".bottle.tar.gz; do
    [ -f "$f" ] && upload "$f"
done
echo "uploading formulas:"
for f in "$OUT"/*.rb; do
    [ -f "$f" ] && upload "$f"
done
[ -f "$OUT/INDEX.txt" ] && upload "$OUT/INDEX.txt"

echo "done: https://github.com/$REPO/releases/tag/$TAG"
