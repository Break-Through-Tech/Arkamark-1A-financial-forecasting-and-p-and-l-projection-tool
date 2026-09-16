# R pipeline

Run from the repo root.

```r
install.packages(c("readr","dplyr","tidyr","stringr","purrr","lubridate","janitor"))
```

```bash
Rscript R/01_eda_financials.R    # -> reports/eda_financials.txt
Rscript R/02_clean_financials.R  # -> data/clean/*.csv, reports/cleaning_log.txt
Rscript R/03_clean_favorita.R    # -> data/clean/fav_*.csv  (needs data/favorita/)
```

Each script locates `00_config.R` from its own file path and resolves every
other path against the repo root, so the working directory does not matter.
Running from inside `R/`, from the repo root, or sourcing in RStudio all
behave identically. On startup the config prints the repo root it resolved;
if that line points somewhere unexpected, that is the thing to fix.

| File | Purpose |
|---|---|
| `00_config.R` | Paths, packages, cleaning parameters (`CFG`), helpers. Every tunable decision lives here. |
| `01_eda_financials.R` | Profiles the six raw files. Run before and after any upstream change. |
| `02_clean_financials.R` | Cleans all six files, builds the joined annual and quarterly panels. |
| `03_clean_favorita.R` | Cleans the Favorita files. Degrades gracefully if `train.csv` is absent. |

Findings that drove the cleaning rules are written up in
[`reports/eda_findings.md`](../reports/eda_findings.md).

## Design choices worth knowing

**Flag, do not delete.** Rows that fail an accounting identity get
`flag_bs_identity` or `flag_gp_identity` and stay in the data. A forecasting
model needs to know which records are suspect; it does not need them silently
removed by someone else's judgment call.

**Sparse columns are reported, not dropped.** `CFG$drop_sparse` is `FALSE` by
default. `researchDevelopment` being 66% missing is information about which
companies do R&D, not noise.

**Order of operations matters.** Empty-row removal runs before deduplication,
so a zero-filled stub is discarded as an empty row rather than competing with
the real record for the key.

**Ratios are guarded.** `safe_ratio()` returns NA when the denominator is under
`CFG$min_denominator` ($1M). Winsorized `*_w` variants exist alongside the raw
ones.

## Open question for the team

Neither file gives more than 4 periods per company. Before building a two-year
forecast, decide whether this data can support one at all, or whether
cross-sectional benchmarking is the honest framing until real Arkamark history
arrives. See `reports/eda_findings.md`.
