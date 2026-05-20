#!/bin/bash

# ============================================================
# Script: extract_pakistan.sh
# Description: Extract Pakistan region from global climate
#              models using CDO sellonlatbox.
# Input : OUTPUT_DIR/model-name/variable-name/var_global_*.nc
# Output: OUTPUT_DIR/model-name/variable-name/var_PAK_*.nc
# ============================================================

set -e

# --- CONFIGURATION ---
BASE_DIR="/media/wcs/Disk3/Rasheed/000_SEPHCE_pakistan/Data2/"
INPUT_DIR="/media/wcs/Disk3/Rasheed/000_SEPHCE_pakistan/Data_Merged"

success=0
failed=0
skipped=0

# Loop over each model directory
for model_dir in "$INPUT_DIR"/*/; do
    model_name=$(basename "$model_dir")

    echo "----------------------------------------"
    echo "Processing model: $model_name"
    echo "----------------------------------------"
    # TASMAX_FILE="$INPUT_DIR/$model_name/tasmax/tasmax_PAK_${model_name}_historical_ssp126_1980-2100.nc"
    # PR_FILE="$INPUT_DIR/$model_name/pr/pr_PAK_${model_name}_historical_ssp126_1980-2100.nc"

    SCEN="ssp245"

    TASMAX_FILE="${INPUT_DIR}/${model_name}/tasmax/${SCEN}/tasmax_PAK_${model_name}_historical_${SCEN}_1980-2100.nc"
    PR_FILE="${INPUT_DIR}/${model_name}/pr/${SCEN}/pr_PAK_${model_name}_historical_${SCEN}_1980-2100.nc"

    echo "  [TASMAX] $TASMAX_FILE"
    echo "  [PR] $PR_FILE"

    if [ ! -f "$TASMAX_FILE" ]; then
        echo "  [SKIP] Missing TASMAX file: $TASMAX_FILE"
        rm -rf "${BASE_DIR}/interim/"
        continue
    fi

    if [ ! -f "$PR_FILE" ]; then
        echo "  [SKIP] Missing PR file: $PR_FILE"
        rm -rf "${BASE_DIR}/interim/"
        continue
    fi


    # -----------------------
    input_basename=$(basename "${TASMAX_FILE}")
    MODEL_NAME=$(echo "${input_basename}" | cut -d'_' -f3)

    HW_FILE="${BASE_DIR}/interim/final_binary/HW_PAK_${MODEL_NAME}_1980-2100.nc"
    PR_EXTREME_FILE="${BASE_DIR}/interim/final_binary/EP_PAK_${MODEL_NAME}_1980-2100.nc"


    OUTFILE="${BASE_DIR}/compound_events/SHWEP_PAK_${MODEL_NAME}_1980-2100.nc"
    echo "  [Compound Events Output] $OUTFILE"

    if [[ -f "$OUTFILE" ]]; then
        echo "  [SKIP] Output exists: $OUTFILE"
    else
        echo "================================================="
        echo "  SHWEP Pakistan Processing Pipeline Starting"
        echo "================================================="

        cd ./

        echo "Step 1: Generate 15-day Tmax"
        python3 001_generate_15d_tmax.py $TASMAX_FILE $BASE_DIR/interim/
        wait
        echo "Step 2: Calculate Tmax P90 (MW15)"
        bash 002_calc_tmax_p90_mw15.sh "$BASE_DIR/interim/"

        echo "Step 3: Separate each day MJJAS"
        bash 003_seperate_each_day_MJJAS.sh $TASMAX_FILE "$BASE_DIR/interim/"

        echo "Step 4: Hot encode 90th percentile" 
        bash 004_hot_encode_90PTCL.sh "$BASE_DIR/interim/"

        echo "Step 5: Heatwave processing"
        bash 005_hw_processing.sh $TASMAX_FILE "$BASE_DIR/interim/"

        echo "Step 6: Precipitation extremes"
        bash 006_pr_extreme.sh $PR_FILE "$BASE_DIR/interim/"

        echo "Step 7: Compound Events (1 day)"
        python3 009_CE_and_DURATION.py $HW_FILE $PR_EXTREME_FILE "$BASE_DIR/"


        rm -rf "${BASE_DIR}/interim/"

        echo "================================================="
        echo "        ALL PROCESSING COMPLETED SUCCESSFULLY"
        echo "================================================="
        
    fi

done

echo "========================================"
echo "Summary"
echo "========================================"
echo "Successful : $success"
echo "Failed     : $failed"
echo "Skipped    : $skipped"
echo "========================================"