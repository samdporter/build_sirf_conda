#!/usr/bin/env bash
set -euo pipefail
BUILD_DIR="$HOME/devel/SIRF_builds/conda"
cmake --build "$BUILD_DIR" --parallel "$(nproc)"
echo "=== Build complete. Next: source $BUILD_DIR/INSTALL/bin/env_sirf.sh ==="
