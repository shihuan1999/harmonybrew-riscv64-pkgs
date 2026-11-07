#!/bin/bash
# fill-sha256.sh — download every recipe's source and write the real SHA256
# back into the recipe file. Idempotent: existing correct hashes are kept,
# missing/wrong ones are refreshed.
#
#   ./scripts/fill-sha256.sh              # all recipes
#   ./scripts/fill-sha256.sh gsl fftw     # selected recipes
#
# Downloads land in ./src/ (git-ignored) and are reused by build.sh.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SRC="${HBREW_SRC:-$ROOT/src}"
mkdir -p "$SRC"

# Non-interactive shells do not read ~/.bashrc, so the corporate proxy has to
# be applied explicitly or every download stalls.
if [ -z "${http_proxy:-}" ] && [ -z "${https_proxy:-}" ]; then
    for cand in "http://proxy1.dc.com:1080" "$(grep -hoE 'proxy=[^ ]+' "$HOME/.bashrc" 2>/dev/null | head -1 | cut -d= -f2-)"; do
        [ -n "$cand" ] || continue
        hostport="${cand#*://}"
        if (echo > "/dev/tcp/${hostport%%:*}/${hostport##*:}") 2>/dev/null; then
            export http_proxy="$cand" https_proxy="$cand"
            echo "proxy: $cand"
            break
        fi
    done
fi

targets=("$@")
[ "${#targets[@]}" -eq 0 ] && targets=("$ROOT"/recipes/*.sh)

ok=0 fail=0 skip=0
for r in "${targets[@]}"; do
    [ -f "$r" ] || r="$ROOT/recipes/$r.sh"
    [ -f "$r" ] || { echo "missing recipe: $r" >&2; fail=$((fail + 1)); continue; }
    NAME="" VERSION="" URL="" SHA256=""
    # shellcheck disable=SC1090
    . "$r"
    [ -n "$URL" ] || { echo "$(basename "$r"): no URL"; skip=$((skip + 1)); continue; }
    f="$SRC/${URL##*/}"
    if [ ! -s "$f" ]; then
        printf '%-18s downloading... ' "$NAME"
        if ! curl -fsL --retry 2 --connect-timeout 20 -m 300 -o "$f.part" "$URL"; then
            rm -f "$f.part"; echo "FAILED"; fail=$((fail + 1)); continue
        fi
        mv "$f.part" "$f"
        echo "ok"
    fi
    got="$(sha256sum "$f" | cut -d' ' -f1)"
    if [ "$got" = "${SHA256:-}" ]; then
        printf '%-18s sha ok\n' "$NAME"
        ok=$((ok + 1))
        continue
    fi
    if grep -q '^SHA256=' "$r"; then
        sed -i "s|^SHA256=.*|SHA256=\"$got\"|" "$r"
    else
        sed -i "s|^URL=.*|&\nSHA256=\"$got\"|" "$r"
    fi
    printf '%-18s sha updated %s\n' "$NAME" "${got:0:16}..."
    ok=$((ok + 1))
done

echo "fill-sha256: ok=$ok failed=$fail skipped=$skip"
[ "$fail" -eq 0 ]
