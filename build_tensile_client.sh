#!/usr/bin/env bash
set -euo pipefail

: "${ROCM_PATH:?ROCM_PATH must be set}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/shared/tensile/next-cmake"
BUILD_DIR="$SCRIPT_DIR/build/tensile-client"
PYTHON_EXE="${PYTHON_EXE:-$HOME/venv_torch/bin/python}"
GPU_TARGETS="${GPU_TARGETS:-gfx1151}"
BUILD_TYPE="${BUILD_TYPE:-Release}"

LLVM_BIN="$ROCM_PATH/lib/llvm/bin"
if [[ ! -x "$LLVM_BIN/amdclang" || ! -x "$LLVM_BIN/amdclang++" ]]; then
  LLVM_BIN="$ROCM_PATH/llvm/bin"
fi

if [[ ! -d "$SRC_DIR" ]]; then
  echo "Full Tensile CMake source dir not found: $SRC_DIR" >&2
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

if [[ ! -f "$ROCM_PATH/lib/cmake/rocm_smi/rocm_smi-config.cmake" ]]; then
  echo "rocm_smi CMake config not found under $ROCM_PATH/lib/cmake/rocm_smi" >&2
  exit 1
fi

echo "Building full Tensile client from $SRC_DIR"
echo "Build dir: $BUILD_DIR"
echo "ROCm path: $ROCM_PATH"
echo "GPU_TARGETS: $GPU_TARGETS"

cmake -G Ninja -S "$SRC_DIR" -B "$BUILD_DIR" \
  -DCMAKE_INSTALL_PREFIX="$BUILD_DIR/install" \
  -DCMAKE_PREFIX_PATH="$ROCM_PATH" \
  -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
  -DCMAKE_C_COMPILER="$LLVM_BIN/amdclang" \
  -DCMAKE_CXX_COMPILER="$LLVM_BIN/amdclang++" \
  -DCMAKE_ASM_COMPILER="$LLVM_BIN/amdclang" \
  -DCMAKE_C_COMPILER_LAUNCHER=ccache \
  -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
  -DCMAKE_EXE_LINKER_FLAGS="-L$ROCM_PATH/lib/llvm/lib" \
  -DCMAKE_SHARED_LINKER_FLAGS="-L$ROCM_PATH/lib/llvm/lib" \
  -DCMAKE_BUILD_RPATH="$ROCM_PATH/lib;$ROCM_PATH/lib/llvm/lib" \
  -DGPU_TARGETS="$GPU_TARGETS" \
  -DTENSILE_ENABLE_HOST=ON \
  -DTENSILE_ENABLE_CLIENT=ON \
  -DTENSILE_ENABLE_DEVICE=OFF \
  -DTENSILE_ENABLE_MSGPACK=ON \
  -DTENSILE_ENABLE_LLVM=OFF \
  -DTENSILE_ENABLE_ROCM_SMI=ON \
  -Drocm_smi_DIR="$ROCM_PATH/lib/cmake/rocm_smi" \
  -DTENSILE_BUILD_TESTING=OFF \
  -DPython3_EXECUTABLE="$PYTHON_EXE"

cmake --build "$BUILD_DIR" --target tensile-client

CLIENT="$BUILD_DIR/tensile-client"
if [[ ! -x "$CLIENT" ]]; then
  echo "Expected client binary was not produced: $CLIENT" >&2
  exit 1
fi

echo "Full Tensile client build complete: $CLIENT"
