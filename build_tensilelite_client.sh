#!/usr/bin/env bash
set -euo pipefail

: "${ROCM_PATH:?ROCM_PATH must be set}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/projects/hipblaslt"
BUILD_DIR="$SCRIPT_DIR/build/tensilelite-client"
PYTHON_EXE="${PYTHON_EXE:-$HOME/venv_torch/bin/python}"
GPU_TARGETS="${GPU_TARGETS:-gfx1151}"
BUILD_TYPE="${BUILD_TYPE:-Release}"

LLVM_BIN="$ROCM_PATH/lib/llvm/bin"
if [[ ! -x "$LLVM_BIN/amdclang" || ! -x "$LLVM_BIN/amdclang++" ]]; then
  LLVM_BIN="$ROCM_PATH/llvm/bin"
fi

LLVM_LIB="$ROCM_PATH/lib/llvm/lib"
if [[ ! -d "$LLVM_LIB" ]]; then
  LLVM_LIB="$ROCM_PATH/llvm/lib"
fi
OMP_LIBRARY="$(find "$LLVM_LIB" -name libomp.so -type f -print -quit)"
if [[ -z "$OMP_LIBRARY" ]]; then
  echo "libomp.so not found below $LLVM_LIB" >&2
  exit 1
fi
OMP_LIBRARY_DIR="$(dirname "$OMP_LIBRARY")"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "hipBLASLt source dir not found: $SRC_DIR" >&2
  exit 1
fi

if [[ ! -x "$LLVM_BIN/amdclang" || ! -x "$LLVM_BIN/amdclang++" ]]; then
  echo "amdclang/amdclang++ not found under $ROCM_PATH/lib/llvm/bin or $ROCM_PATH/llvm/bin" >&2
  exit 1
fi

if [[ ! -x "$PYTHON_EXE" ]]; then
  echo "Python executable not found: $PYTHON_EXE" >&2
  exit 1
fi

if [[ ! -f "$ROCM_PATH/share/rocmcmakebuildtools/cmake/ROCmCMakeBuildToolsConfig.cmake" ]]; then
  echo "ROCmCMakeBuildTools not found under $ROCM_PATH/share/rocmcmakebuildtools/cmake" >&2
  exit 1
fi

echo "Building TensileLite client from $SRC_DIR"
echo "Build dir: $BUILD_DIR"
echo "ROCm path: $ROCM_PATH"
echo "GPU_TARGETS: $GPU_TARGETS"

cmake -G Ninja -S "$SRC_DIR" -B "$BUILD_DIR" \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_INSTALL_PREFIX="$BUILD_DIR/install" \
  -DCMAKE_PREFIX_PATH="$ROCM_PATH" \
  -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
  -DCMAKE_C_COMPILER="$LLVM_BIN/amdclang" \
  -DCMAKE_CXX_COMPILER="$LLVM_BIN/amdclang++" \
  -DCMAKE_ASM_COMPILER="$LLVM_BIN/amdclang" \
  -DCMAKE_C_COMPILER_LAUNCHER=ccache \
  -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
  -DCMAKE_EXE_LINKER_FLAGS="-L$LLVM_LIB -L$OMP_LIBRARY_DIR" \
  -DCMAKE_SHARED_LINKER_FLAGS="-L$LLVM_LIB -L$OMP_LIBRARY_DIR" \
  -DCMAKE_BUILD_RPATH="$ROCM_PATH/lib;$LLVM_LIB;$OMP_LIBRARY_DIR" \
  -DOpenMP_omp_LIBRARY="$OMP_LIBRARY" \
  -DGPU_TARGETS="$GPU_TARGETS" \
  -DROCmCMakeBuildTools_DIR="$ROCM_PATH/share/rocmcmakebuildtools/cmake" \
  -DROCM_DISABLE_LDCONFIG=ON \
  -DHIPBLASLT_ENABLE_FETCH=ON \
  -DHIPBLASLT_ENABLE_HOST=OFF \
  -DHIPBLASLT_ENABLE_DEVICE=OFF \
  -DHIPBLASLT_ENABLE_EXTOPS=OFF \
  -DHIPBLASLT_ENABLE_MATRIX_TRANSFORM=OFF \
  -DHIPBLASLT_ENABLE_CLIENT=OFF \
  -DBUILD_TESTING=OFF \
  -DHIPBLASLT_BUILD_TESTING=OFF \
  -DHIPBLASLT_ENABLE_SAMPLES=OFF \
  -DHIPBLASLT_ENABLE_YAML=ON \
  -DHIPBLASLT_ENABLE_OPENMP=ON \
  -DHIPBLASLT_ENABLE_MXDATAGENERATOR=ON \
  -DHIPBLASLT_BUNDLE_PYTHON_DEPS=OFF \
  -DTENSILELITE_ENABLE_HOST=ON \
  -DTENSILELITE_ENABLE_CLIENT=ON \
  -DTENSILELITE_CLIENT_ENABLE_ROCPROFSDK=OFF \
  -DTENSILELITE_BUILD_TESTING=OFF \
  -DPython_EXECUTABLE="$PYTHON_EXE"

cmake --build "$BUILD_DIR" --target tensilelite-client

CLIENT="$BUILD_DIR/tensilelite/client/tensilelite-client"
if [[ ! -x "$CLIENT" ]]; then
  echo "Expected client binary was not produced: $CLIENT" >&2
  exit 1
fi

echo "TensileLite client build complete: $CLIENT"
