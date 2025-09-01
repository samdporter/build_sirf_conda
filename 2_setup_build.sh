#!/bin/bash

# SIRF Build Setup Script (Part 2)
# Run this after creating the conda environment

set -euo pipefail  # Exit on any error, treat unset variables as error

echo "=== Setting Up SIRF Build Infrastructure ==="

# Configuration
ENV_NAME="sirf-build"
DEVEL_DIR="$HOME/devel"
BUILD_DIR="$DEVEL_DIR/SIRF_builds/conda"
INSTALL_DIR="$BUILD_DIR/INSTALL"

# Check if conda environment is activated
if [[ -z "${CONDA_DEFAULT_ENV:-}" ]]; then
    echo "Warning: No conda environment appears to be active."
    echo "Please activate the environment first:"
    echo "  conda activate $ENV_NAME"
    echo ""
    echo "Or if using mamba:"
    echo "  mamba activate $ENV_NAME"
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
elif [[ "$CONDA_DEFAULT_ENV" != "$ENV_NAME" ]]; then
    echo "Warning: Expected environment '$ENV_NAME', but '$CONDA_DEFAULT_ENV' is active."
    read -p "Continue with current environment? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Please activate the correct environment:"
        echo "  conda activate $ENV_NAME"
        exit 1
    fi
fi

# Detect conda installation
CONDA_PATH=""
CONDA_PATHS=("$HOME/miniforge3" "$HOME/miniconda3" "$HOME/anaconda3" "/opt/conda")
for path in "${CONDA_PATHS[@]}"; do
    if [[ -d "$path" ]]; then
        CONDA_PATH="$path"
        echo "Found conda installation at: $CONDA_PATH"
        break
    fi
done

if [[ -z "$CONDA_PATH" ]]; then
    echo "Warning: Could not find conda installation directory"
    echo "This might cause issues with the activation script"
    # Try to get conda path from conda info
    if command -v conda >/dev/null 2>&1; then
        CONDA_PATH="$(conda info --base 2>/dev/null || echo "")"
        if [[ -n "$CONDA_PATH" ]]; then
            echo "Using conda base from 'conda info': $CONDA_PATH"
        fi
    fi
fi

# Verify environment exists using conda command
echo "Verifying environment '$ENV_NAME' exists..."
if ! conda env list 2>/dev/null | grep -qw "$ENV_NAME"; then
    echo "Error: Environment '$ENV_NAME' not found!"
    echo "Available environments:"
    conda env list 2>/dev/null || echo "Could not list environments"
    echo ""
    echo "Please run ./1_create_environment.sh first"
    exit 1
fi

echo "Environment '$ENV_NAME' found ✓"

# Create build directories
echo "Creating build directories..."
mkdir -p "$BUILD_DIR"
mkdir -p "$INSTALL_DIR"
echo "Build directory: $BUILD_DIR"
echo "Install directory: $INSTALL_DIR"

# Clone/update SIRF-SuperBuild
echo "Setting up SIRF-SuperBuild..."
if [[ ! -d "$DEVEL_DIR/SIRF-SuperBuild" ]]; then
    echo "Cloning SIRF-SuperBuild..."
    mkdir -p "$DEVEL_DIR"
    git clone https://github.com/SyneRBI/SIRF-SuperBuild.git "$DEVEL_DIR/SIRF-SuperBuild"
    echo "SIRF-SuperBuild cloned ✓"
else
    echo "SIRF-SuperBuild already exists, updating..."
    if git -C "$DEVEL_DIR/SIRF-SuperBuild" pull; then
        echo "SIRF-SuperBuild updated ✓"
    else
        echo "Warning: Could not update SIRF-SuperBuild (continuing anyway)"
    fi
fi

# Create improved activation script
echo "Creating activation script..."
cat > "$DEVEL_DIR/activate_sirf.sh" << EOF
#!/bin/bash
# SIRF Environment Activation Script
# This script activates the conda environment and sets up paths

# Function to find conda installation
find_conda() {
    local conda_paths=("$HOME/miniforge3" "$HOME/miniconda3" "$HOME/anaconda3" "/opt/conda")
    for path in "\${conda_paths[@]}"; do
        if [[ -f "\$path/etc/profile.d/conda.sh" ]]; then
            echo "\$path"
            return 0
        fi
    done
    
    # Fallback: try conda info
    if command -v conda >/dev/null 2>&1; then
        conda info --base 2>/dev/null
    fi
}

# Initialize conda
CONDA_BASE=\$(find_conda)
if [[ -n "\$CONDA_BASE" ]] && [[ -f "\$CONDA_BASE/etc/profile.d/conda.sh" ]]; then
    source "\$CONDA_BASE/etc/profile.d/conda.sh"
    echo "Conda initialized from: \$CONDA_BASE"
else
    echo "Warning: Could not find conda installation"
    echo "Trying to activate environment anyway..."
fi

# Activate environment
if conda activate $ENV_NAME 2>/dev/null; then
    echo "Environment '$ENV_NAME' activated ✓"
else
    echo "Error: Could not activate environment '$ENV_NAME'"
    echo "Make sure it exists: conda env list"
    return 1
fi

# Set environment variables
export SIRF_BUILD_DIR="$BUILD_DIR"
export SIRF_INSTALL_DIR="$INSTALL_DIR"

# Update CMAKE_PREFIX_PATH to include conda environment
if [[ -n "\${CONDA_PREFIX:-}" ]]; then
    export CMAKE_PREFIX_PATH="\$CONDA_PREFIX:\${CMAKE_PREFIX_PATH:-}"
    export PATH="\$CONDA_PREFIX/bin:\$PATH"
fi

# Display status
echo "SIRF development environment ready!"
echo "  Environment: \$CONDA_DEFAULT_ENV"
echo "  Build dir: \$SIRF_BUILD_DIR"
echo "  Install dir: \$SIRF_INSTALL_DIR"
echo ""
echo "Next steps:"
echo "  ./3_configure_sirf.sh  # Configure the build"
echo "  ./4_build.sh           # Build SIRF"
EOF

chmod +x "$DEVEL_DIR/activate_sirf.sh"

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Build infrastructure has been set up in: $DEVEL_DIR"
echo ""
echo "Next steps:"
echo "1. Activate the SIRF environment:"
echo "   source $DEVEL_DIR/activate_sirf.sh"
echo ""
echo "2. Configure SIRF:"
echo "   ./3_configure_sirf.sh"
echo ""
echo "3. Build SIRF:"
echo "   ./4_build.sh"
echo ""