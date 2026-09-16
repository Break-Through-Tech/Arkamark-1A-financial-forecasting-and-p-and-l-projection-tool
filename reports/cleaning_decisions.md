# Cleaning decisions: financial statement data

For the Arkamark 1A team. This documents what `R/02_clean_financials.R` does to
the raw files and why, so that nobody has to reverse engineer it from the code
or wonder where 153 rows went.

Evidence for each decision is in [`eda_findings.md`](eda_findings.md). A record
of what each run actually changed is in `cleaning_log.txt`, regenerated every
time the script runs.

## Inputs and outputs

| Input | Rows in | Rows out | Removed |
|---|---|---|---|
| incomeStatementHistory_annually | 17,511 | 17,511 | 0 |
| incomeStatementHistory_quarterly | 17,657 | 17,648 | 3 empty, 6 duplicate |
| balanceSheetHistory_annually | 17,511 | 17,358 | 153 empty |
| balanceSheetHistory_quarterly | 17,657 | 17,481 | 174 empty, 2 duplicate |
| cashflowStatement_annually | 17,511 | 17,510 | 1 empty |
| cashflowStatement_quarterly | 17,657 | 17,639 | 12 empty, 6 duplicate |

Joined panels: `fin_panel_annual.csv` (17,511 x 93, 4,422 tickers) and
`fin_panel_quarterly.csv` (17,651 x 93, 4,420 tickers).

## Decisions

### 1. Blank placeholder rows are deleted

343 rows across the six files had every financial field at 0 or NA. These are
not companies with no assets, they are empty records. Deleting them is the only
decision in this pipeline that removes data outright.

Rejected alternative: keeping them and filtering downstream. Every person who
touched the data would have had to rediscover the problem.

### 2. Duplicate keys are resolved by keeping the more populated row

The quarterly files contained 14 duplicate `(ticker, period_end)` pairs. Some
were byte-identical. Others paired a real record with a zero-filled stub, for
example BOX on 2019-10-31 and LHX on 2019-09-27. The script keeps whichever row
has more populated fields, which handles both cases without a special case for
each ticker.

### 3. `totalRevenue == 0` becomes NA

983 annual and 1,111 quarterly income rows reported exactly zero revenue. A
public company with genuinely zero revenue is rare enough that these are almost
certainly unreported. Left as zero they produce division-by-zero margins that
silently propagate.

Consequence: those rows have no margin figures at all. 16,106 of 17,511 annual
rows carry a usable gross margin. The gap is deliberate and visible rather than
filled with a fake 0%.

### 4. Sparse columns are reported, never dropped

Nine columns exceed 65% missing. None are removed. `CFG$drop_sparse` is `FALSE`
and should probably stay that way.

The reason is that missingness here is structural, not random.
`research_development` is 66% missing because most of these companies do not do
R&D, and `inventory` is 45% missing because service companies carry none. That
absence describes the business model, which is precisely what a staffing and IT
services comparison needs. Dropping the column throws away the signal.

### 5. Accounting failures are flagged, not fixed or deleted

- `flag_gp_identity`: 20 annual rows where revenue minus cost of revenue does
  not equal gross profit. The income statement is essentially clean.
- `flag_bs_identity`: 2,361 annual and 1,658 quarterly rows where assets do not
  equal liabilities plus equity plus minority interest, at 0.1% tolerance.

Note on the second: minority interest sits outside `total_stockholder_equity`
in this source. Including it drops annual failures from 5,546 to 2,361. The
remaining 2,361 are genuine source errors.

These rows stay in the data. A model needs to know which records are suspect;
it does not need them removed by someone else's judgment.

### 6. Sign conventions get explicit magnitude columns

`interest_expense`, `capital_expenditures`, `dividends_paid` and
`repurchase_of_stock` are all stored as negatives. The originals are untouched
and `*_abs` copies are added, so a P&L build-up cannot accidentally add where it
meant to subtract.

### 7. Ratios are guarded, and two guards are different

Margins require revenue above $1M before a ratio is computed, and winsorized
`*_w` variants are provided alongside the raw ones. Without the floor, gross
margin ranged from -3,578 to +7.7.

Effective tax rate needed a stricter rule. Pre-tax income is far smaller than
revenue and crosses zero constantly, so the $1M floor let through a rate of
1,383 annual and -4,925 quarterly. It now requires pre-tax income above $10M
and clamps to [-0.5, 1.0]. The result has a median of 0.213 annual and 0.200
quarterly, which lands on the 21% US statutory rate. Coverage falls from 17,093
rows to 9,143, which is the price of the column meaning what it says.

### 8. Statements are joined with a full join

The panel keeps an income row even when its balance sheet record was a blank
placeholder, filling the balance fields with NA. This is why the annual panel is
17,511 rows while the annual balance file is 17,358.

This is a choice worth revisiting. An inner join would drop those rows entirely.
Full join keeps the revenue data and loses only the assets, which suits margin
work. If the analysis needs a complete balance sheet on every row, switch it.

### 9. Off-calendar fiscal years are preserved

13,802 of 17,511 annual rows end in December, but EDU ends in May and DRI in
late May. The script keeps the true `period_end` and adds a `calendar_aligned`
flag rather than forcing everything onto December 31.

## Open decisions for the team

1. **Do rows with `flag_bs_identity` belong in the benchmarking set?** 13% of
   annual rows carry it. The argument for keeping them is that a balance sheet
   failing to foot says nothing about the income statement, so revenue and
   margin work is unaffected. The argument against is that a source that gets
   the balance sheet wrong may be unreliable throughout. Someone should decide
   this on purpose.
2. **Full join or inner join for the panel?** See decision 8.
3. **The four-period ceiling.** See below.

## The limitation that outranks all of the above

No ticker has more than four periods in either file. Annual gives four fiscal
years per company. Quarterly gives four quarters, meaning one year, not four.

A two-year forward P&L projection built on four annual observations is
extrapolation from a four-point line. There is no seasonality to learn and no
out-of-sample period to validate against. What this data genuinely supports is
cross-sectional margin benchmarking: where a given cost structure sits relative
to 4,400 peers.

This should be settled before anyone commits to a forecasting method, and it is
worth raising with the challenge advisor.
