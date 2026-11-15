# fastText Android builder

Builds fastText 0.9.2 as a position-independent static C++ library for Nova's
four Android ABIs, with the compact `lid.176.ftz` language identification model.
Uses `AVP/android-setup-light.sh`, CMake, Ninja, and the NDK, like the
`libmysofa-android-builder`. The minimum Android API is 23 and the C++ runtime
is `c++_static`, matching AVOS. No external inference framework is needed.

## Build

From the Nova workspace root:

```sh
make native_build_native/fastText-android-builder
```

Or from this directory:

```sh
bash build.sh             # all four ABIs, or the space-separated NDK_APP_ABI
bash build.sh -a arm64    # arm, arm64, x86, x86_64; Android ABI names also work
```

Set `ANDROID_SDK_ROOT` (or the SDK variables supported by AVP's shared setup)
to an SDK containing the NDK and CMake. The shared setup selects the installed
toolchain. Dependencies also include Bash, curl, tar, Ninja, and either
`sha256sum` or `shasum`. Source and model downloads are SHA-256 checked and
cached; subsequent builds use CMake/Ninja's incremental build. No downloaded
source files are patched. The custom CMake file avoids upstream's host-only
`-march=native` and does not build its CLI or shared library. Installed archives
have debug information stripped, retaining the symbols needed for linking.

Outputs under `../prebuilt/fastText/`:

```text
include/fasttext/*.h
lib/armeabi-v7a/libfasttext.a
lib/arm64-v8a/libfasttext.a
lib/x86/libfasttext.a
lib/x86_64/libfasttext.a
share/fastText/lid.176.ftz
LICENSE
LICENSE.fastText
LICENSE.model
NOTICE
```

The model is shared by all ABIs (938,013 bytes). Its SHA-256 is
`8f3472cfe8738a7b6099e8e999c3cbfae0dcd15696aac7d7738a8039db603e83`.
The source tag `v0.9.2` resolves to
`5b5943c118b0ec5fb9cd8d20587de2b2d3966dfe`; the archive checksum is pinned in
`build.sh`. When updating either dependency, update the checksum as well.

## Native integration

`AVP/core.mk` builds this dependency before AVOS when this builder and AVOS's
`jni/fasttext_prebuilt.mk` are present. The NDK module `fasttext_prebuilt`
exports the headers and makes the ABI-specific archive available to libavos.
Older manifests without this builder continue to work. Static linking allows
unused fastText code to be discarded until there is a runtime caller.

This step supplies the builder, native dependency, and model. It does not yet
package the model into the APK or implement subtitle sampling, a C wrapper,
background detection, or track-label updates. A runtime integration should load
the model once and preserve the model license and attribution in app assets.
Static archives do not have ELF page alignment; their final Android shared
library must use Nova's existing 16 KiB linker alignment.

The workspace root is not a Git repository. This directory and its prebuilt
output are intended as separate repositories, like the other native builders.
The public repositories do not exist yet. After publishing the builder as
`nova-video-player/fastText-android-builder` on `main`, add the following to the
desired AVP manifest; add the prebuilt project only after publishing its output:

```xml
<project path="native/fastText-android-builder" name="fastText-android-builder" revision="main" />
<project path="native/prebuilt/fastText" name="prebuilt-fastText" revision="main" />
```

## Validation

After the builder downloads its source and model, build and run actual model
inference on the host with the same CMake target:

```sh
cmake -S . -B build-host -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=ON
cmake --build build-host
ctest --test-dir build-host --output-on-failure
```

The smoke test loads the compact model and checks English/French detection,
plus failure on a missing model. To run it on Android, configure an Android
build with `BUILD_TESTING=ON`, push `fasttext_smoke` and the model to a device,
then run `fasttext_smoke /path/to/lid.176.ftz`. A host run does not establish
Android inference speed or runtime memory consumption.

## Licenses

Nova-authored build scripts, tests, and documentation: Apache-2.0 (`LICENSE`).
Upstream classifier and headers: MIT (`LICENSE.fastText`). Model: CC BY-SA 3.0
Unported (`LICENSE.model`), with attribution and source links in `NOTICE`.
The Apache license does not replace the upstream code or model licenses.
The builder copies all three licenses and the notice into the prebuilt output.
See https://fasttext.cc/docs/en/language-identification.html.
