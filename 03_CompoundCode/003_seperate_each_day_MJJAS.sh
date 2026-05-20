#!/bin/bash
# ============================================================
# Step 3: Split Daily Tmax Files by Month and Day (May–Sep)
# ============================================================
# Input  : Single NetCDF file covering MJJAS period
# Output : Individual daily files → days/MM/day_MM_DD.nc
#
# Usage:
#   bash step3_split_daily.sh <input_file.nc> <base_dir>
#
# Example:
#   bash step3_split_daily.sh tasmax_PAK_ModelName_historical_ssp585_1850-2100.nc \
#        /media/wcs/Disk3/Rasheed/000_SEPHCE_pakistan/Data/interim
# ============================================================

set -euo pipefail
export HDF5_USE_FILE_LOCKING=FALSE

# -----------------------------------------------
# Argument Parsing
# -----------------------------------------------
if [ $# -lt 2 ]; then
    echo "=============================================="
    echo "  ERROR: Missing arguments."
    echo "=============================================="
    echo "  Usage  : bash step3_split_daily.sh <input_file.nc> <base_dir>"
    echo "  Example: bash step3_split_daily.sh \\"
    echo "               tasmax_PAK_ModelName_historical_ssp585_1850-2100.nc \\"
    echo "               /media/wcs/Disk3/Rasheed/000_SEPHCE_pakistan/Data/interim"
    echo "=============================================="
    exit 1
fi

INPUT_FILE="$1"
BASE_DIR="$2"

# -----------------------------------------------
# Validate input file
# -----------------------------------------------
if [ ! -f "${INPUT_FILE}" ]; then
    echo "  [ERROR] Input file not found: ${INPUT_FILE}"
    exit 1
fi

if [[ "${INPUT_FILE}" != *.nc ]]; then
    echo "  [ERROR] Input file must be a NetCDF (.nc) file."
    exit 1
fi

# -----------------------------------------------
# Validate base directory
# -----------------------------------------------
if [ ! -d "${BASE_DIR}" ]; then
    echo "  [ERROR] Base directory not found: ${BASE_DIR}"
    exit 1
fi

# -----------------------------------------------
# Derive variable name from filename
# e.g. tasmax_PAK_ModelName_... → tasmax
# -----------------------------------------------
input_basename=$(basename "${INPUT_FILE}")
VAR="${input_basename%%_*}"   # everything before first underscore

# -----------------------------------------------
# Paths
# -----------------------------------------------
OUT_DIR="${BASE_DIR}/days/${VAR}"
TMP_DIR="${BASE_DIR}/tmp_splitmon/${VAR}"

# FIX: write CDO error log to BASE_DIR — avoids /tmp permission issues
CDO_ERR="${BASE_DIR}/cdo_err.txt"

mkdir -p "${OUT_DIR}"
mkdir -p "${TMP_DIR}"

# -----------------------------------------------
# Valid MJJAS months
# -----------------------------------------------
VALID_MONTHS=("05" "06" "07" "08" "09")

# -----------------------------------------------
# Header
# -----------------------------------------------
echo "=============================================="
echo "  Step 3: Split Daily Files (MJJAS)"
echo "=============================================="
echo "  Variable   : ${VAR}"
echo "  Input file : ${INPUT_FILE}"
echo "  Base dir   : ${BASE_DIR}"
echo "  Output dir : ${OUT_DIR}"
echo "  Temp dir   : ${TMP_DIR}"
echo "  CDO log    : ${CDO_ERR}"
echo "=============================================="

# -----------------------------------------------
# Counters
# -----------------------------------------------
success=0
failed=0

# -----------------------------------------------
# Step 1: Split into monthly files
# -----------------------------------------------
echo ""
echo "  [►] Splitting into monthly files..."

cdo -s splitmon "${INPUT_FILE}" "${TMP_DIR}/tmp_" 2>"${CDO_ERR}" || {
    echo "  [ERROR] splitmon failed:"
    sed 's/^/    /' "${CDO_ERR}"
    exit 1
}

echo "  [OK] Monthly split complete."

# -----------------------------------------------
# Step 2: Loop through MJJAS months → split to days
# -----------------------------------------------
for month in "${VALID_MONTHS[@]}"; do
    mfile="${TMP_DIR}/tmp_${month}.nc"

    if [ ! -f "${mfile}" ]; then
        echo ""
        echo "  [WARN] Monthly file not found for month ${month} — skipping."
        continue
    fi

    month_out_dir="${OUT_DIR}"
    mkdir -p "${month_out_dir}"

    echo ""
    echo "  [►] Processing month: ${month}"

    # ---- SKIP IF MONTH ALREADY DONE ----
    if ls "${month_out_dir}"/day_${month}_*.nc 1> /dev/null 2>&1; then
        echo "  [SKIP] Month ${month} already exists"
        continue
    fi

    if cdo -s splitday "${mfile}" "${month_out_dir}/day_${month}_" 2>"${CDO_ERR}"; then
        n_days=$(ls "${month_out_dir}"/day_${month}_*.nc 2>/dev/null | wc -l)
        echo "  [OK] Month ${month} → ${n_days} daily file(s) created."
        ((success += n_days))
    else
        echo "  [ERROR] splitday failed for month ${month}:"
        sed 's/^/    /' "${CDO_ERR}"
        ((failed++))
    fi

done

# -----------------------------------------------
# Step 3: Cleanup
# -----------------------------------------------
echo ""
echo "  [►] Cleaning up temporary files..."
rm -rf "${TMP_DIR}"
rm -f  "${CDO_ERR}"
echo "  [OK] Temp files removed."

# -----------------------------------------------
# Summary
# -----------------------------------------------
total_files=$(find "${OUT_DIR}" -name "*.nc" | wc -l)

echo ""
echo "=============================================="
echo "  Summary"
echo "=============================================="
echo "  Daily files created : ${success}"
echo "  Months failed       : ${failed}"
echo "  Output directory    : ${OUT_DIR}"
echo "=============================================="
echo "  Output structure:"
echo "    days/${VAR}/"
echo "    ├── day_05_01.nc ... day_05_31.nc"
echo "    ├── day_06_01.nc ... day_06_30.nc"
echo "    ├── day_07_01.nc ... day_07_31.nc"
echo "    ├── day_08_01.nc ... day_08_31.nc"
echo "    └── day_09_01.nc ... day_09_30.nc"
echo ""
echo "  Total .nc files in output: ${total_files}"
echo "=============================================="