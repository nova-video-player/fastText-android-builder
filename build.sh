#!/bin/bash
# Copyright 2026 Courville Software
# SPDX-License-Identifier: Apache-2.0

set -e -o pipefail

usage() {
  echo "Usage: bash build.sh [-a arm|arm64|x86|x86_64]"
  echo "Without -a, builds NDK_APP_ABI or all four Nova ABIs."
}

ARCH=
while getopts ":a:h" opt; do
  case "$opt" in
    a) ARCH=$OPTARG ;;
    h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))
if [ "$#" -ne 0 ]; then
  usage >&2
  exit 2
fi

ABIS=()
if [ -n "$ARCH" ]; then
  ABIS=("$ARCH")
else
  read -r -a ABIS <<< "${NDK_APP_ABI:-armeabi-v7a arm64-v8a x86 x86_64}"
fi
for i in "${!ABIS[@]}"; do
  case "${ABIS[$i]}" in
    arm|armeabi-v7a) ABIS[$i]=armeabi-v7a ;;
    arm64|arm64-v8a) ABIS[$i]=arm64-v8a ;;
    x86|x86_64) ;;
    *) echo "Unsupported architecture: ${ABIS[$i]}" >&2; exit 2 ;;
  esac
done
if [ "${#ABIS[@]}" -eq 0 ]; then
  echo "No Android ABIs selected." >&2
  exit 2
fi

LOCAL_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$LOCAL_PATH"
# Shared setup expects optional SDK environment variables to be unset safely.
source ../../AVP/android-setup-light.sh
set -u

if [ ! -f "${NDK_PATH:-}/build/cmake/android.toolchain.cmake" ]; then
  echo "Android NDK not found; configure ANDROID_SDK_ROOT as for the other Nova builders." >&2
  exit 1
fi
CMAKE=${CMAKE_PATH:+${CMAKE_PATH}/bin/}cmake

mkdir -p ../prebuilt/fastText downloads
PREBUILT_DIR=$(cd ../prebuilt/fastText && pwd)
FASTTEXT_VERSION=0.9.2
SOURCE_DIR="${LOCAL_PATH}/fastText-${FASTTEXT_VERSION}"
SOURCE_SHA256=7ea4edcdb64bfc6faaaec193ef181bdc108ee62bb6a04e48b2e80b639a99e27e
MODEL_SHA256=8f3472cfe8738a7b6099e8e999c3cbfae0dcd15696aac7d7738a8039db603e83

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d ' ' -f 1
  else
    shasum -a 256 "$1" | cut -d ' ' -f 1
  fi
}

download() {
  local url=$1 destination=$2 expected=$3 temporary
  if [ -f "$destination" ]; then
    if [ "$(sha256 "$destination")" = "$expected" ]; then
      chmod 644 "$destination"
      return
    fi
    echo "Checksum mismatch: $destination" >&2
    return 1
  fi
  temporary=$(mktemp "${destination}.XXXXXX")
  if ! curl --fail --location --retry 3 --silent --show-error "$url" -o "$temporary"; then
    rm -f "$temporary"
    return 1
  fi
  if [ "$(sha256 "$temporary")" != "$expected" ]; then
    echo "Checksum mismatch downloading $url" >&2
    rm -f "$temporary"
    return 1
  fi
  chmod 644 "$temporary"
  mv "$temporary" "$destination"
}

download "https://codeload.github.com/facebookresearch/fastText/tar.gz/refs/tags/v${FASTTEXT_VERSION}" \
  "downloads/fastText-${FASTTEXT_VERSION}.tar.gz" "$SOURCE_SHA256"
if [ ! -d "$SOURCE_DIR" ]; then
  tar -xzf "downloads/fastText-${FASTTEXT_VERSION}.tar.gz"
fi

mkdir -p "${PREBUILT_DIR}/share/fastText"
download "https://dl.fbaipublicfiles.com/fasttext/supervised-models/lid.176.ftz" \
  "${PREBUILT_DIR}/share/fastText/lid.176.ftz" "$MODEL_SHA256"
cp "$SOURCE_DIR/LICENSE" "${PREBUILT_DIR}/LICENSE.fastText"
cp LICENSE "${PREBUILT_DIR}/LICENSE"
cp LICENSE.model "${PREBUILT_DIR}/LICENSE.model"
cp NOTICE "${PREBUILT_DIR}/NOTICE"

for ABI in "${ABIS[@]}"; do
  echo "Building fastText ${FASTTEXT_VERSION} for ${ABI}..."
  "$CMAKE" -S "$LOCAL_PATH" -B "build-${ABI}" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="${NDK_PATH}/build/cmake/android.toolchain.cmake" \
    -DANDROID_NDK="$NDK_PATH" \
    -DANDROID_ABI="$ABI" \
    -DANDROID_PLATFORM=android-23 \
    -DANDROID_STL=c++_static \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREBUILT_DIR" \
    -DFASTTEXT_SOURCE_DIR="$SOURCE_DIR" \
    -DBUILD_TESTING=OFF
  "$CMAKE" --build "build-${ABI}" --parallel "$CORES"
  "$CMAKE" --install "build-${ABI}"
  # The NDK includes debug information even in Release archives. Keep linking
  # symbols while avoiding several megabytes of debug data per prebuilt ABI.
  "${NDK_PATH}/toolchains/llvm/prebuilt/${OS}-x86_64/bin/llvm-strip" --strip-debug \
    "${PREBUILT_DIR}/lib/${ABI}/libfasttext.a"
done
