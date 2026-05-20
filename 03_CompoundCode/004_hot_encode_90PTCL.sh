#!/bin/bash

if [ $# -lt 1 ]; then
    echo "=============================================="
    echo "  ERROR: No input file provided."
    echo "=============================================="
    echo "  Usage  : bash 004_hot_encode_90PTCL.sh <BASE_DIR>"
    echo "  Example: bash 004_hot_encode_90PTCL.sh  /media/wcs/Disk3/Rasheed/000_SEPHCE_pakistan/Data/interim/days"
    echo "=============================================="
    exit 1
fi

BASE_DIR="$1"

VAR="tasmax"

# BASE_DIR="/media/wcs/Disk3/Rasheed/000_SEPHCE_pakistan/Data/interim"
DATA_DIR="${BASE_DIR}/days/${VAR}"
THR_DIR="${BASE_DIR}/thresholds/${VAR}"
OUT_DIR="${BASE_DIR}/binary_out"

mkdir -p $OUT_DIR

echo "Starting Binary Conversion (0 or 1)..."

for f in ${DATA_DIR}/day_*.nc; do
    
    fname=$(basename "$f")
    mm=$(echo $fname | cut -d'_' -f2)
    dd=$(echo $fname | cut -d'_' -f3 | cut -d'.' -f1)
    mmdd="${mm}${dd}"

    threshold_file="${THR_DIR}/tasmax_p90_${mmdd}.nc"
    out_file="${OUT_DIR}/extreme_1_0_${mmdd}.nc"

    # ---- SKIP IF OUTPUT EXISTS ----
    if [[ -f "$out_file" ]]; then
        echo "Skipping Day: $mmdd (already exists)"
        continue
    fi

    if [[ -f "$threshold_file" ]]; then
        echo "Processing Day: $mmdd"

        cdo gec,0 -sub "$f" "$threshold_file" "$out_file"

    else
        echo "Warning: Threshold file for $mmdd not found. Skipping..."
    fi

done

echo "Process Complete. Files saved in $OUT_DIR"