
#!/usr/bin/env bash
set -euo pipefail

# Fixed locations (adjust if you like)
DEVEL_DIR="$HOME/devel"
SRC_DIR="$DEVEL_DIR/SIRF-SuperBuild"
BUILD_DIR="$DEVEL_DIR/SIRF_builds/conda"

# Get conda prefix more reliably
if [[ -n "${CONDA_PREFIX:-}" ]]; then
    CONDA_ENV_PREFIX="$CONDA_PREFIX"
elif [[ -n "${CONDA_DEFAULT_ENV:-}" ]]; then
    CONDA_ENV_PREFIX="$(conda info --base)/envs/$CONDA_DEFAULT_ENV"
else
    CONDA_ENV_PREFIX="$(conda info --base)/envs/sirf-build"
fi

echo "Configuring SIRF SuperBuild (PET-only) with robust CUDA handling"
echo "Source:  $SRC_DIR"
echo "Build:   $BUILD_DIR"
echo "Install: $BUILD_DIR/INSTALL"
echo "Conda environment: $CONDA_ENV_PREFIX"

# Verify conda environment exists
if [[ ! -d "$CONDA_ENV_PREFIX" ]]; then
    echo "Error: Conda environment not found at $CONDA_ENV_PREFIX"
    exit 1
fi

# Check for pugixml
if [[ ! -f "$CONDA_ENV_PREFIX/include/pugixml.hpp" ]]; then
    echo "Warning: pugixml headers not found"
    echo "Checking pugixml installation..."
    conda list pugixml || echo "pugixml not installed in conda environment"
fi

# CUDA Configuration Strategy
echo ""
echo "=== CUDA Configuration ==="

# Check what CUDA is available
CONDA_CUDA_AVAILABLE=false
SYSTEM_CUDA_AVAILABLE=false

if [[ -f "$CONDA_ENV_PREFIX/bin/nvcc" ]]; then
    CONDA_CUDA_AVAILABLE=true
    CONDA_CUDA_VERSION=$("$CONDA_ENV_PREFIX/bin/nvcc" --version | grep "release" | sed 's/.*release \([0-9.]*\).*/\1/')
    echo "✓ Conda CUDA found: version $CONDA_CUDA_VERSION"
fi

if [[ -f "/usr/local/cuda/bin/nvcc" ]]; then
    SYSTEM_CUDA_AVAILABLE=true
    SYSTEM_CUDA_VERSION=$("/usr/local/cuda/bin/nvcc" --version | grep "release" | sed 's/.*release \([0-9.]*\).*/\1/')
    echo "✓ System CUDA found: version $SYSTEM_CUDA_VERSION"
fi

# Determine CUDA strategy
if [[ "$CONDA_CUDA_AVAILABLE" == "true" ]]; then
    echo "Strategy: Using conda CUDA (recommended)"
    CUDA_STRATEGY="conda"
    CUDA_ROOT="$CONDA_ENV_PREFIX"
    export CUDA_HOME="$CONDA_ENV_PREFIX"
    export PATH="$CONDA_ENV_PREFIX/bin:$PATH"
elif [[ "$SYSTEM_CUDA_AVAILABLE" == "true" ]]; then
    echo "Strategy: Using system CUDA with conda GCC (compatibility mode)"
    CUDA_STRATEGY="system"
    CUDA_ROOT="/usr/local/cuda"
    export CUDA_HOME="/usr/local/cuda"
else
    echo "Error: No CUDA installation found!"
    echo "Please install CUDA either via conda or system package manager"
    exit 1
fi

# Set up compiler compatibility
echo ""
echo "=== Compiler Configuration ==="
CONDA_GCC="$CONDA_ENV_PREFIX/bin/x86_64-conda-linux-gnu-gcc"
CONDA_GXX="$CONDA_ENV_PREFIX/bin/x86_64-conda-linux-gnu-g++"

if [[ -f "$CONDA_GCC" ]]; then
    GCC_VERSION=$("$CONDA_GCC" --version | head -n1 | grep -o '[0-9]\+\.[0-9]\+' | head -n1)
    echo "✓ Conda GCC version: $GCC_VERSION"
    
    # Check GCC compatibility with CUDA
    GCC_MAJOR=$(echo "$GCC_VERSION" | cut -d. -f1)
    if [[ "$GCC_MAJOR" -le 12 ]]; then
        echo "✓ GCC version is CUDA-compatible"
        USE_UNSUPPORTED_COMPILER=false
    else
        echo "⚠ GCC version may need compatibility flag"
        USE_UNSUPPORTED_COMPILER=true
    fi
else
    echo "Warning: Conda GCC not found, using system GCC"
    USE_UNSUPPORTED_COMPILER=true
fi

# Build CMake command
echo ""
echo "=== Building CMake Configuration ==="

CMAKE_ARGS=(
    -S "$SRC_DIR" 
    -B "$BUILD_DIR"
    -DDEVEL_BUILD=ON
    -DCMAKE_INSTALL_PREFIX="$BUILD_DIR/INSTALL"
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_PREFIX_PATH="$CONDA_ENV_PREFIX;$CONDA_ENV_PREFIX/lib"
    -DCMAKE_INCLUDE_PATH="$CONDA_ENV_PREFIX/include"
    -DCMAKE_LIBRARY_PATH="$CONDA_ENV_PREFIX/lib"
    -DPYTHON_EXECUTABLE="$CONDA_ENV_PREFIX/bin/python"
)

# Add CUDA-specific flags
if [[ "$USE_UNSUPPORTED_COMPILER" == "true" ]]; then
    CMAKE_ARGS+=(-DCMAKE_CUDA_FLAGS="-allow-unsupported-compiler")
    echo "Adding CUDA compatibility flag"
fi

if [[ -f "$CONDA_GCC" ]]; then
    CMAKE_ARGS+=(-DCMAKE_CUDA_HOST_COMPILER="$CONDA_GCC")
    echo "Using conda GCC as CUDA host compiler"
fi

if [[ "$CUDA_STRATEGY" == "conda" ]]; then
    CMAKE_ARGS+=(-DCUDA_TOOLKIT_ROOT_DIR="$CONDA_ENV_PREFIX")
    echo "Pointing CMake to conda CUDA toolkit"
else
    CMAKE_ARGS+=(-DCUDA_TOOLKIT_ROOT_DIR="$CUDA_ROOT")
    echo "Using system CUDA toolkit"
fi

# Add other configuration
CMAKE_ARGS+=(
    -DUSE_SYSTEM_Boost=ON
    -DUSE_SYSTEM_HDF5=OFF
    -DUSE_SYSTEM_FFTW3=ON
    -DUSE_SYSTEM_SWIG=ON
    -DUSE_SYSTEM_Armadillo=ON
    -DUSE_SYSTEM_parallelproj=ON
    -DUSE_SYSTEM_EIGEN3=ON
    -DUSE_SYSTEM_pugixml=ON
    -DUSE_ITK=ON
    -DUSE_SYSTEM_ITK=ON
    -DBUILD_Gadgetron=OFF
    -DBUILD_siemens_to_ismrmrd=OFF
    -DBUILD_TESTING=ON
    -DBUILD_STIR_TESTING=ON
    -DBUILD_SIRF_TESTING=ON
    -DSTIR_BUILD_SWIG_PYTHON=ON
    -DSTIR_ENABLE_OPENMP=ON
    -DBUILD_CIL=ON
    -DSIRF_TAG="origin/master"
    -DSTIR_URL="https://github.com/samdporter/STIR"
    -DSTIR_TAG="origin/SPECT_subsets"
    -DCIL_TAG="origin/master"
    -DUSE_ROOT=OFF
)

echo ""
echo "=== Executing CMake Configuration ==="
echo "Command: cmake ${CMAKE_ARGS[*]}"
echo ""

# Execute cmake
if cmake "${CMAKE_ARGS[@]}"; then
    echo ""
    echo "=== Configure Complete! ==="
    echo "CUDA Strategy: $CUDA_STRATEGY"
    if [[ "$CUDA_STRATEGY" == "conda" ]]; then
        echo "CUDA Root: $CONDA_ENV_PREFIX"
    else
        echo "CUDA Root: $CUDA_ROOT (system)"
        echo "GCC: $CONDA_GCC (conda)"
    fi
    echo ""
    echo "Next step: ./4_build.sh"
else
    echo ""
    echo "=== Configuration Failed! ==="
    echo "Check the error messages above"
    echo "Common issues:"
    echo "1. Missing packages in conda environment"
    echo "2. CUDA/GCC compatibility problems"
    echo "3. Missing development headers"
    exit 1
fi