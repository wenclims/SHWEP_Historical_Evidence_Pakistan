# SHWEP Pakistan Processing Pipeline

## Overview

This pipeline processes climate model outputs to detect and generate **SHWEP (Sequential Heatwave and Extreme Precipitation)** compound events over Pakistan.

The workflow combines:

* Heatwave detection using daily maximum temperature (`tasmax`)
* Extreme precipitation detection using precipitation (`pr`)
* Compound event generation where both extremes occur simultaneously

The script automates the full processing chain for multiple CMIP6 climate models and SSP scenarios.

---

# Workflow Summary

The pipeline performs the following steps:

1. Generate 15-day moving-window Tmax
2. Calculate Tmax 90th percentile thresholds
3. Separate daily climatology for MJJAS season
4. Hot-encode temperature exceedances
5. Detect heatwave events
6. Detect precipitation extremes
7. Generate compound SHWEP events

---

# Directory Structure

## Input Directory

Expected structure:

```text
INPUT_DIR/
├── MODEL_NAME/
│   ├── tasmax/
│   │   └── ssp245/
│   │       └── tasmax_PAK_MODEL_historical_ssp245_1980-2100.nc
│   │
│   └── pr/
│       └── ssp245/
│           └── pr_PAK_MODEL_historical_ssp245_1980-2100.nc
```

---

## Output Directory

Generated outputs:

```text
BASE_DIR/
├── interim/
│   ├── ...
│
├── compound_events/
│   └── SHWEP_PAK_MODEL_1980-2100.nc
```

---

# Requirements

## Software

* Bash
* Python 3
* CDO (Climate Data Operators)

## Python Packages

Install required Python libraries:

```bash
pip install xarray numpy scipy netCDF4 pandas rioxarray
```

---

# Configuration

Edit the following variables inside the script before execution:

```bash
BASE_DIR="/path/to/output_directory/"
INPUT_DIR="/path/to/input_directory/"
```

Select SSP scenario:

```bash
SCEN="ssp245"
```

Supported scenarios depend on available data:

* `ssp126`
* `ssp245`
* `ssp585`

---

# Processing Steps

## Step 1 — Generate 15-day Tmax

Script:

```bash
001_generate_15d_tmax.py
```

Creates 15-day moving-window Tmax values used for percentile calculations.

---

## Step 2 — Calculate Tmax P90 Thresholds

Script:

```bash
002_calc_tmax_p90_mw15.sh
```

Calculates the 90th percentile Tmax threshold using moving windows.

---

## Step 3 — Separate MJJAS Daily Climatology

Script:

```bash
003_seperate_each_day_MJJAS.sh
```

Extracts day-wise climatological values for:

* May
* June
* July
* August
* September

---

## Step 4 — Hot Encode Tmax Extremes

Script:

```bash
004_hot_encode_90PTCL.sh
```

Converts exceedances above the Tmax 90th percentile into binary extreme indicators.

---

## Step 5 — Heatwave Processing

Script:

```bash
005_hw_processing.sh
```

Detects heatwave events based on duration and threshold exceedance criteria.

---

## Step 6 — Extreme Precipitation Detection

Script:

```bash
006_pr_extreme.sh
```

Detects precipitation extreme events from daily precipitation data.

---

## Step 7 — SHWEP Compound Event Generation

Script:

```bash
009_CE_and_DURATION.py
```

Combines:

* Heatwave binary events
* Extreme precipitation binary events

to generate:

* Compound event occurrence
* Compound event duration statistics

---

# Running the Pipeline

Make the script executable:

```bash
chmod +x extract_pakistan.sh
```

Run:

```bash
./extract_pakistan.sh
```

---

# Output Files

Final output:

```text
SHWEP_PAK_MODEL_1980-2100.nc
```

Contains:

* SHWEP occurrence
* Compound-event duration information
* Time-series data for the full study period

---

# Notes

* Historical and SSP simulations are assumed to be merged into continuous files.
* Intermediate files are stored temporarily in:

```text
BASE_DIR/interim/
```

and automatically deleted after successful processing.

* Existing outputs are skipped automatically to avoid reprocessing.

---

# Error Handling

The script:

* skips missing files
* skips already processed models
* removes temporary directories after completion

The pipeline uses:

```bash
set -e
```

which stops execution immediately if a command fails.

---

# Example Models

Example CMIP6 models:

* ACCESS-CM2
* MPI-ESM1-2-HR
* CanESM5
* MIROC6
* CNRM-CM6-1
* etc

---

# Authors

Rasheed Ahmad (weather and Climate Services Pakistan)

Attaullah (Co-Lead Weather and Climate Services Pakistan)

Climate Extremes and Compound Event Analysis Workflow
