#!/usr/bin/env python3
"""
Step 1: 15-Day Moving Window Extraction for Tasmax (Parallelized)
-----------------------------------------------------------------
Usage:
    python step1_moving_window_parallel.py <input_file.nc> <BASE_DIR>
"""

import os
import sys
import subprocess
from datetime import datetime, timedelta
from concurrent.futures import ProcessPoolExecutor, as_completed

# -----------------------------------------------
# Argument Parsing
# -----------------------------------------------
if len(sys.argv) < 3:
    print("=" * 60)
    print("  ERROR: No input file provided.")
    print("=" * 60)
    sys.exit(1)

INPUT_FILE = os.path.abspath(sys.argv[1])
BASE_DIR   = os.path.abspath(sys.argv[2])

if not os.path.isfile(INPUT_FILE):
    print(f"  [ERROR] Input file not found: {INPUT_FILE}")
    sys.exit(1)

if not INPUT_FILE.endswith(".nc"):
    print(f"  [ERROR] Input file must be a NetCDF (.nc) file: {INPUT_FILE}")
    sys.exit(1)

# -----------------------------------------------
# Variable name
# -----------------------------------------------
input_basename = os.path.basename(INPUT_FILE)
var_name       = input_basename.split("_")[0]  # e.g. "tasmax"

# -----------------------------------------------
# Paths
# -----------------------------------------------
OUT_DIR  = os.path.join(BASE_DIR, "15d_moving_window", var_name)
TMP_DIR  = os.path.join(BASE_DIR, "tmp_15d", var_name)
os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(TMP_DIR, exist_ok=True)

# -----------------------------------------------
# Reference period
# -----------------------------------------------
REF_START = 1995
REF_END   = 2024

# REF_START = 1980
# REF_END   = 2009

# -----------------------------------------------
# Season: May (5) to September (9)
# -----------------------------------------------
SEASON_MONTHS = {5: 31, 6: 30, 7: 31, 8: 31, 9: 30}

# -----------------------------------------------
# Helper: run a CDO command safely
# -----------------------------------------------
def run_cdo(cmd: list, label: str = "") -> bool:
    try:
        subprocess.run(cmd, check=True, stderr=subprocess.PIPE)
        return True
    except subprocess.CalledProcessError as e:
        tag = f" [{label}]" if label else ""
        print(f"  [ERROR]{tag} CDO failed: {e.stderr.decode().strip()}")
        return False

# -----------------------------------------------
# Process a single calendar day
# -----------------------------------------------
def process_calendar_day(args):
    month, day = args
    mm  = f"{month:02d}"
    dd  = f"{day:02d}"
    tag = f"{mm}-{dd}"
    output_file = os.path.join(OUT_DIR, f"mw_{mm}{dd}.nc")

    if os.path.exists(output_file):
        return (tag, "skipped")

    year_files = []
    year_failed = False

    for year in range(REF_START, REF_END + 1):
        target_date = datetime(year, month, day)
        start_str   = (target_date - timedelta(days=7)).strftime("%Y-%m-%d")
        end_str     = (target_date + timedelta(days=7)).strftime("%Y-%m-%d")
        tmp_file    = os.path.join(TMP_DIR, f"{var_name}_{year}_{mm}{dd}.nc")

        success = run_cdo(
            ["cdo", "-s", f"seldate,{start_str},{end_str}", INPUT_FILE, tmp_file],
            label=f"{year}/{tag}"
        )
        if not success:
            year_failed = True
            continue

        year_files.append(tmp_file)

    if not year_files:
        return (tag, "failed")

    merge_ok = run_cdo(
        ["cdo", "-s", "mergetime"] + year_files + [output_file],
        label=f"mergetime/{tag}"
    )

    # Cleanup
    for f in year_files:
        if os.path.exists(f):
            os.remove(f)

    if merge_ok:
        return (tag, "processed")
    else:
        if os.path.exists(output_file):
            os.remove(output_file)
        return (tag, "failed")

# -----------------------------------------------
# Main
# -----------------------------------------------
def main():
    print("=" * 60)
    print("  Step 1: 15-Day Moving Window Extraction (Parallel)")
    print("=" * 60)
    print(f"  Variable   : {var_name}")
    print(f"  Input file : {INPUT_FILE}")
    print(f"  Output dir : {OUT_DIR}")
    print(f"  Temp dir   : {TMP_DIR}")
    print("=" * 60)

    # Prepare all calendar days
    all_days = [(m, d) for m, n_days in SEASON_MONTHS.items() for d in range(1, n_days+1)]

    processed = skipped = failed = 0

    # Use 48 cores
    with ProcessPoolExecutor(max_workers=48) as executor:
        future_to_day = {executor.submit(process_calendar_day, day): day for day in all_days}

        for future in as_completed(future_to_day):
            tag, status = future.result()
            if status == "processed":
                print(f"  [OK] {tag}")
                processed += 1
            elif status == "skipped":
                print(f"  [SKIP] {tag}")
                skipped += 1
            else:
                print(f"  [ERROR] {tag}")
                failed += 1

    # Summary
    total = len(all_days)
    print("\n" + "=" * 60)
    print("  Summary")
    print("=" * 60)
    print(f"  Total days  : {total}")
    print(f"  Processed   : {processed}")
    print(f"  Skipped     : {skipped}")
    print(f"  Failed      : {failed}")
    print("=" * 60)
    print(f"  Output → {OUT_DIR}")
    print("=" * 60)

if __name__ == "__main__":
    main()