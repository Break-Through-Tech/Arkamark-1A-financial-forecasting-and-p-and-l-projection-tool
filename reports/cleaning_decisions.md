# Cleaning decisions

**Status:** draft, unsigned. Every row in the register below needs an owner and
a date before this document is worth anything.

This file records **judgment calls**: choices where a reasonable person could
have decided otherwise, and where the choice changes downstream results. It is
written and maintained by people.

Measured facts about the data do not belong here. They live in
[`data_dictionary.md`](data_dictionary.md), which is emitted by
`R/05_data_dictionary.R` and regenerates on every run. The split is deliberate:
the part that goes stale is automated, the part that needs a human owner stays
with a human owner.

---

## Provenance, before anything else

This pipeline does not process Arkamark data. Arkamark has provided none. The
six source CSVs are a public Kaggle dataset of filed statements for roughly
4,400 listed companies, used as a substitute while Arkamark's own data is
finalised.

The data is real, not synthetic. `ACN` is Accenture, `AZO` is AutoZone. So any
finding here is a true statement about those companies and says nothing about
Arkamark without an explicit comparability argument.

State this on every chart, slide and README built from these outputs.

---

## How to read this file

Each decision has a number, the parameter that implements it, what we chose,
what we rejected, and the evidence. If you disagree with one, change the row,
put your name on it, and note the date. Do not silently change the code.

A decision with `TBD` in the owner column has not actually been made. It has
been inherited.

---

## Decision register

| # | Decision | Setting | Owner | Date |
|---|---|---|---|---|
| 1 | Layer boundary: cleaning never imputes | architectural | TBD | TBD |
| 2 | Keep sparse columns | `drop_sparse = FALSE` | TBD | TBD |
| 3 | Drop wholly empty rows | `drop_empty_rows = TRUE` | TBD | TBD |
| 4 | Flag errors, do not delete them | architectural | TBD | TBD |
| 5 | Identity tolerance | `identity_tol = 0.001` | TBD | TBD |
| 6 | Treat zero revenue as missing, in modeling only | `zero_revenue_to_na = TRUE` | TBD | TBD |
| 7 | Do not fill absent line items with zero | `impute_absent_as_zero = FALSE` | TBD | TBD |
| 8 | Two ratio floors: margins vs balance sheet | `min_revenue_denom = 1e7`, `min_denominator = 1e6` | TBD | TBD |
| 9 | Guard the effective tax rate harder | `min_pretax_income = 1e7` | TBD | TBD |
| 10 | No winsorizing by default | `winsor_probs = NULL` | TBD | TBD |
| 11 | Balance sheet and cash flow are out of scope | scope | TBD | TBD |
| 12 | Mark rows whose P&L dwarfs their revenue | `margin_unreliable` | TBD | TBD |

---

## 1. Cleaning never imputes

**Chosen:** three layers. Script 02 fixes types, keys, validity and flags
errors. Script 03 reshapes. Script 04 selects, fills and derives.

**Rejected:** one `clean.R` that does everything.

**Why:** a null coming out of script 02 means "this company did not report this
figure." That is a fact about the filing, not a defect in the data. Filling it
is an interpretation, and an interpretation buried inside a file called "clean"
is invisible to everyone downstream who then treats the output as ground truth.

**Consequence to expect:** the script 02 outputs look alarming. In
`fin_panel_annual.csv`, 100% of rows carry at least one null. That is the design
working, not failing. Anyone fitting a model against a script 02 output is using
the wrong file.

---

## 2. Keep sparse columns

**Chosen:** no column is dropped for sparsity at any setting.

**Rejected:** dropping columns above a missingness threshold, typically 60%.

**Why:** in financial statements, missingness is almost never random. A blank
`research_development` means the company does not report R&D, not that the
figure is unknown. Dropping the column throws away the information that a whole
class of companies reports nothing there.

**Note the interaction:** if you ever add a sparsity drop, it must run *before*
any structural-zero fill. Filling first pushes every such column to 0% missing
and the drop silently finds nothing. A parallel Python implementation hit
exactly this bug and shipped a 91%-missing column into its output.

---

## 3. Drop wholly empty rows

**Chosen:** drop rows where every financial measure is 0 or NA. 343 rows.

**Rejected:** keeping them.

**Why:** a row with no measures is not an observation of a company-period, it is
an empty record. Note that `row_information()` deliberately excludes identifier
and derived-calendar columns, because counting `fiscal_year` as information is
what defeated an earlier version of this check.

---

## 4. Flag errors, do not delete them

**Chosen:** demonstrable errors get a `flag_*` column and stay in the file.
Negative revenue, negative COGS, gross profit exceeding revenue, failed balance
identity, implausibly small revenue, wrong period gap.

**Rejected:** deleting error rows during cleaning.

**Why:** deletion is irreversible and invisible. A flag lets each downstream use
decide. For benchmarking, filter with
`!flag_negative_revenue, !flag_implausible_revenue, !flag_gp_exceeds_rev`,
which drops 421 rows.

**Open item:** nobody has yet looked at *which* companies are flagged. If the
flags cluster in one sector, that is a finding worth a slide.

---

## 5. Identity tolerance of 0.1%

**Chosen:** `identity_tol = 0.001`, relative.

**Why:** filings round. An exact-equality test fails on rounding and tells you
nothing.

**What the identities actually show** (measured on the raw annual income
statement, 1% tolerance, 17,511 rows):

| Identity | Holds |
|---|---|
| `gross_profit = total_revenue - cost_of_revenue` | 99.9% |
| `operating_income = total_revenue - total_operating_expenses` | 100% |
| `operating_income = ebit` | 88.7% |
| `income_before_tax = ebit + total_other_income_expense_net` | 88.0% |
| `net_income = income_before_tax - income_tax_expense` | 86.3% |
| `total_operating_expenses = cost_of_revenue + SG&A + R&D` | **49.0%** |

**This is the most important table in the document, and it has consequences:**

- `operating_income` and `ebit` are **not the same field** despite the challenge
  brief naming EBIT as the target. Pick one, state which, defend it.
- Operating expenses **do not decompose** into COGS, SG&A and R&D on half the
  rows. A P&L engine built on that assumption will silently lose money. Carry
  the residual as an explicit `other_opex` line so the statement always ties.

**Open item:** no `05_audit_identities.R` exists yet. These numbers were
produced ad hoc and should be reproducible on every run.

---

## 6. Zero revenue becomes missing, in the modeling layer only

**Chosen:** script 02 only flags it. Script 04 converts it, with
`zero_revenue_to_na = TRUE`.

**Why:** revenue recorded as exactly 0 is a "not reported" placeholder in this
source, 983 annual rows and 1,111 quarterly. A listed company with genuinely
zero revenue is implausible. But calling 0 a placeholder is an interpretation,
so it happens in the layer where interpretations live and get logged.

---

## 7. Do not fill absent line items with zero

**Chosen:** `impute_absent_as_zero = FALSE`.

**Rejected:** filling to make the modeling table dense.

**Why:** an earlier version filled 168,102 cells with zero and gained **no
additional rows**. Density came from selecting the aggregates every operating
company reports, then keeping complete rows, not from filling gaps. The fills
only carried optional line items a P&L projection does not use.

**If you need those columns**, set the flag to `TRUE` and read the log, which
prices the change. Do not fill by hand.

---

## 8. Two ratio floors, not one

**Chosen:** margins divide by revenue and use `min_revenue_denom = 1e7`.
Balance-sheet ratios divide by liabilities, equity or assets and keep
`min_denominator = 1e6`.

**Rejected:** a single global floor.

**Why two:** at $1M the annual modeling table produced a gross margin of
**-112.30** and a net margin of **-257.66**, because 1,236 rows sit between $1M
and $10M of revenue where a margin is arithmetic noise. But raising the global
floor to $10M would also blank `current_ratio` and `debt_to_equity` for every
company with a small balance sheet, which costs real observations and solves
nothing. A small balance sheet is normal. A tiny revenue line under a large P&L
is not.

**Measured effect on annual net margin:**

| | min | p1 | median | max |
|---|---:|---:|---:|---:|
| Before | -257.66 | -16.06 | 0.049 | 155.34 |
| Floor only | -23.17 | -3.85 | 0.055 | 155.34 |
| Floor + `!margin_unreliable` | **-4.98** | **-2.46** | **0.055** | **4.83** |

The median barely moves. That is the evidence this removes noise rather than
signal. No rows are dropped; ~1,236 rows get blank margins instead of nonsense
ones, and their raw figures are retained.

**Still true:** a blank ratio is a refusal to divide, not a missing input. Every
input to a blank margin is present in the same row.

---

## 9. Effective tax rate floored at $10M pretax

**Chosen:** `min_pretax_income = 1e7`, bounds `c(-0.5, 1.0)`.

**Why:** effective tax rate is tax expense over pretax income. Roughly half
these companies have negative or near-zero pretax income, where the ratio is
meaningless or wildly signed.

**Consequence, and read this before anyone panics:** `effective_tax` is blank on
**7,034 of 15,732 rows, 44.7%**. That single column is 79% of every blank in the
file. It is the main reason the modeling table looks full of holes when it is
not. 29 of its 37 columns have zero nulls.

**Open item:** $10M is a high floor and it was inherited, not argued. Someone
should either defend it or lower it. Either way, put a name on it.

---

## 10. No winsorizing by default

**Chosen:** `winsor_probs = NULL`.

**Why:** clipping outliers changes reported results and should be a visible,
deliberate act. Set it to `c(0.01, 0.99)` when a specific analysis needs it and
the log will record that the run was winsorized.

**Counterpoint worth taking seriously:** raw operating margin in this source
runs to -28,077. Any median is safe, but any mean is not. If someone reports a
mean anywhere, this decision has to be revisited.

---

## 11. Balance sheet and cash flow are out of scope

**Chosen:** clean them, do not invest further in them.

**Why:** the challenge brief lists balance sheet and cash flow projection as a
stretch goal. The primary deliverable is a two-year sales forecast and a
projected P&L. Deep work on the other two statements before the P&L ships
spends weeks the schedule does not have.

**This is a scope decision, not a technical one, and it needs the loudest
signature on this page.**

---

## 12. Mark rows whose P&L dwarfs their revenue

**Chosen:** a `margin_unreliable` column, TRUE when
`|net_income| > 5 x |total_revenue|`. 861 annual rows, 5.5%. Marked, never
removed.

**Why a revenue floor is not enough:** two situations clear any plausible floor
and still produce a meaningless margin.

1. **Holding companies.** `LBRDA` and `LBRDK` are Liberty Broadband, `GLIBA` is
   GCI Liberty. Their income comes from equity-method stakes, not operations.
   LBRDA 2017 filed $13.1M of revenue against $2.03B of net income, a net
   margin of 155.3. $13.1M is a perfectly normal amount of revenue, so no
   floor catches it.
2. **Loss-making small caps**, mostly development-stage biotech, burning many
   times their revenue. Same arithmetic, opposite sign.

Both are correct filings. The test is symmetric because the problem is scale,
not sign.

**How to use it:** `filter(!margin_unreliable)` before any margin benchmark,
and say in the write-up that you did. Excluding 5.5% of observations is a
methodological choice a reader is entitled to know about.

**Open item:** the 5x threshold is a round number chosen because it cleanly
separates the two clusters. Nobody has tested 3x or 10x. If a reviewer asks why
5, there is currently no answer.

---

## Open questions the pipeline cannot resolve

**No sector, industry, SIC or country column exists in this source.** The brief
asks for margin structures relevant to a professional services firm.
Benchmarking one against an undifferentiated pool of 4,400 banks, REITs,
biotechs and retailers is not a benchmark. Either acquire a ticker-to-sector
mapping, or hand-pick comparables by ticker and document the list. `ACN` and
`VRTU` are in the data.

**Maximum four periods per company.** Annual gives four fiscal years,
2016 to 2019. Quarterly gives four quarters, almost all inside 2019, so the
quarterly files are a one-year snapshot rather than a time series. Neither
supports a per-company two-year forecast. The brief's reference to "ten years of
historical" does not match what was supplied.

Both have been raised with the Challenge Advisor. Record the date sent and any
reply here.

| Question | Raised on | Reply | Assumption we proceed on |
|---|---|---|---|
| Sector mapping source | TBD | none | TBD |
| Four periods vs ten years | TBD | none | TBD |

An unanswered question is not a blocker. It is an assumption, and assumptions
are a graded deliverable.

---

## Changelog

| Date | Change | By |
|---|---|---|
| 2026-09-22 | Added decisions 8 (split ratio floors) and 12 (`margin_unreliable`) after profiling found gross margins to -112 and net margins to 155 in the shipped modeling table. | TBD |
| 2026-09-22 | Rewritten. Measured facts moved to the generated `data_dictionary.md`; this file now holds judgment calls only. Owner and date columns added because the previous version had none. | TBD |
