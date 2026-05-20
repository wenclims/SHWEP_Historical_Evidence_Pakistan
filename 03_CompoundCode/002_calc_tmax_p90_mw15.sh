#!/bin/bash
# ============================================================
# Step 2: Daily 90th Percentile Tmax Threshold Maps (May–Sep)
# ============================================================

set -euo pipefail
export HDF5_USE_FILE_LOCKING=FALSE

# Suppress the noisy HDF5 attribute-not-found diagnostics
export HDF5_DIAG_SUPPRESS=1   # not always available, but worth setting
# Better suppression: redirect stderr for CDO calls (see below)

if [ $# -lt 1 ]; then
    echo "  Usage  : bash 002_calc_tmax_p90_mw15.sh <BASE_DIR>"
    exit 1
fi

BASE_DIR="$1"
VAR="tasmax"
IN_DIR="${BASE_DIR}/15d_moving_window/${VAR}"
OUT_DIR="${BASE_DIR}/thresholds/${VAR}"

mkdir -p "${OUT_DIR}"

if [ ! -d "${IN_DIR}" ]; then
    echo "  [ERROR] Input directory not found: ${IN_DIR}"
    exit 1
fi

n_files=$(ls "${IN_DIR}"/mw_*.nc 2>/dev/null | wc -l)
if [ "${n_files}" -eq 0 ]; then
    echo "  [ERROR] No mw_*.nc files found in: ${IN_DIR}"
    exit 1
fi

echo "=============================================="
echo "  Step 2: 90th Percentile Threshold Maps"
echo "=============================================="
echo "  Variable   : ${VAR}"
echo "  Input dir  : ${IN_DIR}"
echo "  Output dir : ${OUT_DIR}"
echo "  Files found: ${n_files}"
echo "=============================================="

success=0
failed=0
skipped=0

for f in "${IN_DIR}"/mw_*.nc; do
    fname=$(basename "$f")
    mmdd="${fname#mw_}"
    mmdd="${mmdd%.nc}"

    output_file="${OUT_DIR}/${VAR}_p90_${mmdd}.nc"

    # Skip if output already exists
    if [[ -f "$output_file" ]]; then
        echo "  [SKIP] Exists: ${mmdd}"
        skipped=$((skipped + 1))   # FIX: was ((skipped++))
        continue
    fi

    echo "  [►] Processing: ${mmdd}"

    # Redirect stderr to /dev/null to suppress HDF5 noise
    # Remove 2>/dev/null if you want to see real CDO errors
    if cdo -s -L timpctl,90 \
            "$f" \
            -timmin "$f" \
            -timmax "$f" \
            "${output_file}" 2>/dev/null; then
        success=$((success + 1))   # FIX: was ((success++))
    else
        failed=$((failed + 1))     # FIX: was ((failed++))
        echo "  [ERROR] Failed: ${mmdd}"
        rm -f "$output_file"
    fi
done

echo ""
echo "=============================================="
echo "  Summary"
echo "=============================================="
echo "  Total files : ${n_files}"
echo "  Processed   : ${success}"
echo "  Skipped     : ${skipped}"
echo "  Failed      : ${failed}"
echo "=============================================="
echo "  Output → ${OUT_DIR}"
echo "=============================================="