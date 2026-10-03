#!/bin/bash
# Keep patches/fheroes2 and the git work tree in step.
#
#   tools/fh2-patches.sh checkout   work/fheroes2 = fheroes2 $FHEROES2_VERSION (tag pristine)
#                                   + one commit per patch in the series
#   tools/fh2-patches.sh export     work tree commits -> patches/fheroes2/*.patch + series
#   tools/fh2-patches.sh check      the series applied to a fresh tarball gives the work tree
#
# Edit a patch by changing the work tree and amending/fixing up its commit,
# then export. Commits are by Andrew Youll.
set -e
. "$(dirname "$0")/../build/env.sh"
W=$RFH_ROOT/work/fheroes2
P=$RFH_ROOT/patches/fheroes2

case ${1:-} in
checkout)
  check_sha "$DL/fheroes2-$FHEROES2_VERSION.tar.gz"
  rm -rf "$W"; mkdir -p "$RFH_ROOT/work"
  tar xzf "$DL/fheroes2-$FHEROES2_VERSION.tar.gz" -C "$RFH_ROOT/work"
  mv "$RFH_ROOT/work/fheroes2-$FHEROES2_VERSION" "$W"
  cd "$W"
  git init -q
  git config user.name "Andrew Youll"
  git config user.email adyoull@users.noreply.github.com
  echo "/src/dist/fheroes2/fheroes2" >> .git/info/exclude
  git add -A && git commit -qm "fheroes2 $FHEROES2_VERSION" && git tag pristine
  while read -r p; do
    case $p in ""|"#"*) continue ;; esac
    git am -q "$P/$p"
  done < "$P/series"
  git log --oneline pristine..HEAD ;;
export)
  cd "$W"
  rm -f "$P"/*.patch
  git format-patch -q --zero-commit --no-numbered --no-signature -o "$P" pristine..HEAD
  ( cd "$P" && ls *.patch ) > "$P/series"
  cat "$P/series" ;;
check)
  t=$(mktemp -d)
  tar xzf "$DL/fheroes2-$FHEROES2_VERSION.tar.gz" -C "$t"
  while read -r p; do
    case $p in ""|"#"*) continue ;; esac
    patch -d "$t/fheroes2-$FHEROES2_VERSION" -p1 -s < "$P/$p"
  done < "$P/series"
  if diff -r -q -x .git -x '*.o' -x '*.d' -x '*.a' -x fheroes2.pot -x 'fheroes2.pot~' -x '*.mo' \
       -x fheroes2 "$t/fheroes2-$FHEROES2_VERSION" "$W" | grep -v '^Only in .*src/dist/fheroes2: fheroes2$'; then
    echo "DIFFERENT"; rm -rf "$t"; exit 1
  fi
  rm -rf "$t"; echo "OK: the series reproduces the work tree" ;;
*) echo "usage: $0 checkout|export|check" >&2; exit 2 ;;
esac
