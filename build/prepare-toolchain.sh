#!/bin/bash
# Get everything the build needs.
#
# In the riscos-crossdev container image (RISCOS_TOOLCHAIN set), the
# toolchain is the image's and nothing is done to it. Outside the image:
#   1. unpack riscos-crossdev's prebuilt toolchain ($TOOLCHAIN_TARBALL in
#      $DL, checked) into $GCCSDK_ENV;
#   2. delete libtool .la files: they hold the build machine's absolute
#      paths, which break libtool links once the toolchain has moved;
#   3. delete any shared libraries (static only), except libgcc_s, which
#      libtool's own test links ask for;
#   4. optionally put a riscos-unixlib release's libunixlib.a over the
#      toolchain's (UNIXLIB: dl/$UNIXLIB/libunixlib.a).
# Then, always, build/fetch.sh: the sources and the riscos-mesa devkit
# .riscos-deps names.
set -e
. "$(dirname "$0")/env.sh"

if [ -n "$RISCOS_TOOLCHAIN" ] && [ "$GCCSDK_ENV" = "$RISCOS_TOOLCHAIN" ]; then
  echo "toolchain: $RISCOS_TOOLCHAIN (riscos-crossdev image)"
else
  check_sha "$DL/$TOOLCHAIN_TARBALL"
  parent=$(dirname "$GCCSDK_ENV")
  mkdir -p "$parent"
  rm -rf "$GCCSDK_ENV"
  tar xJf "$DL/$TOOLCHAIN_TARBALL" -C "$parent"
  TC=${TOOLCHAIN_TARBALL%.tar.xz}
  [ "$parent/$TC" = "$GCCSDK_ENV" ] || ln -sfn "$parent/$TC" "$GCCSDK_ENV"

  T=$GCCSDK_ENV/arm-riscos-gnueabihf
  find -L "$GCCSDK_ENV/" -name '*.la' -delete
  if [ -n "$UNIXLIB" ]; then
    check_sha "$DL/$UNIXLIB/libunixlib.a"
    cp "$DL/$UNIXLIB/libunixlib.a" "$T/lib/libunixlib.a"
    echo "UnixLib: $UNIXLIB"
  fi
  find -L "$T/lib" -maxdepth 1 -name '*.so*' ! -name 'libgcc_s.so*' -delete
fi
echo "toolchain ready: $($TARGET-gcc --version | head -1)"

"$RFH_ROOT/build/fetch.sh"
