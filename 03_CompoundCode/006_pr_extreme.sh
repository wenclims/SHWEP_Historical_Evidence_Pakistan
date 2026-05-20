#!/bin/bash

set -euo pipefail
export HDF5_USE_FILE_LOCKING=FALSE

# Argument Parsing
if [ $# -lt 1 ]; then
    echo "=============================================="
    echo "  ERROR: No input file provided."
    echo "=============================================="
    echo "  Usage  : bash 006_pr_extreme_may_sep.sh <input_file.nc>"
    echo "  Example: bash 006_pr_extreme_may_sep.sh pr_PAK_ModelName_historical_ssp126_1980-2100.nc"
    echo "=============================================="
    exit 1
fi

INPUT_FILE="$1"
BASE_DIR="$2"

# Validate input
if [ ! -f "${INPUT_FILE}" ]; then
    echo "  [ERROR] Input file not found: ${INPUT_FILE}"
    exit 1
fi

if [[ "${INPUT_FILE}" != *.nc ]]; then
    echo "  [ERROR] Input file must be a NetCDF (.nc) file."
    exit 1
fi

# Derive model name from filename
# e.g. pr_PAK_ModelName_historical_ssp126_1980-2100.nc → ModelName
input_basename=$(basename "${INPUT_FILE}")
MODEL_NAME=$(echo "${input_basename}" | cut -d'_' -f3)

set -euo pipefail

# =========================
# USER SETTINGS
# =========================
INFILE="$INPUT_FILE"
REF_START=1995
REF_END=2024
# REF_START=1980
# REF_END=2009
PCTL=95

OUTDIR="${BASE_DIR}/final_binary/"

mkdir -p "${OUTDIR}"

FINAL_OUTPUT="${OUTDIR}/EP_PAK_${MODEL_NAME}_1980-2100.nc"

if [[ -f "$FINAL_OUTPUT" ]]; then
    echo "  [SKIP] Final output already exists: $FINAL_OUTPUT"
    exit 0
fi

echo "--------------------------------------"
echo "Extreme Precipitation Detection (CDO)"
echo "MONSOON SEASON: May-September ONLY"
echo "Reference period: ${REF_START}-${REF_END}"
echo "Percentile: ${PCTL}"
echo "Wet-day threshold: >= 1 mm"
echo "--------------------------------------"

# =========================
# Step 1: Set dry days to MISSING and convert to mm/day
# =========================
echo "Step 1: Setting precipitation < 1mm to MISSING..."
# cdo -setrtomiss,-inf,0.9999 ${INFILE} \
cdo -setrtomiss,-inf,0.9999 -mulc,86400 ${INFILE} \
    ${OUTDIR}/pr_wet_only.nc

# =========================
# Step 2: Extract May-September months from entire dataset
# =========================
echo "Step 2: Extracting May-September months from full dataset..."
cdo -selmon,5,6,7,8,9 \
    ${OUTDIR}/pr_wet_only.nc \
    ${OUTDIR}/pr_wet_only_may_sep.nc

# =========================
# Step 3: Extract reference period (May-Sep only)
# =========================
echo "Step 3: Selecting reference period ${REF_START}-${REF_END} (May-Sep only)..."
cdo -selyear,${REF_START}/${REF_END} \
    ${OUTDIR}/pr_wet_only_may_sep.nc \
    ${OUTDIR}/pr_ref_may_sep.nc

# =========================
# Step 4: Compute 95th percentile from May-Sep reference period
# =========================
echo "Step 4: Computing ${PCTL}th percentile from May-Sep wet days only..."
cdo -timpctl,${PCTL} \
    ${OUTDIR}/pr_ref_may_sep.nc \
    -timmin ${OUTDIR}/pr_ref_may_sep.nc \
    -timmax ${OUTDIR}/pr_ref_may_sep.nc \
    ${OUTDIR}/pr_p${PCTL}_may_sep.nc

# =========================
# Step 5: Binary extreme encoding for May-Sep dataset
# =========================
echo "Step 5: Binary encoding for May-Sep months (1 = extreme, 0 = non-extreme or dry)..."
# -ge compares wet_only against threshold (MISSING days stay MISSING)
# -setmisstoc,0 converts those MISSING dry days to 0 for clean binary output
cdo -setmisstoc,0 -ge \
    ${OUTDIR}/pr_wet_only_may_sep.nc \
    ${OUTDIR}/pr_p${PCTL}_may_sep.nc \
    ${OUTDIR}/EP_PAK_${MODEL_NAME}_1980-2100.nc
    # ${OUTDIR}/EP_PAK_${MODEL_NAME}_1980-2024.nc

echo "--------------------------------------"
echo "DONE ✔"
echo "Outputs written to: ${OUTDIR}"
echo ""
echo "Key outputs:"
echo "  - 95th percentile (May-Sep): pr_p${PCTL}_may_sep.nc"
echo "  - Binary extremes (May-Sep): EP_PAK_${MODEL_NAME}_1980-2100.nc"
echo "--------------------------------------"