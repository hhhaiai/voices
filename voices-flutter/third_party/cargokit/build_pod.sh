#!/bin/sh
set -e

BASEDIR=$(dirname "$0")

# Workaround for https://github.com/dart-lang/pub/issues/4010
BASEDIR=$(cd "$BASEDIR" ; pwd -P)

# Remove XCode SDK from path. Otherwise this breaks tool compilation when building iOS project
NEW_PATH=`echo $PATH | tr ":" "\n" | grep -v "Contents/Developer/" | tr "\n" ":"`

export PATH=${NEW_PATH%?} # remove trailing :

env

# Platform name (macosx, iphoneos, iphonesimulator)
export CARGOKIT_DARWIN_PLATFORM_NAME=$PLATFORM_NAME

# Arctive architectures (arm64, armv7, x86_64), space separated.
export CARGOKIT_DARWIN_ARCHS=$ARCHS

# Current build configuration (Debug, Release)
export CARGOKIT_CONFIGURATION=$CONFIGURATION

# Path to directory containing Cargo.toml.
export CARGOKIT_MANIFEST_DIR=$PODS_TARGET_SRCROOT/$1

# Temporary directory for build artifacts.
export CARGOKIT_TARGET_TEMP_DIR=$TARGET_TEMP_DIR

# Output directory for final artifacts.
export CARGOKIT_OUTPUT_DIR=$PODS_CONFIGURATION_BUILD_DIR/$PRODUCT_NAME

# Directory to store built tool artifacts.
export CARGOKIT_TOOL_TEMP_DIR=$TARGET_TEMP_DIR/build_tool

# Directory inside root project. Not necessarily the top level directory of root project.
export CARGOKIT_ROOT_PROJECT_DIR=$SRCROOT

FLUTTER_EXPORT_BUILD_ENVIRONMENT=(
  "$PODS_ROOT/../Flutter/ephemeral/flutter_export_environment.sh" # macOS
  "$PODS_ROOT/../Flutter/flutter_export_environment.sh" # iOS
)

for path in "${FLUTTER_EXPORT_BUILD_ENVIRONMENT[@]}"
do
  if [[ -f "$path" ]]; then
    source "$path"
  fi
done

sh "$BASEDIR/run_build_tool.sh" build-pod "$@"

echo "DEBUG: CARGOKIT_DARWIN_PLATFORM_NAME=$CARGOKIT_DARWIN_PLATFORM_NAME"
echo "DEBUG: CARGOKIT_OUTPUT_DIR=$CARGOKIT_OUTPUT_DIR"
echo "DEBUG: CARGOKIT_DARWIN_ARCHS=$CARGOKIT_DARWIN_ARCHS"

# Strip CoreML provider objects from generated staticlibs on Apple targets.
# Keep provider_registration.cc.o to preserve generic provider symbols.
if [[ "$CARGOKIT_DARWIN_PLATFORM_NAME" == iphone* ]] || [[ "$CARGOKIT_DARWIN_PLATFORM_NAME" == macosx ]]; then
  LIB_PATH="${CARGOKIT_OUTPUT_DIR}/lib$2.a"
  if [[ -f "$LIB_PATH" ]]; then
    TMP_DIR=$(mktemp -d)
    THIN_LIBS=()
    COREML_OBJECTS=(
      "coreml_execution_provider.cc.o"
      "coreml_options.cc.o"
      "coreml_provider_factory.cc.o"
      "model.mm.o"
      "provider_registration.cc.o"
    )

    for ARCH in $CARGOKIT_DARWIN_ARCHS
    do
      THIN_LIB="$TMP_DIR/lib_${ARCH}.a"
      lipo "$LIB_PATH" -thin "$ARCH" -output "$THIN_LIB"

      for OBJ in "${COREML_OBJECTS[@]}"
      do
        xcrun ar -d "$THIN_LIB" "$OBJ" >/dev/null 2>&1 || true
      done

      THIN_LIBS+=("$THIN_LIB")
    done

    if [[ ${#THIN_LIBS[@]} -gt 0 ]]; then
      lipo -create "${THIN_LIBS[@]}" -output "$LIB_PATH"
    fi

    rm -rf "$TMP_DIR"
  fi
fi

# Make a symlink from built framework to phony file, which will be used as input to
# build script. This should force rebuild (podspec currently doesn't support alwaysOutOfDate
# attribute on custom build phase)
ln -fs "$OBJROOT/XCBuildData/build.db" "${BUILT_PRODUCTS_DIR}/cargokit_phony"
ln -fs "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_PATH}" "${BUILT_PRODUCTS_DIR}/cargokit_phony_out"
