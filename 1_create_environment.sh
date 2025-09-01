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

# --- initialise shell integration ---
if [[ "$PM" == "mamba" || "$PM" == "conda" ]]; then
  if [[ -f "$HOME/miniforge3/etc/profile.d/conda.sh" ]]; then
    # shellcheck disable=SC1091
    source "$HOME/miniforge3/etc/profile.d/conda.sh"
  elif [[ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]]; then
    # shellcheck disable=SC1091
    source "$HOME/miniconda3/etc/profile.d/conda.sh"
  else
    eval "$($PM shell.bash hook)" || true
  fi
  if [[ "$PM" == "mamba" ]]; then
    eval "$(mamba shell hook --shell bash)" || true
  fi
else
  eval "$($PM shell hook -s bash)" || true
fi

# --- remove existing env if present ---
echo "Removing existing environment if present: $ENV_NAME"
if "$PM" env list 2>/dev/null | grep -qw "$ENV_NAME"; then
  if [[ "$PM" == "micromamba" ]]; then
    "$PM" remove -y -n "$ENV_NAME" --all || true
  else
    "$PM" env remove -y -n "$ENV_NAME" || true
  fi
fi

# --- create from YAML (correct subcommand per tool) ---
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: $ENV_FILE not found in $(pwd)" >&2
  exit 1
fi

echo "Creating new environment from $ENV_FILE"
case "$PM" in
  mamba)       "$PM" env create -f "$ENV_FILE" ;;
  conda)       "$PM" env create -f "$ENV_FILE" ;;
  micromamba)  "$PM" create -y -f "$ENV_FILE" ;;
esac

# --- resolve final env name from YAML (fallback to ENV_NAME) ---
YAML_NAME="$(awk -F': *' '/^name:/ {print $2; exit}' "$ENV_FILE" || true)"
FINAL_NAME="${YAML_NAME:-$ENV_NAME}"

# --- activate ---
echo "Activating environment: $FINAL_NAME"
case "$PM" in
  micromamba)  micromamba activate "$FINAL_NAME" ;;
  mamba)       mamba activate "$FINAL_NAME" ;;
  conda)       conda activate "$FINAL_NAME" ;;
esac

echo ""
echo "=== Environment Creation Complete! ==="
echo "Environment '$FINAL_NAME' is active."
echo "Next step: run ./2_setup_build.sh"
echo ""