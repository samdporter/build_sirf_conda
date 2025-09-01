#!/usr/bin/env bash
# SIRF Conda Environment Creation Script (GPU-ready)
set -euo pipefail

echo "=== Creating SIRF Conda Environment (PET-only + TotalSegmentator) ==="

ENV_NAME="sirf-build"
ENV_FILE="sirf_environment.yml"

# --- pick package manager ---
PM=""
if command -v mamba >/dev/null 2>&1; then
  PM="mamba"
elif command -v micromamba >/dev/null 2>&1; then
  PM="micromamba"
elif command -v conda >/dev/null 2>&1; then
  PM="conda"
else
  echo "Error: need mamba/micromamba/conda on PATH." >&2
  exit 1
fi
echo "Using package manager: $PM"

# --- simplified shell integration ---
# Initialize conda for the current shell session
if [[ "$PM" == "conda" ]] || [[ "$PM" == "mamba" ]]; then
    # Try common conda installation paths
    CONDA_BASE_PATHS=("$HOME/miniforge3" "$HOME/miniconda3" "$HOME/anaconda3" "/opt/conda" "/usr/local/miniconda3")
    CONDA_INITIALIZED=false
    
    for conda_path in "${CONDA_BASE_PATHS[@]}"; do
        if [[ -f "$conda_path/etc/profile.d/conda.sh" ]]; then
            # shellcheck disable=SC1090
            source "$conda_path/etc/profile.d/conda.sh"
            CONDA_INITIALIZED=true
            echo "Initialized conda from: $conda_path"
            break
        fi
    done
    
    if [[ "$CONDA_INITIALIZED" == "false" ]]; then
        # Fallback: try to initialize from conda itself
        if command -v conda >/dev/null 2>&1; then
            eval "$(conda shell.bash hook)"
            echo "Initialized conda using shell hook"
        else
            echo "Warning: Could not initialize conda properly"
        fi
    fi
    
    # Initialize mamba if using mamba
    if [[ "$PM" == "mamba" ]] && command -v mamba >/dev/null 2>&1; then
        eval "$(mamba shell hook --shell bash)" 2>/dev/null || true
    fi
elif [[ "$PM" == "micromamba" ]]; then
    eval "$(micromamba shell hook -s bash)" 2>/dev/null || true
fi

# --- check if environment file exists ---
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: $ENV_FILE not found in $(pwd)" >&2
  echo "Make sure you're running this script from the directory containing $ENV_FILE" >&2
  exit 1
fi

# --- remove existing env if present (with robust error handling) ---
echo "Checking for existing environment: $ENV_NAME"

# Check if environment exists in the list
if "$PM" env list 2>/dev/null | grep -qw "$ENV_NAME"; then
  echo "Found '$ENV_NAME' in environment list, attempting to remove..."
  
  # Try to remove, but don't fail if it doesn't actually exist
  case "$PM" in
    micromamba)
      if ! "$PM" remove -y -n "$ENV_NAME" --all 2>/dev/null; then
        echo "Environment removal failed (this is normal if env was corrupted)"
        echo "Checking if environment directory exists..."
        ENV_DIR="$(conda info --base 2>/dev/null)/envs/$ENV_NAME"
        if [[ -d "$ENV_DIR" ]]; then
          echo "Manually removing environment directory: $ENV_DIR"
          rm -rf "$ENV_DIR"
        fi
      fi
      ;;
    mamba|conda)
      if ! "$PM" env remove -y -n "$ENV_NAME" 2>/dev/null; then
        echo "Environment removal failed (this is normal if env was corrupted)"
        echo "Checking if environment directory exists..."
        # Try to get the conda base path
        if command -v conda >/dev/null 2>&1; then
          ENV_DIR="$(conda info --base 2>/dev/null)/envs/$ENV_NAME"
        elif [[ -n "$CONDA_BASE" ]]; then
          ENV_DIR="$CONDA_BASE/envs/$ENV_NAME"
        else
          # Try common paths
          for base_path in "$HOME/miniforge3" "$HOME/miniconda3" "$HOME/anaconda3"; do
            if [[ -d "$base_path/envs/$ENV_NAME" ]]; then
              ENV_DIR="$base_path/envs/$ENV_NAME"
              break
            fi
          done
        fi
        
        if [[ -n "${ENV_DIR:-}" ]] && [[ -d "$ENV_DIR" ]]; then
          echo "Manually removing environment directory: $ENV_DIR"
          rm -rf "$ENV_DIR"
        fi
      fi
      ;;
  esac
  echo "Environment cleanup completed"
else
  echo "No existing environment found in list"
fi

# Additional cleanup: remove any leftover directories
echo "Checking for leftover environment directories..."
for base_path in "$HOME/miniforge3/envs" "$HOME/miniconda3/envs" "$HOME/anaconda3/envs"; do
  ENV_PATH="$base_path/$ENV_NAME"
  if [[ -d "$ENV_PATH" ]]; then
    echo "Found leftover directory: $ENV_PATH"
    echo "Removing: $ENV_PATH"
    rm -rf "$ENV_PATH"
  fi
done

# --- create from YAML ---
echo "Creating new environment from $ENV_FILE using $PM..."
case "$PM" in
  mamba)       
    "$PM" env create -f "$ENV_FILE" || {
      echo "Error: Failed to create environment with mamba"
      exit 1
    }
    ;;
  conda)       
    "$PM" env create -f "$ENV_FILE" || {
      echo "Error: Failed to create environment with conda"
      exit 1
    }
    ;;
  micromamba)  
    "$PM" create -y -f "$ENV_FILE" || {
      echo "Error: Failed to create environment with micromamba"
      exit 1
    }
    ;;
esac

# --- verify environment was created ---
YAML_NAME="$(awk -F': *' '/^name:/ {print $2; exit}' "$ENV_FILE" 2>/dev/null || echo "$ENV_NAME")"
FINAL_NAME="${YAML_NAME:-$ENV_NAME}"

echo "Verifying environment '$FINAL_NAME' was created..."
if ! "$PM" env list 2>/dev/null | grep -qw "$FINAL_NAME"; then
  echo "Error: Environment '$FINAL_NAME' was not created successfully!" >&2
  exit 1
fi

echo ""
echo "=== Environment Creation Complete! ==="
echo "Environment '$FINAL_NAME' has been created successfully."
echo ""
echo "To activate the environment, run:"
echo "  conda activate $FINAL_NAME"
echo "or:"
echo "  mamba activate $FINAL_NAME"
echo ""
echo "Once activated, run the next step:"
echo "  ./2_setup_build.sh"
echo ""