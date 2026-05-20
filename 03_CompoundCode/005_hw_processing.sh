#!/bin/bash

# ============================================================
# Step 5: Heatwave Detection from Binary Tmax Extreme Files
# ============================================================
# Input  : Binary daily extreme files (0/1) from Step 4
# Output : HW_PAK_<ModelName>_1850_2100.nc (Daily Mask)
# ============================================================

set -euo pipefail
export HDF5_USE_FILE_LOCKING=FALSE

# -----------------------------------------------
# Argument Parsing
# -----------------------------------------------
if [ $# -lt 1 ]; then
    echo "  ERROR: No input file provided."
    exit 1
fi

INPUT_FILE="$1"
BASE_DIR="$2"

# -----------------------------------------------
# Extract model name
# -----------------------------------------------
input_basename=$(basename "${INPUT_FILE}")
MODEL_NAME=$(echo "${input_basename}" | cut -d'_' -f3)

# -----------------------------------------------
# Paths
# -----------------------------------------------
# BASE_DIR="/media/wcs/Disk3/Rasheed/000_SEPHCE_pakistan/Data/interim"
INPUT_DIR="${BASE_DIR}/binary_out"
TMP_DIR="${BASE_DIR}/tmax_binary_extremes_90PTCL/"
OUT_DIR="${BASE_DIR}/final_binary/"

mkdir -p "${TMP_DIR}"
mkdir -p "${OUT_DIR}"

# -----------------------------------------------
# Output filename (Now saving the daily mask)
# -----------------------------------------------
OUTPUT_FILE="${OUT_DIR}/HW_PAK_${MODEL_NAME}_1980-2100.nc"
# OUTPUT_FILE="${OUT_DIR}/HW_PAK_${MODEL_NAME}_1980-2024.nc"

if [[ -f "${OUTPUT_FILE}" ]]; then
    echo "  [SKIP] Output already exists: ${OUTPUT_FILE}"
    exit 0
fi

# -----------------------------------------------
# Step 1: Merge all binary files
# -----------------------------------------------
echo "  [►] Step 1: Merging binary files..."
cdo -s mergetime "${INPUT_DIR}"/extreme_1_0_*.nc \
    "${TMP_DIR}/hot_days_mask.nc"

# -----------------------------------------------
# Step 2: Consecutive streak lengths
# -----------------------------------------------
echo "  [►] Step 2: Computing streak lengths..."
cdo -s consects \
    "${TMP_DIR}/hot_days_mask.nc" \
    "${TMP_DIR}/streak_lengths.nc"

# -----------------------------------------------
# Step 3: Keep only streaks >= 3 days
# -----------------------------------------------
echo "  [►] Step 3: Creating heatwave mask..."
cdo -s gec,3 \
    "${TMP_DIR}/streak_lengths.nc" \
    "${TMP_DIR}/hw_mask.nc"

# -----------------------------------------------
# Step 4: Finalize Daily Mask (Replaces yearsum)
# -----------------------------------------------
echo "  [►] Step 4: Saving final daily mask..."
mv "${TMP_DIR}/hw_mask.nc" "${OUTPUT_FILE}"

# -----------------------------------------------
# Cleanup
# -----------------------------------------------
rm -rf "${TMP_DIR}"
echo "  [OK] Final output → ${OUTPUT_FILE}"
