#!/usr/bin/env bash
set -euo pipefail

# Fixed locations (adjust if you like)
DEVEL_DIR="$HOME/devel"
SRC_DIR="$DEVEL_DIR/SIRF-SuperBuild"
BUILD_DIR="$DEVEL_DIR/SIRF_builds/conda"
CONDA_PREFIX="$(conda info --base)/envs/sirf-build"

echo "Configuring SIRF SuperBuild (PET-only)"
echo "Source:  $SRC_DIR"
echo "Build:   $BUILD_DIR"
echo "Install: $BUILD_DIR/INSTALL"

cmake -S "$SRC_DIR" -B "$BUILD_DIR" \
  -DDEVEL_BUILD=ON \
  -DCMAKE_INSTALL_PREFIX="$BUILD_DIR/INSTALL" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="$CONDA_PREFIX" \
  -DPYTHON_EXECUTABLE="$CONDA_PREFIX/bin/python" \
  \
  -DUSE_SYSTEM_Boost=ON \
  -DUSE_SYSTEM_HDF5=OFF \
  -DUSE_SYSTEM_FFTW3=ON \
  -DUSE_SYSTEM_SWIG=ON \
  -DUSE_SYSTEM_Armadillo=ON \
  -DUSE_SYSTEM_parallelproj=ON \
  -DUSE_SYSTEM_EIGEN3=ON \
  \
  -DUSE_ITK=ON \
  -DUSE_SYSTEM_ITK=ON \
  \
  -DBUILD_GADGETRON=OFF \
  -DBUILD_siemens_to_ismrmrd=OFF \
  -DBUILD_TESTING=ON \
  \
  -DSTIR_BUILD_SWIG_PYTHON=ON \
  -DSTIR_ENABLE_OPENMP=ON \
  \
  -DBUILD_CIL=ON \
  \
  -DSIRF_TAG="origin/master" \
  -DSTIR_URL="https://github.com/samdporter/STIR" \
  -DSTIR_TAG="origin/SPECT_subsets" \
  -DCIL_TAG="origin/master" \
  \
  -DUSE_ROOT=OFF

echo "=== Configure complete. Next: ./4_build.sh ==="
