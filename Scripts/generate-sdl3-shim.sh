#!/bin/sh

cd "$(dirname "${0}")/.."

echo "#pragma once"
echo ""
echo "#include <SDL3/SDL.h>"
echo ""
grep -r 'UINT64_C' Frameworks/SDL3.xcframework/macos-arm64_x86_64/SDL3.framework/Versions/A/Headers | awk -F ':' '{print $2}' | grep -F '#define' | grep "UINT64_C(0x" | while read -r LINE
do
  MACRO_NAME="$(echo "${LINE}" | awk '{print $2}')"
  ACTUAL_STUFF="$(echo "${LINE}" | awk -F 'SDL_UINT64_C\\(' '{print $2}' | sed 's/)/UL/')"
  echo "#undef ${MACRO_NAME}"
  echo "#define ${MACRO_NAME} ${ACTUAL_STUFF}"
done
