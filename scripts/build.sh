#!/bin/bash
# hbrew-pkg — one-click cross-build of a riscv64_ohos Harmonybrew bottle.
#
# Downloads the source (or uses a local tarball), configures and builds it with
# the SpacemiT musl toolchain, fixes the ELF runpaths, packs a bottle in the
# layout brew expects, and emits a formula.
#
#   ./scripts/build.sh recipes/<name>.sh          # build one recipe
#   ./scripts/build.sh --all                      # build every recipe
#   ./scripts/build.sh --list                     # list recipes
#
# Recipe format: a plain shell file that sets
#   NAME VERSION URL [SHA256] [DESC] [HOMEPAGE] [DEPS]
#   BUILD_METHOD   autoconf | cmake | make | custom
#   and optionally overrides
#   CONFIGURE_ARGS / CMAKE_ARGS / MAKE_TARGET / INSTALL_CMD / EXTRA_LDFLAGS
#   POST_BUILD()   shell function for special fixes
#
# Everything lands in out/:
#   out/<name>-<ver>.riscv64_ohos.bottle.tar.gz
#   out/<name>.rb
#
# Environment (override as needed):
#   HBREW_TC       toolchain prefix        (default: SpacemiT musl OHOS)
#   HBREW_PREFIX   device prefix           (default: /data/harmonybrew)
#   HBREW_OUT      output dir              (default: ./out)
#   HBREW_JOBS     parallel make jobs      (default: nproc)
#   HBREW_SRC      source cache dir        (default: ./src)

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

HBREW_TC="${HBREW_TC:-$HOME/WorkSpace/spacemit-toolchain-linux-musl-x86_64-oh-20260630}"
HBREW_PREFIX="${HBREW_PREFIX:-/data/harmonybrew}"
HBREW_OUT="${HBREW_OUT:-$ROOT/out}"
HBREW_SRC="${HBREW_SRC:-$ROOT/src}"
HBREW_JOBS="${HBREW_JOBS:-$(nproc 2>/dev/null || echo 8)}"
HBREW_TAG="riscv64_ohos"
HOST="riscv64-unknown-linux-musl"

export PATH="$HBREW_TC/bin:$PATH"
export CC="${HOST}-gcc" CXX="${HOST}-g++" AR="${HOST}-ar" RANLIB="${HOST}-ranlib" STRIP="${HOST}-strip"
export CFLAGS="${CFLAGS:--O2 -pipe}" CXXFLAGS="${CXXFLAGS:--O2 -pipe}"
# Runtime library search path baked into every binary we produce.
RPATH_FLAGS="-Wl,-rpath,$HBREW_PREFIX/lib"

mkdir -p "$HBREW_OUT" "$HBREW_SRC" "$ROOT/build" "$ROOT/logs"

log()  { echo "[build $(date +%H:%M:%S)] $*"; }
warn() { echo "[build WARN] $*" >&2; }
die()  { echo "[build FATAL] $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Network: non-interactive shells do not source ~/.bashrc, so the corporate
# proxy is usually missing here and every download times out. Detect and
# apply it, unless the caller already exported one.
if [ -z "${http_proxy:-}" ] && [ -z "${https_proxy:-}" ]; then
    for cand in "http://proxy1.dc.com:1080" "$(grep -hoE 'proxy=[^ ]+' "$HOME/.bashrc" 2>/dev/null | head -1 | cut -d= -f2-)"; do
        [ -n "$cand" ] || continue
        hostport="${cand#*://}"
        host="${hostport%%:*}"
        port="${hostport##*:}"
        if (echo > "/dev/tcp/$host/$port") 2>/dev/null; then
            export http_proxy="$cand" https_proxy="$cand"
            export no_proxy="${no_proxy:-10.0.0.0/8,localhost,127.0.0.1}"
            log "proxy: $cand"
            break
        fi
    done
fi

# ---------------------------------------------------------------------------
fetch() {  # fetch <url> [sha256] -> prints local path
    local url="$1" want="${2:-}" f
    f="$HBREW_SRC/${url##*/}"
    if [ ! -f "$f" ]; then
        log "downloading ${url##*/}"
        curl -fL --retry 3 --connect-timeout 20 -o "$f.part" "$url" \
            || { rm -f "$f.part"; die "download failed: $url"; }
        mv "$f.part" "$f"
    fi
    if [ -n "$want" ]; then
        local got
        got="$(sha256sum "$f" | cut -d' ' -f1)"
        [ "$got" = "$want" ] || die "sha256 mismatch for ${url##*/}
  want $want
  got  $got"
    fi
    echo "$f"
}

# ---------------------------------------------------------------------------
# fix_rpaths <stage-prefix> <name> <version>
# Rewrite DT_RPATH/DT_RUNPATH that point at the build host so the device can
# resolve its own libraries. Pure Python (patchelf is often unavailable).
fix_rpaths() {
    local stage="$1" name="$2" ver="$3"
    local tool="$HERE/elf_rpath.py"
    [ -f "$tool" ] || { warn "elf_rpath.py missing, skipping rpath fix"; return 0; }
    local want="$HBREW_PREFIX/lib:$HBREW_PREFIX/Cellar/$name/$ver/lib"
    local n=0 bad=0
    while IFS= read -r elf; do
        [ -f "$elf" ] || continue
        local cur
        cur="$(python3 "$tool" --get "$elf" 2>/dev/null || true)"
        [ -n "$cur" ] && [ "$cur" != "(none)" ] || continue
        case "$cur" in
            "$HBREW_PREFIX"*) continue ;;
        esac
        bad=$((bad + 1))
        if python3 "$tool" --set "$elf" "$want" >/dev/null 2>&1; then
            n=$((n + 1))
        else
            warn "rpath not rewritable: ${elf#"$stage"/} (left as $cur)"
        fi
    done < <(find "$stage" -type f \( -perm -u+x -o -name '*.so' -o -name '*.so.*' \) 2>/dev/null)
    [ "$bad" -gt 0 ] && log "rpath: $n fixed / $bad offending -> $want"
    return 0
}

# ---------------------------------------------------------------------------
write_formula() {  # <name> <ver> <desc> <homepage> <deps> <sha>
    local name="$1" ver="$2" desc="$3" homepage="$4" deps="$5" sha="$6"
    local cls letter deps_block=""
    cls="$(printf '%s' "$name" | sed -E 's/[-_.](.)/\U\1/g; s/^(.)/\U\1/')"
    letter="${name:0:1}"
    for d in $deps; do deps_block="${deps_block}  depends_on \"$d\""$'\n'; done

    local root_url="${HBREW_ROOT_URL:-https://github.com/${GITHUB_REPO:-shihuan1999/harmonybrew-riscv64-pkgs}/releases/download/bottles}"
    cat > "$HBREW_OUT/$name.rb" <<RUBY
# Generated by hbrew-pkg/scripts/build.sh — Harmonybrew $HBREW_TAG
class $cls < Formula
  desc "$desc"
  homepage "$homepage"
  url "$root_url/$name-$ver.$HBREW_TAG.bottle.tar.gz"
  sha256 "$sha"
  version "$ver"

  bottle do
    root_url "$root_url"
    sha256 cellar: :any_skip_relocation, $HBREW_TAG: "$sha"
  end

$deps_block
  def install
    prefix.install Dir["*"]
  end

  test do
    system "true"
  end
end
RUBY
    echo "$HBREW_OUT/$name.rb"
}

# ---------------------------------------------------------------------------
build_recipe() {  # <recipe-file>
    local recipe="$1"
    [ -f "$recipe" ] || die "no such recipe: $recipe"

    # Reset per-recipe knobs
    NAME="" VERSION="" URL="" SHA256="" DESC="" HOMEPAGE="" DEPS=""
    BUILD_METHOD="autoconf"
    CONFIGURE_ARGS="" CMAKE_ARGS="" MAKE_TARGET="" INSTALL_CMD="" EXTRA_LDFLAGS=""
    POST_BUILD() { :; }

    # shellcheck disable=SC1090
    . "$recipe"
    [ -n "$NAME" ] && [ -n "$VERSION" ] && [ -n "$URL" ] \
        || die "$recipe: NAME/VERSION/URL required"

    local log="$ROOT/logs/$NAME.log"
    : > "$log"
    log "==== $NAME $VERSION ($BUILD_METHOD) ===="

    local tarball
    tarball="$(fetch "$URL" "${SHA256:-}")" || exit 1

    local work="$ROOT/build/$NAME-$VERSION"
    rm -rf "$work"
    mkdir -p "$work"
    tar xf "$tarball" -C "$work" --strip-components=1 2>/dev/null \
        || tar xf "$tarball" -C "$work"

    local stage="$HBREW_OUT/stage/$NAME/$VERSION"
    rm -rf "$HBREW_OUT/stage/$NAME"
    mkdir -p "$stage"
    # Recipes reference these in INSTALL_CMD / CUSTOM_BUILD / POST_BUILD.
    # CONFIGURE_ARGS-style single-quoted strings must therefore expand at run
    # time, so export both.
    export stage HBREW_JOBS

    (
        cd "$work" || exit 1
        export LDFLAGS="${LDFLAGS:-} $RPATH_FLAGS $EXTRA_LDFLAGS"
        export CPPFLAGS="${CPPFLAGS:-} -I$stage/include"
        case "$BUILD_METHOD" in
            autoconf)
                [ -x ./configure ] || { [ -x ./autogen.sh ] && ./autogen.sh; } || true
                [ -x ./configure ] || { echo "no configure script"; exit 1; }
                ./configure --host="$HOST" --build="$(uname -m)-linux-gnu" \
                    --prefix="$stage" --disable-shared --enable-static \
                    $CONFIGURE_ARGS
                make -j"$HBREW_JOBS" $MAKE_TARGET
                make install
                ;;
            cmake)
                cmake -B build -S . \
                    -DCMAKE_SYSTEM_NAME=Linux \
                    -DCMAKE_C_COMPILER="$CC" \
                    -DCMAKE_CXX_COMPILER="$CXX" \
                    -DCMAKE_INSTALL_PREFIX="$stage" \
                    -DCMAKE_BUILD_TYPE=Release \
                    -DBUILD_SHARED_LIBS=OFF \
                    $CMAKE_ARGS
                cmake --build build -j "$HBREW_JOBS"
                cmake --install build
                ;;
            make)
                make -j"$HBREW_JOBS" PREFIX="$stage" $MAKE_TARGET
                if [ -n "$INSTALL_CMD" ]; then
                    eval "$INSTALL_CMD"
                else
                    make install PREFIX="$stage"
                fi
                ;;
            custom)
                eval "${CUSTOM_BUILD:?custom needs CUSTOM_BUILD}"
                # custom recipes usually need their own install step
                if [ -n "$INSTALL_CMD" ]; then
                    eval "$INSTALL_CMD"
                fi
                ;;
            *)
                echo "unknown BUILD_METHOD: $BUILD_METHOD"; exit 1 ;;
        esac
        # Any recipe may supply extra post-install steps
        [ -n "${EXTRA_INSTALL:-}" ] && eval "$EXTRA_INSTALL"
        true
    ) >> "$log" 2>&1
    local rc=$?
    if [ "$rc" -ne 0 ]; then
        tail -25 "$log" >&2
        die "$NAME build failed (log: $log)"
    fi

    POST_BUILD "$stage" >> "$log" 2>&1 || warn "POST_BUILD reported failure (see $log)"

    # strip, then repair rpaths
    find "$stage" -type f \( -perm -u+x -o -name '*.so*' \) 2>/dev/null | while read -r f; do
        head -c 4 "$f" 2>/dev/null | grep -q ELF && "$STRIP" "$f" 2>/dev/null || true
    done
    fix_rpaths "$stage" "$NAME" "$VERSION"

    [ -n "$(ls -A "$stage" 2>/dev/null)" ] || die "$NAME produced an empty prefix"

    # ---- bottle (keg layout: <name>/<ver>/...) ----
    local bottle="$HBREW_OUT/$NAME-$VERSION.$HBREW_TAG.bottle.tar.gz"
    local tmpkeg="$HBREW_OUT/stage/_keg_$NAME"
    rm -rf "$tmpkeg"
    mkdir -p "$tmpkeg/$NAME"
    cp -a "$stage" "$tmpkeg/$NAME/$VERSION"
    ( cd "$tmpkeg" && tar czf "$bottle" "$NAME" )
    rm -rf "$tmpkeg"
    local sha
    sha="$(sha256sum "$bottle" | cut -d' ' -f1)"
    log "bottle: $(basename "$bottle")  sha256=$sha  ($(du -h "$bottle" | cut -f1))"

    local formula
    formula="$(write_formula "$NAME" "$VERSION" "${DESC:-$NAME}" \
        "${HOMEPAGE:-https://example.invalid/$NAME}" "${DEPS:-}" "$sha")"
    log "formula: ${formula#"$ROOT"/}"
    echo "$NAME $VERSION $sha" >> "$HBREW_OUT/INDEX.txt"
}

# ---------------------------------------------------------------------------
case "${1:-}" in
    --list)
        for r in "$ROOT"/recipes/*.sh; do
            [ -f "$r" ] || continue
            ( . "$r" >/dev/null 2>&1; printf '%-22s %-10s %s\n' "${NAME:-?}" "${VERSION:-?}" "${DESC:-}" )
        done
        ;;
    --all)
        fail=0
        for r in "$ROOT"/recipes/*.sh; do
            [ -f "$r" ] || continue
            build_recipe "$r" || fail=$((fail + 1))
        done
        log "done: $fail recipe(s) failed"
        [ "$fail" -eq 0 ]
        ;;
    "")
        sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
        exit 1
        ;;
    *)
        for r in "$@"; do
            [ -f "$r" ] || r="$ROOT/recipes/$r.sh"
            build_recipe "$r" || exit 1
        done
        ;;
esac
