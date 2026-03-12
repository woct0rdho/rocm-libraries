#!/bin/bash
set -euo pipefail

# Build hipBLASLt client binaries in a separate tree so the main hipBLASLt build/cache stays untouched.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/projects/hipblaslt"
BUILD_DIR="${BUILD_DIR:-$SCRIPT_DIR/build/hipblaslt-bench}"
TARGET="${TARGET:-hipblaslt-bench}"
GPU_TARGETS="${GPU_TARGETS:-gfx1151}"
BUILD_TYPE="${BUILD_TYPE:-Release}"
if [[ "$TARGET" == "hipblaslt-test" || "$TARGET" == "hipblaslt-test-data" ]]; then
  HIPBLASLT_BUILD_TESTS=ON
else
  HIPBLASLT_BUILD_TESTS="${HIPBLASLT_BUILD_TESTS:-OFF}"
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

if [[ ! -x "$ROCM_PATH/llvm/bin/amdclang" ]]; then
  echo "Missing C compiler: $ROCM_PATH/llvm/bin/amdclang" >&2
  exit 1
fi

if [[ ! -x "$ROCM_PATH/llvm/bin/amdclang++" ]]; then
  echo "Missing C++ compiler: $ROCM_PATH/llvm/bin/amdclang++" >&2
  exit 1
fi

if [[ ! -x "$ROCM_PATH/llvm/bin/flang" ]]; then
  echo "Missing Fortran compiler: $ROCM_PATH/llvm/bin/flang" >&2
  exit 1
fi

echo "Building $TARGET from $SRC_DIR"
echo "Build dir: $BUILD_DIR"
echo "GPU_TARGETS: $GPU_TARGETS"
echo "HIPBLASLT_BUILD_TESTS: $HIPBLASLT_BUILD_TESTS"

cmake -G Ninja -S "$SRC_DIR" -B "$BUILD_DIR" \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_INSTALL_PREFIX="$ROCM_PATH" \
  -DCMAKE_PREFIX_PATH="$ROCM_PATH" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
  -DCMAKE_C_COMPILER="$ROCM_PATH/llvm/bin/amdclang" \
  -DCMAKE_CXX_COMPILER="$ROCM_PATH/llvm/bin/amdclang++" \
  -DCMAKE_ASM_COMPILER="$ROCM_PATH/llvm/bin/amdclang" \
  -DCMAKE_Fortran_COMPILER="$ROCM_PATH/llvm/bin/flang" \
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
  -DHIPBLASLT_ENABLE_HOST=ON \
  -DHIPBLASLT_ENABLE_DEVICE=OFF \
  -DHIPBLASLT_ENABLE_EXTOPS=OFF \
  -DHIPBLASLT_ENABLE_MATRIX_TRANSFORM=OFF \
  -DHIPBLASLT_ENABLE_CLIENT=ON \
  -DHIPBLASLT_ENABLE_MARKER=OFF \
  -DBUILD_TESTING=OFF \
  -DHIPBLASLT_BUILD_TESTING="$HIPBLASLT_BUILD_TESTS" \
  -DHIPBLASLT_ENABLE_SAMPLES=OFF \
  -DHIPBLASLT_ENABLE_AMD_SMI=OFF \
  -DHIPBLASLT_ENABLE_BLIS=OFF \
  -DTENSILELITE_ENABLE_CLIENT=OFF \
  -DTENSILELITE_BUILD_TESTING=OFF
cmake --build "$BUILD_DIR" --target "$TARGET"

BUILT_BINARY="$BUILD_DIR/clients/$TARGET"
echo "Built: $BUILT_BINARY"

# libomp lives under llvm/lib in this SDK; include it at runtime when invoking client binaries.
echo "Runtime hint: export LD_LIBRARY_PATH=$OMP_LIBRARY_DIR:$LLVM_LIB:$ROCM_PATH/lib:\${LD_LIBRARY_PATH:-}"
if [[ -x "$BUILT_BINARY" ]] && command -v ldd >/dev/null 2>&1; then
  ldd "$BUILT_BINARY" | grep -E 'hipblaslt|amdhip|roc|blas|lapack|omp|gtest' || true
fi
