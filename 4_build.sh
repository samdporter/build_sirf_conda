#!/usr/bin/env bash
set -euo pipefail

# Default settings
BUILD_DIR="$HOME/devel/SIRF_builds/conda"
PARALLEL_JOBS="$(nproc)"
BUILD_TYPE=""
VERBOSE=false

# Function to show usage
show_help() {
    echo "SIRF Build Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --debug        Single-core build with verbose output (good for debugging)"
    echo "  -j NUM         Use NUM parallel jobs (default: $(nproc))"
    echo "  -j1            Single-core build (same as -j 1)"
    echo "  --verbose      Show detailed build output"
    echo "  --release      Force release build (default: uses configured type)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Normal parallel build"
    echo "  $0 --debug           # Debug build (single core, verbose)"
    echo "  $0 -j4               # Build with 4 cores"
    echo "  $0 --verbose -j2     # Verbose build with 2 cores"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --debug)
            PARALLEL_JOBS=1
            VERBOSE=true
            BUILD_TYPE="Debug"
            echo "Debug mode: single-core build with verbose output"
            ;;
        -j*)
            if [[ "$1" == "-j" ]]; then
                shift
                if [[ $# -gt 0 ]] && [[ "$1" =~ ^[0-9]+$ ]]; then
                    PARALLEL_JOBS="$1"
                else
                    echo "Error: -j requires a number" >&2
                    exit 1
                fi
            elif [[ "$1" =~ ^-j[0-9]+$ ]]; then
                PARALLEL_JOBS="${1#-j}"
            else
                echo "Error: Invalid -j option: $1" >&2
                exit 1
            fi
            echo "Using $PARALLEL_JOBS parallel jobs"
            ;;
        --verbose)
            VERBOSE=true
            echo "Verbose output enabled"
            ;;
        --release)
            BUILD_TYPE="Release"
            echo "Force release build"
            ;;
        *)
            echo "Error: Unknown option $1" >&2
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
    shift
done

# Validate build directory exists
if [[ ! -d "$BUILD_DIR" ]]; then
    echo "Error: Build directory not found: $BUILD_DIR" >&2
    echo "Run ./3_configure_sirf.sh first" >&2
    exit 1
fi

# Check if we're in a conda environment
if [[ -z "${CONDA_DEFAULT_ENV:-}" ]]; then
    echo "Warning: No conda environment appears to be active"
    echo "Consider running: source ~/devel/activate_sirf.sh"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "=== Starting SIRF Build ==="
echo "Build directory: $BUILD_DIR"
echo "Parallel jobs: $PARALLEL_JOBS"
echo "Conda environment: ${CONDA_DEFAULT_ENV:-<none>}"

# Build command construction
BUILD_CMD="cmake --build \"$BUILD_DIR\""

# Add parallel jobs
if [[ "$PARALLEL_JOBS" -gt 1 ]]; then
    BUILD_CMD="$BUILD_CMD --parallel $PARALLEL_JOBS"
    echo "Using parallel build with $PARALLEL_JOBS cores"
else
    echo "Using single-core build (easier to debug errors)"
fi

# Add build type if specified
if [[ -n "$BUILD_TYPE" ]]; then
    BUILD_CMD="$BUILD_CMD --config $BUILD_TYPE"
    echo "Build type: $BUILD_TYPE"
fi

# Add verbose output if requested
if [[ "$VERBOSE" == "true" ]]; then
    BUILD_CMD="$BUILD_CMD --verbose"
    echo "Verbose output enabled"
fi

echo ""
echo "Executing: $BUILD_CMD"
echo ""

# Record start time
START_TIME=$(date +%s)

# Execute build with proper error handling
if eval "$BUILD_CMD"; then
    END_TIME=$(date +%s)
    BUILD_TIME=$((END_TIME - START_TIME))
    
    echo ""
    echo "=== Build Complete! ==="
    echo "Build time: ${BUILD_TIME}s"
    echo "Next step: source $BUILD_DIR/INSTALL/bin/env_sirf.sh"
    echo ""
    
    # Show installation directory info
    if [[ -d "$BUILD_DIR/INSTALL" ]]; then
        echo "Installation summary:"
        echo "  Install dir: $BUILD_DIR/INSTALL"
        if [[ -f "$BUILD_DIR/INSTALL/bin/env_sirf.sh" ]]; then
            echo "  Environment script: ✓ Available"
        else
            echo "  Environment script: ✗ Not found"
        fi
        
        # Check for Python modules
        if [[ -d "$BUILD_DIR/INSTALL/python" ]]; then
            echo "  Python modules: ✓ Available"
        elif find "$BUILD_DIR/INSTALL" -name "*.py" -o -name "*.so" | head -1 >/dev/null 2>&1; then
            echo "  Python modules: ✓ Available"
        else
            echo "  Python modules: ⚠ Check installation"
        fi
    fi
    
else
    END_TIME=$(date +%s)
    BUILD_TIME=$((END_TIME - START_TIME))
    
    echo ""
    echo "=== Build Failed! ==="
    echo "Build time before failure: ${BUILD_TIME}s"
    echo ""
    echo "Troubleshooting tips:"
    echo "1. Try a debug build: $0 --debug"
    echo "2. Check the error messages above"
    echo "3. Verify your conda environment: conda list"
    echo "4. Check build directory: ls -la $BUILD_DIR"
    echo ""
    exit 1
fi