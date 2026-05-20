#!/usr/bin/env python3
"""
Compound Event Detection & Duration (Multi-window)
==================================================
Detect compound events (CE) where a heatwave END is followed by extreme precipitation
within 1, 3, 5, or 7 days. Computes both binary masks and CE duration.
"""

import numpy as np
import xarray as xr
from pathlib import Path
import sys

# =============================================================================
# PATHS
# =============================================================================

# READ INPUT FILES FROM COMMAND LINE
HW_FILE = Path(sys.argv[1])
PR_FILE = Path(sys.argv[2])
BASE_DIR = Path(sys.argv[3])
OUT_DIR = BASE_DIR / "compound_events_ssp245/"
OUT_DIR.mkdir(parents=True, exist_ok=True)

model_name = HW_FILE.name.split("_")[2]
WINDOWS = [1, 3, 5, 7]  # CE detection windows in days

# =============================================================================
# LOAD & ALIGN
# =============================================================================
print("Loading data ...")
ds_hw  = xr.open_dataset(HW_FILE)
hw_var = "tasmax"
# hw_var = 'tmax'
hw     = ds_hw[hw_var]

ds_pr  = xr.open_dataset(PR_FILE)
pr_var = "pr"
# pr_var = 'precip'
# pr_var = "tp"
pr     = ds_pr[pr_var]

# Remove duplicate time values
print("Removing duplicate time values...")
_, unique_idx_hw = np.unique(hw.time.values, return_index=True)
hw = hw.isel(time=np.sort(unique_idx_hw))

_, unique_idx_pr = np.unique(pr.time.values, return_index=True)
pr = pr.isel(time=np.sort(unique_idx_pr))

common_times = np.intersect1d(hw.time.values, pr.time.values)
hw = hw.sel(time=common_times)
pr = pr.sel(time=common_times)

# Strict binary sanitization
hw_vals = np.clip(np.round(np.nan_to_num(hw.values, nan=0.0)), 0, 1).astype(np.float32)
pr_vals = np.clip(np.round(np.nan_to_num(pr.values, nan=0.0)), 0, 1).astype(np.float32)
T, Y, X = hw_vals.shape
print(f"Shape: T={T}, Y={Y}, X={X}")

# =============================================================================
# HEATWAVE & PRECIP STREAKS
# =============================================================================
print("Calculating HW streaks ...")
hw_streak = np.zeros((T, Y, X), dtype=np.float32)
hw_streak[0] = hw_vals[0]
for t in range(1, T):
    hw_streak[t] = (hw_streak[t-1] + 1) * hw_vals[t]

print("Calculating PR streaks ...")
pr_streak_dur = np.zeros((T, Y, X), dtype=np.float32)
curr_streak = np.zeros((Y, X), dtype=np.float32)
for t in range(T-1, -1, -1):
    curr_streak = (curr_streak + 1) * pr_vals[t]
    pr_streak_dur[t] = curr_streak

# =============================================================================
# DETECT CE & DURATION FOR ALL WINDOWS
# =============================================================================
coords = {"time": hw.time, "lat": hw.lat, "lon": hw.lon}
data_vars = {}

# Heatwave end days
hw_end = np.zeros((T, Y, X), dtype=np.float32)
hw_end[:-1] = (hw_vals[:-1] == 1) & (hw_vals[1:] == 0)
hw_end[-1] = 0

for window in WINDOWS:
    print(f"Processing {window}-day window ...")
    # --- CE binary mask ---
    pr_forward = np.zeros((T, Y, X), dtype=np.float32)
    for k in range(1, window + 1):
        if k < T:
            pr_forward[:T-k] = np.maximum(pr_forward[:T-k], pr_vals[k:])
    ce_mask = (hw_end == 1) & (pr_forward == 1)
    data_vars[f"CE_{window}d"] = (["time","lat","lon"], ce_mask.astype(np.float32))
    print(f"  Total CE triggers: {int(ce_mask.sum()):,}")

    # --- CE duration ---
    ce_duration = np.zeros((T, Y, X), dtype=np.float32)
    already_filled = np.zeros((T, Y, X), dtype=bool)
    for k in range(1, window + 1):
        if k >= T:
            break
        rain_on_day_k = (pr_vals[k:] == 1)
        trigger_at_k = (ce_mask[:T-k] == 1) & rain_on_day_k & (~already_filled[:T-k])
        if trigger_at_k.any():
            duration_at_k = hw_streak[:T-k] + (k-1) + pr_streak_dur[k:]
            duration_at_k = np.clip(duration_at_k, 0, 180)
            ce_duration[:T-k] = np.where(trigger_at_k, duration_at_k, ce_duration[:T-k])
            already_filled[:T-k] = already_filled[:T-k] | trigger_at_k
    data_vars[f"CE_{window}d_duration"] = (["time","lat","lon"], ce_duration)
    print(f"  Duration max: {ce_duration.max():.0f} days")

# =============================================================================
# SAVE ALL TO SINGLE NETCDF
# =============================================================================
attrs = {
    "description": "Compound Event binary masks and durations for multiple windows "
                   "(1, 3, 5, 7 days) after heatwave ends.",
    "hw_source": str(HW_FILE),
    "pr_source": str(PR_FILE),
    "units_binary": "1 = CE trigger, 0 = no CE",
    "units_duration": "days"
}

ds_out = xr.Dataset(data_vars=data_vars, coords=coords, attrs=attrs)
out_file = OUT_DIR / f"SHWEP_PAK_{model_name}_1980-2100.nc"
# out_file = OUT_DIR / f"SHWEP_PAK_{model_name}_1980-2024.nc"
ds_out.to_netcdf(out_file)
print(f"\nSaved multi-window CE & duration → {out_file}")
print("\n✅ Done.")