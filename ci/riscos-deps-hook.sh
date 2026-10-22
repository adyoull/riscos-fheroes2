#!/bin/sh
# Run by .github/workflows/riscos-deps-update.yml as
#   ci/riscos-deps-hook.sh NAME OLD_TAG NEW_TAG
# from the top of the repository when NAME (a line of .riscos-deps) has a
# newer release, to move the pins kept outside .riscos-deps, the sha256
# lines in build/SHA256SUMS.txt (build/env.sh reads the versions from
# .riscos-deps):
#   riscos-mesa      the devkit, riscos-mesa-devkit-<version>.tgz
#   riscos-softmidi  its source (GitHub's archive of the tag) and its release
#                    zip SoftMIDI-<version>.zip (the TimGM6mb SoundFont)
#   riscos-crossdev  nothing (the workflows' image, and so the toolchain,
#                    follows .riscos-deps)
set -eu
name=${1#adyoull/} old=${2#v} new=${3#v}
sums=build/SHA256SUMS.txt
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# move FILE_OLD FILE_NEW URL: replace FILE_OLD's line with FILE_NEW and its sha256.
move() {
  curl -fsSL --retry 3 -o "$tmp/$2" "$3"
  sum=$(sha256sum "$tmp/$2" | cut -d' ' -f1)
  grep -q "  $1\$" "$sums" || { echo "riscos-deps-hook: no $1 line in $sums" >&2; exit 1; }
  awk -v o="$1" -v n="$2" -v s="$sum" '$2 == o {print s "  " n; next} {print}' "$sums" > "$tmp/sums"
  cat "$tmp/sums" > "$sums"
  echo "riscos-deps-hook: $2 $sum"
}

case $name in
riscos-mesa)
  move "riscos-mesa-devkit-$old.tgz" "riscos-mesa-devkit-$new.tgz" \
    "https://github.com/adyoull/riscos-mesa/releases/download/v$new/riscos-mesa-devkit-$new.tgz"
  ;;
riscos-softmidi)
  move "riscos-softmidi-$old.tar.gz" "riscos-softmidi-$new.tar.gz" \
    "https://github.com/adyoull/riscos-softmidi/archive/refs/tags/v$new.tar.gz"
  move "SoftMIDI-$old.zip" "SoftMIDI-$new.zip" \
    "https://github.com/adyoull/riscos-softmidi/releases/download/v$new/SoftMIDI-$new.zip"
  ;;
esac
