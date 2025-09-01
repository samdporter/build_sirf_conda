#!/bin/bash

# SIRF Build Setup Script (Part 2)
# Run this after creating the conda environment

set -e  # Exit on any error

echo "=== Setting Up SIRF Build Infrastructure ==="

# Configuration
ENV_NAME="sirf-build"
DEVEL_DIR="$HOME/devel"
BUILD_DIR="$DEVEL_DIR/SIRF_builds/conda"
INSTALL_DIR="$BUILD_DIR/INSTALL"

# Detect conda installation
if [ -d "$HOME/miniforge3" ]; then
    CONDA_PATH="$HOME/miniforge3"
elif [ -d "$HOME/miniconda3" ]; then
    CONDA_PATH="$HOME/miniconda3"
else
    echo "Error: Could not find conda installation"
    exit 1
fi

# Verify environment exists
echo "Checking if environment exists..."
if ! conda env list | grep -q "sirf-build"; then
    echo "Error: Environment 'sirf-build' not found!"
    echo "Run ./1_create_environment.sh first"
    exit 1
fi

echo "Environment 'sirf-build' found. Proceeding with build setup..."

# Create build directories (no cd)
mkdir -p "$BUILD_DIR"

# Clone/update SIRF-SuperBuild without leaving this directory
if [ ! -d "$DEVEL_DIR/SIRF-SuperBuild" ]; then
  echo "Cloning SIRF-SuperBuild..."
  git clone https://github.com/SyneRBI/SIRF-SuperBuild.git "$DEVEL_DIR/SIRF-SuperBuild"
else
  echo "SIRF-SuperBuild already exists, updating..."
  git -C "$DEVEL_DIR/SIRF-SuperBuild" pull
fi

# Activation script: do NOT cd into build dir
cat > "$DEVEL_DIR/activate_sirf.sh" << 'EOF'
#!/bin/bash
# Activate conda env only; do not change directory
if [ -d "$HOME/miniforge3" ]; then
  source "$HOME/miniforge3/etc/profile.d/conda.sh"
elif [ -d "$HOME/miniconda3" ]; then
  source "$HOME/miniconda3/etc/profile.d/conda.sh"
fi
conda activate sirf-build
export SIRF_BUILD_DIR="$HOME/devel/SIRF_builds/conda"
export CMAKE_PREFIX_PATH="$CONDA_PREFIX:$CMAKE_PREFIX_PATH"
export PATH="$CONDA_PREFIX/bin:$PATH"
echo "SIRF env active. Build dir: \$SIRF_BUILD_DIR"
EOF
chmod +x "$DEVEL_DIR/activate_sirf.sh"