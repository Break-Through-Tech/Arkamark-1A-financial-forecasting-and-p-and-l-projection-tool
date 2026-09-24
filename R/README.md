# R pipeline

```r
install.packages(c("readr","dplyr","tidyr","stringr","purrr","lubridate","janitor"))
```

```bash
Rscript R/01_eda_financials.R    # profile the raw files
Rscript R/02_clean_financials.R  # CLEANING   -> fin_*.csv, fin_panel_*.csv
Rscript R/03_tidy_long.R         # RESHAPING  -> fin_long_*.csv, fin_coverage.csv
Rscript R/04_analysis_prep.R     # MODELING   -> fin_analysis_*.csv
Rscript R/05_data_dictionary.R   # DOCS       -> reports/data_dictionary.md
```

Run from anywhere; each script finds `00_config.R` from its own path.

## Three layers, and why the boundary matters

| Layer | Script | Does | Never does |
|---|---|---|---|
| Cleaning | `02` | types, keys, validity, error flags | impute, drop columns, touch outliers |
| Reshaping | `03` | wide to long | anything lossy |
| Modeling | `04` | select, fill, derive, winsorize | hide that these are choices |
| Documentation | `05` | measure the outputs, emit the dictionary | assert anything it did not measure |

A null in the script 02 output means "this company did not report this figure."
That is a fact about the data, not a defect. Filling it is an interpretation, so
interpretation lives in script 04 where it is parameterized in `MODEL` and
logged on every run.

Putting a modeling choice inside a file called "clean" hides it from everyone
downstream. That is the one rule in this pipeline.

## Which file do I use?

| You want to | Use |
|---|---|
| Fit a model or compute ratios | `fin_analysis_annual.csv` |
| Compare companies over equal periods | `fin_analysis_annual_balanced.csv` |
| Group or aggregate without deciding what absence means | `fin_long_annual.csv` |
| See reporting rates per line item | `fin_coverage.csv` |
| Audit a value or check a flag | `fin_panel_annual.csv` |

## The default path imputes nothing

`fin_analysis_annual.csv` is **15,732 rows, 37 columns, zero imputed values.**
29 of those 37 columns carry no nulls at all: every raw figure, every flag,
every key. All 8,874 blanks sit in the 8 derived ratio columns, and 7,034 of
them are `effective_tax` alone, where the guard declines to divide on pretax
income under $10M. A blank ratio is a refusal to divide, not a missing input.

Density comes from selecting the aggregates every operating company reports,
then keeping complete rows. It does not come from filling gaps.

An earlier version filled 168,102 cells with zero to reach the same 15,732 rows.
Those fills bought no additional rows. They only carried 26 optional line items
that a P&L projection does not use. `CFG$impute_absent_as_zero` is `FALSE`;
set it to `TRUE` if you need those columns and the log will price it for you.

Every figure in this section is measured by `R/05_data_dictionary.R`. If it
disagrees with `reports/data_dictionary.md`, that file is right and this one is
stale. Re-run script 05 after any change to scripts 02, 03 or 04.

## Two limitations no script can fix

**Four periods per company, maximum.** Annual gives 4 fiscal years, quarterly
gives 4 quarters. Not enough for a per-company two-year forecast.

**No sector, industry, SIC or country column exists in this source.**
Benchmarking an IT services firm against an undifferentiated pool of 4,422
banks, REITs, biotechs and retailers is not a benchmark. A ticker-to-sector
mapping has to be acquired separately before that use case is valid.

Both are documented in [`reports/cleaning_decisions.md`](../reports/cleaning_decisions.md).
