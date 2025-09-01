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

# Create build directories
echo "Creating build directories..."
mkdir -p "$BUILD_DIR"
cd "$DEVEL_DIR"

# Clone SIRF-SuperBuild if not present
if [ ! -d "SIRF-SuperBuild" ]; then
    echo "Cloning SIRF-SuperBuild..."
    git clone https://github.com/SyneRBI/SIRF-SuperBuild.git
else
    echo "SIRF-SuperBuild already exists, updating..."
    cd SIRF-SuperBuild
    git pull
    cd ..
fi

# Create activation script for future use
echo "Creating environment activation script..."
cat > "$DEVEL_DIR/activate_sirf.sh" << EOF
#!/bin/bash

# SIRF Conda Environment Activation Script
# Source this script to activate the SIRF conda environment

# Initialize conda/mamba
source "$CONDA_PATH/etc/profile.d/conda.sh"

# Initialize mamba if available
if command -v mamba >/dev/null 2>&1; then
    eval "\$(mamba shell hook --shell bash)"
    echo "Using mamba for environment management"
fi

# Activate environment
conda activate $ENV_NAME

# Set environment variables
export SIRF_BUILD_DIR="$BUILD_DIR"
export CMAKE_PREFIX_PATH="\$CONDA_PREFIX:\$CMAKE_PREFIX_PATH"

# Add conda bin to PATH (should happen automatically, but just in case)
export PATH="\$CONDA_PREFIX/bin:\$PATH"

echo "SIRF conda environment activated!"
echo "Build directory: \$SIRF_BUILD_DIR"
echo "Python: \$(which python)"
echo "CMake: \$(which cmake)"

# Change to build directory
cd "\$SIRF_BUILD_DIR"

EOF

chmod +x "$DEVEL_DIR/activate_sirf.sh"

echo ""
echo "=== Build Infrastructure Setup Complete! ==="
echo ""
echo "Created:"
echo "  - Build directory: $BUILD_DIR"
echo "  - Activation script: $DEVEL_DIR/activate_sirf.sh"
echo "  - SIRF-SuperBuild source: $DEVEL_DIR/SIRF-SuperBuild"
echo ""
echo "Next steps:"
echo "1. Create configure_sirf.sh in $BUILD_DIR"
echo "2. Activate environment: source $DEVEL_DIR/activate_sirf.sh"
echo "3. Configure: cd $BUILD_DIR && ./configure_sirf.sh"
echo "4. Build: cmake --build . --parallel \$(nproc)"
