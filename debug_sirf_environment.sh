#!/bin/bash

# SIRF Environment Debug Script
# Run this to diagnose environment issues

echo "=== SIRF Environment Diagnostics ==="
echo ""

# Check conda environment
echo "1. Conda Environment Status:"
echo "Current environment: $CONDA_DEFAULT_ENV"
if [ -z "$CONDA_DEFAULT_ENV" ]; then
    echo "WARNING: No conda environment activated!"
    echo "Run: conda activate sirf-build"
fi
echo "Conda prefix: $CONDA_PREFIX"
echo ""

# Check PATH
echo "2. PATH Analysis:"
echo "PATH: $PATH"
echo ""
IFS=':' read -ra PATH_ARRAY <<< "$PATH"
echo "PATH components containing 'local' (potential conflicts):"
for path in "${PATH_ARRAY[@]}"; do
    if [[ "$path" == *"local"* ]]; then
        echo "  - $path"
    fi
done
echo ""

# Check key executables
echo "3. Key Executable Locations:"
executables=("python" "cmake" "gcc" "g++" "gfortran" "pkg-config")
for exe in "${executables[@]}"; do
    location=$(which $exe 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "  $exe: $location"
        if [[ "$location" == *"conda"* ]] || [[ "$location" == *"miniforge"* ]]; then
            echo "    ✓ Using conda version"
        else
            echo "    ⚠ Using system version (potential conflict)"
        fi
    else
        echo "  $exe: NOT FOUND"
    fi
done
echo ""

# Check Python packages
echo "4. Python Package Analysis:"
if command -v python >/dev/null 2>&1; then
    echo "Python location: $(which python)"
    echo "Python version: $(python --version)"
    echo "Python prefix: $(python -c 'import sys; print(sys.prefix)')"
    
    echo ""
    echo "Key Python packages:"
    packages=("numpy" "scipy" "matplotlib" "h5py" "nibabel")
    for pkg in "${packages[@]}"; do
        python -c "import $pkg; print('  $pkg: ' + $pkg.__version__ + ' (' + $pkg.__file__ + ')')" 2>/dev/null || echo "  $pkg: NOT FOUND"
    done
else
    echo "Python not found!"
fi
echo ""

# Check library paths
echo "5. Library Path Analysis:"
echo "LD_LIBRARY_PATH: ${LD_LIBRARY_PATH:-<not set>}"
echo "PKG_CONFIG_PATH: ${PKG_CONFIG_PATH:-<not set>}"
echo "CMAKE_PREFIX_PATH: ${CMAKE_PREFIX_PATH:-<not set>}"
echo ""

# Check for SIRF-specific environment variables
echo "6. SIRF Environment Variables:"
sirf_vars=("SIRF_PATH" "SIRF_PYTHON_EXECUTABLE" "PYTHONPATH")
for var in "${sirf_vars[@]}"; do
    value=${!var}
    if [ -n "$value" ]; then
        echo "  $var: $value"
        if [[ "$value" == *"local"* ]]; then
            echo "    ⚠ Contains local path (may cause conflicts)"
        fi
    else
        echo "  $var: <not set>"
    fi
done
echo ""

# Check for existing SIRF installations
echo "7. Existing SIRF Installation Check:"
sirf_locations=("/usr/local" "$HOME/local" "$HOME/.local")
for loc in "${sirf_locations[@]}"; do
    if [ -d "$loc/bin" ] && [ -n "$(find $loc -name "*sirf*" -type f 2>/dev/null)" ]; then
        echo "  Found SIRF files in: $loc"
        echo "    ⚠ This may interfere with your new conda build"
    fi
done
echo ""

# Check conda package versions
echo "8. Conda Package Versions:"
if command -v conda >/dev/null 2>&1; then
    key_packages=("boost" "hdf5" "fftw" "cmake" "swig" "armadillo")
    for pkg in "${key_packages[@]}"; do
        version=$(conda list $pkg 2>/dev/null | grep "^$pkg " | awk '{print $2}' | head -n1)
        if [ -n "$version" ]; then
            echo "  $pkg: $version"
        else
            echo "  $pkg: NOT INSTALLED"
        fi
    done
else
    echo "Conda not available!"
fi
echo ""

# Suggestions
echo "9. Recommendations:"
if [[ "$PATH" == *"/usr/local/bin"* ]] && [[ "$PATH" != "$CONDA_PREFIX/bin"* ]]; then
    echo "  ⚠ Consider updating your PATH to prioritize conda"
fi

if [ -n "$(find /usr/local -name "*sirf*" -type f 2>/dev/null)" ]; then
    echo "  ⚠ Consider backing up and removing old SIRF installations from /usr/local"
fi

if [ -z "$CONDA_DEFAULT_ENV" ]; then
    echo "  → Activate conda environment: conda activate sirf-build"
fi

echo ""
echo "=== Diagnostics Complete ==="
