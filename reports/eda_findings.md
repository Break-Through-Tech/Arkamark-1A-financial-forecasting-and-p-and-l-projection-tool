# EDA findings: financial statement CSVs

Profiled against the six files in `data/`. Every cleaning rule in
`R/02_clean_financials.R` traces back to something on this page.

## Shape

| File | Rows | Cols | Tickers |
|---|---|---|---|
| incomeStatementHistory_annually | 17,511 | 20 | 4,422 |
| incomeStatementHistory_quarterly | 17,657 | 20 | 4,420 |
| balanceSheetHistory_annually | 17,511 | 31 | 4,422 |
| balanceSheetHistory_quarterly | 17,657 | 31 | 4,420 |
| cashflowStatement_annually | 17,511 | 22 | 4,422 |
| cashflowStatement_quarterly | 17,657 | 22 | 4,420 |

The three statements within a frequency share the same `(stock, endDate)` key,
so they join cleanly into one wide panel. Only 2 tickers appear annually but
not quarterly.

## The finding that should shape the whole project

**No ticker has more than 4 periods.** Annual files give at most 4 fiscal
years per company (2016 to 2019 for most). Quarterly files give at most 4
quarters, which is one year of history, not four.

- Annual: 4,279 tickers with 4 periods, 114 with 3, 24 with 2, 5 with 1
- Date span: 2012-07-12 to 2020-05-02 across companies, but only ~4 points each

A two-year forward P&L projection from 4 annual observations per company is
extrapolation from a 4-point line, not time series forecasting. There is no
seasonality to learn, no trend to validate out of sample. What this data
genuinely supports is **cross-sectional margin benchmarking**: where does a
given cost structure sit relative to 4,400 peers. Worth raising with the team
before anyone commits to an ARIMA or Prophet approach.

## Data quality issues found

**Duplicate keys (6 rows, quarterly only).** Three pairs are byte-identical
(AZO, SXT, TRC, VRTU). Three pairs are a real record beside a zero-filled stub
(BOX 2019-10-31, LHX 2019-09-27). Keeping the row with the most populated
fields resolves both cases without a special case.

**All-zero placeholder rows.** 153 in the annual balance sheet, 174 quarterly,
1 to 12 in cash flow. Every numeric field is 0 or NA. These are not companies
with no assets; they are empty records.

**`totalRevenue == 0`** in 983 annual and 1,111 quarterly income rows, plus 23
rows with negative revenue. Almost certainly "not reported" rather than a real
zero. Left as 0, these produce division-by-zero margins downstream, so the
pipeline converts them to NA.

**Missingness is heavy and structural, not random.**

| Statement | Worst columns |
|---|---|
| Income | discontinuedOperations 91%, otherOperatingExpenses 70%, minorityInterest 69%, researchDevelopment 66%, interestExpense 25% |
| Balance | deferredLongTermLiab 85%, shortTermInvestments 78%, minorityInterest 75%, shortLongTermDebt 69%, longTermInvestments 57%, inventory 45%, goodWill 45% |
| Cashflow | effectOfExchangeRate 55%, otherCashflowsFromInvesting 54%, dividendsPaid 52%, changeToInventory 52%, investments 48% |

Important distinction: `researchDevelopment` is 66% missing because most of
these companies do not report R&D at all, and `inventory` is 45% missing
because service companies do not carry inventory. That absence is a signal
about the business model. The pipeline flags sparse columns by default and
only drops them if you set `CFG$drop_sparse <- TRUE`.

**Accounting identities do not always hold.**

- Gross profit (`totalRevenue - costOfRevenue = grossProfit`): only 20 of
  17,511 annual rows violate it by more than $1,000. Essentially clean.
- Balance sheet (`assets = liabilities + equity`): 5,546 of 17,315 annual rows
  fail at 0.1% tolerance. Adding `minorityInterest` drops that to 2,361, which
  tells you minority interest sits outside `totalStockholderEquity` in this
  source. The remaining 2,361 are genuine source errors and get a
  `flag_bs_identity` column rather than deletion.

**Sign conventions.** `interestExpense` (13,077 negative vs 13 positive),
`capitalExpenditures` (15,261 negative vs 5), and `dividendsPaid` (8,384
negative, 0 positive) are all stored as negatives. The pipeline keeps the
originals and adds `*_abs` columns so a P&L build-up cannot accidentally add
where it meant to subtract.

**`ebit` duplicates `operatingIncome`** in 15,633 of 17,511 annual rows. Do not
treat them as two independent features.

**Fiscal calendars vary.** 13,802 of 17,511 annual rows end in December, but
EDU ends in May, DRI in late May, and 550 rows end in March. Forcing everything
onto a calendar year would misalign those companies. The pipeline keeps the
true `period_end` and adds a `calendar_aligned` flag.

**Raw margin ratios explode near zero revenue.** Unguarded gross margin runs
from -3,578 to +7.7, with 545 rows outside [-1, 1]. Requiring revenue above
$1M before computing a ratio cuts that to 408, and winsorized variants
(`*_w` columns) handle the remaining tail.

## After cleaning

| Panel | Rows | Cols | Tickers |
|---|---|---|---|
| fin_panel_annual | 17,511 | ~69 | 4,422 |
| fin_panel_quarterly | 17,651 | ~69 | 4,420 |

No duplicate `(ticker, period_end)` keys in either panel.

## Favorita dataset

The Favorita files are in the Claude project knowledge but not in this repo.
`R/03_clean_favorita.R` expects them in `data/favorita/`. Headers confirmed:

- `oil.csv` (date, dcoilwtico): missing weekend rows plus NA values including
  the first row
- `holidays_events.csv` (date, type, locale, locale_name, description,
  transferred): `transferred == TRUE` means the holiday did **not** happen that
  day, `type == "Work Day"` is the opposite of a holiday, and multiple rows
  share dates, which fans out a naive join
- `stores.csv` (store_nbr, city, state, type, cluster)
- `transactions.csv` (date, store_nbr, transactions)
- `test.csv` (id, date, store_nbr, family, onpromotion)
- `sample_submission.csv` (id, sales)

**`train.csv` is absent.** It is the file the entire dataset revolves around
and it is likely over the 30MB upload limit. Without it there are no sales to
forecast.
