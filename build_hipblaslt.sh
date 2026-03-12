#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/projects/hipblaslt"
BUILD_DIR="${BUILD_DIR:-$SCRIPT_DIR/build/hipblaslt}"
INSTALL_DIR="${ROCM_PATH:?ROCM_PATH must be set}"
GPU_TARGETS="${GPU_TARGETS:-gfx1151}"
BUILD_TYPE="${BUILD_TYPE:-Release}"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "hipBLASLt source dir not found: $SRC_DIR" >&2
  exit 1
fi

if [[ ! -x "$ROCM_PATH/llvm/bin/amdclang" ]]; then
  echo "Missing C compiler: $ROCM_PATH/llvm/bin/amdclang" >&2
  exit 1
fi

if [[ ! -x "$ROCM_PATH/llvm/bin/amdclang++" ]]; then
  echo "Missing C++ compiler: $ROCM_PATH/llvm/bin/amdclang++" >&2
  exit 1
fi

if [[ ! -f "$INSTALL_DIR/share/rocmcmakebuildtools/cmake/ROCmCMakeBuildToolsConfig.cmake" ]]; then
  echo "ROCmCMakeBuildTools not found under $INSTALL_DIR/share/rocmcmakebuildtools/cmake" >&2
  exit 1
fi

echo "Building hipBLASLt from $SRC_DIR"
echo "Build dir: $BUILD_DIR"
echo "Install dir: $INSTALL_DIR"
echo "GPU_TARGETS: $GPU_TARGETS"

cmake -G Ninja -S "$SRC_DIR" -B "$BUILD_DIR" \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
  -DCMAKE_PREFIX_PATH="$INSTALL_DIR" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
  -DCMAKE_C_COMPILER="$ROCM_PATH/llvm/bin/amdclang" \
  -DCMAKE_CXX_COMPILER="$ROCM_PATH/llvm/bin/amdclang++" \
  -DCMAKE_C_COMPILER_LAUNCHER=ccache \
  -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
  -DCMAKE_EXE_LINKER_FLAGS="-L$ROCM_PATH/llvm/lib" \
  -DCMAKE_SHARED_LINKER_FLAGS="-L$ROCM_PATH/llvm/lib" \
  -DGPU_TARGETS="$GPU_TARGETS" \
  -DROCmCMakeBuildTools_DIR="$INSTALL_DIR/share/rocmcmakebuildtools/cmake" \
  -DROCM_DISABLE_LDCONFIG=ON \
  -DHIPBLASLT_ENABLE_FETCH=ON \
  -DHIPBLASLT_ENABLE_HOST=ON \
  -DHIPBLASLT_ENABLE_DEVICE=ON \
  -DHIPBLASLT_ENABLE_CLIENT=OFF \
  -DBUILD_TESTING=OFF \
  -DHIPBLASLT_BUILD_TESTING=OFF \
  -DHIPBLASLT_ENABLE_SAMPLES=OFF \
  -DTENSILELITE_ENABLE_CLIENT=OFF \
  -DTENSILELITE_BUILD_TESTING=OFF
cmake --build "$BUILD_DIR"
cmake --install "$BUILD_DIR"

"$SCRIPT_DIR/sync_rocm_sdk_links.py" libraries "$INSTALL_DIR" \
  libhipblaslt.so \
  librocroller.so \
  hipblaslt/library

echo "hipBLASLt build complete. Artifacts installed in $INSTALL_DIR"
