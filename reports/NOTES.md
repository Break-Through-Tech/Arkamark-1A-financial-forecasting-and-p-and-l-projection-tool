# Quick notes

Cheat sheet. Full detail in `data_dictionary.md` and `cleaning_decisions.md`.

## Run it

```bash
Rscript R/02_clean_financials.R   # clean
Rscript R/03_tidy_long.R          # long format
Rscript R/04_analysis_prep.R      # modeling tables
```

From the repo root. `data/clean/` is gitignored, so everyone generates it once.

## Which file for what

| File | Use it for |
|---|---|
| `fin_analysis_annual.csv` | Margin benchmarking, ratios, cross-company comparison. 15,732 rows, 15 core columns, zero nulls. |
| `fin_analysis_annual_balanced.csv` | Same, but only companies with all 4 periods. Fairer comparisons, no survivorship gaps. |
| `fin_analysis_quarterly.csv` | Anything seasonal, **and the COVID shock** (3,542 rows in Mar–May 2020). |
| `fin_panel_annual.csv` | Building an actual P&L, and any audit question. Has 22 more columns including SG&A and depreciation. |
| `fin_long_annual.csv` | Grouping, aggregating, or pivoting a custom subset. Zero NAs by design. |
| `fin_coverage.csv` | Which line items companies actually report, and how often. |

## The analysis table is not enough for a P&L

`fin_analysis_annual.csv` has 15 columns, tuned for margin work. A P&L build-up
needs line items it does not carry, and they are nearly fully populated on the
same rows:

| Line item | Present | In analysis table? |
|---|---|---|
| `total_other_income_expense_net` | 100.0% | No |
| `selling_general_administrative` | 98.6% | No |
| `depreciation` | 96.8% | No |
| `accounts_payable` | 96.6% | No |
| `capital_expenditures` | 90.5% | No |
| `interest_expense` | 76.9% | No |

Pull them from `fin_panel_annual.csv` by joining on `ticker` + `period_end`, or
move them into `CORE` in `R/04_analysis_prep.R`.

## Gotchas

- **`total_operating_expenses` already includes `cost_of_revenue`.** Do not add them.
- **Minority interest sits outside `total_stockholder_equity`.** The balance check adds it back.
- **Blank ratio cells are not missing data.** Every input is present in the same row; the guard declined to divide on a denominator under $1M.
- **Quarterly is dirtier than annual.** 75 negative-revenue rows vs 21, 30 negative-COGS vs 4.
- **Error rows are still in the files**, flagged not deleted. For benchmarking:
  `filter(!flag_negative_revenue, !flag_implausible_revenue, !flag_gp_exceeds_rev)` drops 421 rows.
- **Excel shows ratio columns as text** because R writes `NA`. Known issue, fix is `na = ""` in the `write_csv` calls.
- **Units are whole dollars.** `4202000000` is $4.2B.

## Two things no script fixes

1. **Max 4 periods per company.** Annual gives 4 years, quarterly gives 4 quarters. Not enough for a per-company 2-year forecast.
2. **No sector column exists.** Cannot pick peer companies. Real IT services comparables are in there by ticker (ACN = Accenture, VRTU = Virtusa) if you hand-pick.
