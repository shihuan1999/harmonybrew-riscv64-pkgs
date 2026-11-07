#!/bin/bash
# install-on-device.sh — deploy the zero-step installer to a device and
# install/uninstall bottles by name.
#
#   ./scripts/install-on-device.sh setup            # push scripts + enable
#   ./scripts/install-on-device.sh install <name>   # brew install from release
#   ./scripts/install-on-device.sh uninstall <name>
#   ./scripts/install-on-device.sh list
#
# Set TARGET to your hdc device key (default: first device).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
DEV="$ROOT/device"
PREFIX=/data/harmonybrew
REPO="${GITHUB_REPO:-shihuan1999/harmonybrew-riscv64-pkgs}"
TAG="${HBREW_TAG_RELEASE:-bottles}"
TARGET="${TARGET:-}"
HDC="hdc"
[ -n "$TARGET" ] && HDC="hdc -t $TARGET"

sh_dev() { MSYS_NO_PATHCONV=1 $HDC shell "$1" 2>&1 | grep -v 'Not support std mode' || true; }
push()   { MSYS_NO_PATHCONV=1 $HDC file send "$1" "$2" >/dev/null 2>&1; }

cmd="${1:-}"; shift || true
case "$cmd" in
  setup)
      echo "deploying zero-step installer to device"
      for f in hbrew-systemlink brewboot hbrew-farm-watch hbrew-farm hbrew-fix-rpath; do
          [ -f "$DEV/$f" ] || continue
          push "$DEV/$f" "$PREFIX/sbin/$f"
          sh_dev "sed -i 's/\r\$//' $PREFIX/sbin/$f; chmod 755 $PREFIX/sbin/$f"
      done
      sh_dev "$PREFIX/sbin/brewboot"
      echo "installed. try: brew install tree && tree --version"
      ;;
  install)
      n="${1:?usage: install <name>}"
      sh_dev "cd /tmp && curl -fsL -o $n.rb https://github.com/$REPO/releases/download/$TAG/$n.rb && brew install /tmp/$n.rb"
      ;;
  uninstall)
      n="${1:?usage: uninstall <name>}"
      sh_dev "brew uninstall $n"
      ;;
  list)
      sh_dev "brew list --versions"
      ;;
  *)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 1
      ;;
esac
