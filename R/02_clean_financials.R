# ---------------------------------------------------------------------------
# 02_clean_financials.R
# CLEANING LAYER. Nothing else.
#
#   Rscript R/02_clean_financials.R
#
# What this script does:
#   1. Structural  - snake_case names, typed dates, explicit column contract
#   2. Validity    - removes records that are not observations of a company-period
#   3. Integrity   - resolves duplicate keys
#   4. Errors      - flags demonstrable data errors and contradictions
#   5. Provenance  - logs every change
#
# What this script deliberately does NOT do:
#   - impute or fill anything, including with zero
#   - drop columns for being sparse
#   - winsorize, clip, or otherwise move outliers
#   - engineer ratios or model features
#
# Those are judgment calls and they belong in script 04, where they are visible
# and switchable. A null here means "this company did not report this figure",
# which is a fact worth preserving, not a defect to be papered over.
#
# Outputs:
#   data/clean/fin_<statement>_<frequency>.csv
#   data/clean/fin_panel_annual.csv, fin_panel_quarterly.csv
#   reports/cleaning_log.txt
# ---------------------------------------------------------------------------

local({
  args <- commandArgs(trailingOnly = FALSE)
  fa <- grep("^--file=", args, value = TRUE)
  here <- if (length(fa) > 0) dirname(sub("^--file=", "", fa[1])) else NULL
  cands <- c(if (!is.null(here)) file.path(here, "00_config.R"),
             "R/00_config.R", "00_config.R", "../R/00_config.R")
  hit <- cands[file.exists(cands)]
  if (length(hit) == 0) stop("Cannot find 00_config.R.", call. = FALSE)
  source(hit[1], local = FALSE)
})

log_con <- file(file.path(PATHS$reports, "cleaning_log.txt"), open = "wt")
logline <- function(...) { m <- paste0(...); writeLines(m, log_con); message(m) }

logline("Arkamark 1A cleaning log - ", format(Sys.time(), "%Y-%m-%d %H:%M"))
logline("CLEANING LAYER: no imputation, no column dropping, no outlier treatment.")
logline(strrep("=", 78))

# ===========================================================================
# 1. STRUCTURAL
# ===========================================================================
# Objective transformations with no judgment: naming, typing, derived calendar
# fields. Off-calendar fiscal year ends are real (EDU ends in May, DRI in late
# May), so the true period_end is preserved and the deviation is recorded.

clean_structure <- function(df, statement, frequency) {
  df |>
    janitor::clean_names() |>
    rename(ticker = stock, period_end = end_date) |>
    mutate(
      statement        = statement,
      frequency        = frequency,
      fiscal_year      = year(period_end),
      fiscal_qtr       = quarter(period_end),
      fiscal_month     = month(period_end),
      calendar_aligned = fiscal_month == 12L
    ) |>
    relocate(any_of(ID_COLS))
}

# ===========================================================================
# 2. VALIDITY
# ===========================================================================
# The question is not "does this row have gaps" but "is this row an observation
# of a company-period at all". A record whose every financial measure is 0 or
# NA answers no. That is a removal on validity grounds, not imputation.

drop_non_observations <- function(df, label) {
  if (!CFG$drop_empty_rows) return(df)
  keep <- row_information(df) > 0
  n <- sum(!keep)
  if (n > 0) logline("  [", label, "] removed ", n,
                     " records with no financial data at all")
  df[keep, ]
}

# ===========================================================================
# 3. INTEGRITY
# ===========================================================================
# (ticker, period_end) must be unique. 14 violations exist across the quarterly
# files: some byte-identical, some a real record beside a zero-filled stub.
# Keeping the more populated row resolves both without per-ticker special cases.

dedupe_keys <- function(df, label) {
  before <- nrow(df)
  out <- df |>
    mutate(.info = row_information(df)) |>
    arrange(ticker, period_end, desc(.info)) |>
    distinct(ticker, period_end, .keep_all = TRUE) |>
    select(-.info)
  n <- before - nrow(out)
  if (n > 0) logline("  [", label, "] resolved ", n, " duplicate keys")
  out
}

# ===========================================================================
# 4. ERROR DETECTION
# ===========================================================================
# Demonstrable errors: values that cannot be true, and internal contradictions.
# Every one is FLAGGED rather than corrected or removed. Correcting would mean
# guessing the true value; removing would mean deciding for the analyst.

add_error_flags <- function(df, statement, frequency) {
  has <- function(...) all(c(...) %in% names(df))

  # Period spacing. A frequency label is a claim about the data, and 49 "annual"
  # pairs violate it, one only 31 days apart. Either the label or the date is
  # wrong, and this flags the row so nobody differences it as if it were a year.
  win <- CFG$period_days[[frequency]]
  df <- df |>
    arrange(ticker, period_end) |>
    group_by(ticker) |>
    mutate(period_gap_days = as.numeric(period_end - lag(period_end))) |>
    ungroup() |>
    mutate(flag_period_gap = !is.na(period_gap_days) &
             (period_gap_days < win[1] | period_gap_days > win[2]))

  if (statement == "income" && has("total_revenue", "cost_of_revenue", "gross_profit")) {
    df <- df |> mutate(
      # A listed company cannot have negative revenue or negative cost of
      # revenue. 23 and 4 rows respectively.
      flag_negative_revenue = !is.na(total_revenue) & total_revenue < 0,
      flag_negative_cogs    = !is.na(cost_of_revenue) & cost_of_revenue < 0,
      # Gross profit above revenue is arithmetically impossible. 3 rows.
      flag_gp_exceeds_rev   = !is.na(gross_profit) & !is.na(total_revenue) &
                              gross_profit > total_revenue,
      # revenue - cogs should equal gross profit. 20 rows disagree by >$1k.
      flag_gp_identity      = !is.na(total_revenue) & !is.na(cost_of_revenue) &
                              !is.na(gross_profit) &
                              abs(total_revenue - cost_of_revenue - gross_profit) > 1000,
      # Revenue of a few thousand dollars for a listed company indicates a unit
      # error or a shell. 417 rows under $1M. Flagged only: whether a shell
      # belongs in your sample depends on the question being asked.
      flag_implausible_revenue = !is.na(total_revenue) & total_revenue > 0 &
                                 total_revenue < CFG$implausible_revenue,
      # Revenue recorded as exactly zero is a placeholder for "not reported" in
      # this source, 983 annual rows. NOT converted to NA here: that is an
      # interpretation, and script 04 applies it where it can be seen.
      flag_zero_revenue = !is.na(total_revenue) & total_revenue == 0
    )
  }

  if (statement == "balance" && has("total_assets", "total_liab", "total_stockholder_equity")) {
    df <- df |> mutate(
      # Minority interest sits outside total_stockholder_equity in this source.
      # Including it cuts annual identity failures from 5,546 to 2,361, which is
      # how we know it belongs on this side of the equation.
      balance_gap = total_assets -
        (total_liab + total_stockholder_equity + coalesce(minority_interest, 0)),
      flag_bs_identity = !is.na(balance_gap) &
        abs(balance_gap) > abs(total_assets) * CFG$identity_tol,
      flag_nonpositive_assets = !is.na(total_assets) & total_assets <= 0,
      # Liabilities above assets is negative equity. 968 rows. This is a real
      # financial condition, NOT an error, and is flagged for awareness only.
      flag_negative_equity = !is.na(total_assets) & !is.na(total_liab) &
                             total_liab > total_assets
    )
  }
  df
}

# ===========================================================================
# 5. PROVENANCE
# ===========================================================================
# Panel depth is a property of the source worth carrying on every row, since it
# caps what any model built on this data can honestly claim.

add_provenance <- function(df) {
  df |>
    group_by(ticker) |>
    mutate(n_periods = n(), period_index = dense_rank(period_end)) |>
    ungroup() |>
    mutate(complete_panel = n_periods == max(n_periods, na.rm = TRUE))
}

# ===========================================================================
# Pipeline
# ===========================================================================

clean_one <- function(statement, frequency, file) {
  label <- paste0(statement, "/", frequency)
  logline(""); logline(strrep("-", 78)); logline(file); logline(strrep("-", 78))

  raw <- read_fin_raw(file)
  logline("  read ", nrow(raw), " rows x ", ncol(raw), " cols")

  out <- raw |>
    clean_structure(statement, frequency) |>
    drop_non_observations(label) |>
    dedupe_keys(label) |>
    add_error_flags(statement, frequency) |>
    add_provenance()

  # Report what was flagged. Flags are the product of this script, so they are
  # summarised rather than buried in the output file.
  flags <- grep("^flag_", names(out), value = TRUE)
  if (length(flags) > 0) {
    logline("  error and condition flags raised:")
    for (f in flags) {
      n <- sum(out[[f]], na.rm = TRUE)
      if (n > 0) logline("    ", sprintf("%-28s %6d", f, n))
    }
  }

  # Missingness is reported, never acted on. This is the honest record of how
  # much of the source is unreported.
  miss <- missing_profile(out) |> filter(pct_missing > 0.5)
  if (nrow(miss) > 0) {
    logline("  columns over 50% unreported (RETAINED, see script 04):")
    for (i in seq_len(nrow(miss))) {
      logline("    ", sprintf("%-38s %5.1f%%", miss$column[i],
                              100 * miss$pct_missing[i]))
    }
  }

  logline("  wrote ", nrow(out), " rows x ", ncol(out), " cols")
  readr::write_csv(out, file.path(PATHS$clean,
                   sprintf("fin_%s_%s.csv", statement, frequency)))
  out
}

cleaned <- FIN_FILES |>
  mutate(data = pmap(list(statement, frequency, file), clean_one))

# ===========================================================================
# Wide panel: the three statements on one row
# ===========================================================================
# full_join, so an income row survives even when its balance sheet record was
# an empty placeholder. Keeping the revenue and losing only the assets suits
# more analyses than discarding the row, and flag columns make it visible.

build_panel <- function(freq) {
  pick <- function(stmt) {
    cleaned |> filter(statement == stmt, frequency == freq) |>
      pull(data) |> pluck(1) |> select(-statement, -frequency)
  }
  shared <- c("fiscal_year", "fiscal_qtr", "fiscal_month", "calendar_aligned",
              "n_periods", "period_index", "complete_panel", "period_gap_days",
              "flag_period_gap")

  panel <- pick("income") |>
    full_join(pick("balance")  |> select(-any_of(shared)),
              by = c("ticker", "period_end"), suffix = c("", "_bs")) |>
    full_join(pick("cashflow") |> select(-any_of(shared)),
              by = c("ticker", "period_end"), suffix = c("", "_cf")) |>
    arrange(ticker, period_end)

  stopifnot(!any(duplicated(panel[c("ticker", "period_end")])))

  dest <- file.path(PATHS$clean, sprintf("fin_panel_%s.csv", freq))
  readr::write_csv(panel, dest)
  logline(""); logline("panel ", freq, ": ", nrow(panel), " rows x ",
          ncol(panel), " cols, ",
          sprintf("%.1f%%", 100 * mean(is.na(panel))), " unreported")
  panel
}

pa <- build_panel("annual")
pq <- build_panel("quarterly")

logline(""); logline(strrep("=", 78)); logline("SUMMARY"); logline(strrep("=", 78))
logline("annual:    ", nrow(pa), " rows, ", n_distinct(pa$ticker), " tickers")
logline("quarterly: ", nrow(pq), " rows, ", n_distinct(pq$ticker), " tickers")
logline("")
logline("Nulls in these files are unreported figures, faithfully preserved.")
logline("For a dense modeling table see script 04, which makes the filling")
logline("and selection decisions explicitly and logs each one.")
logline("")
logline("TWO LIMITATIONS NO SCRIPT CAN FIX:")
logline("1. No ticker has more than 4 periods. Annual gives 4 fiscal years;")
logline("   quarterly gives 4 quarters, i.e. one year. This does not support")
logline("   a two-year per-company forecast.")
logline("2. There is no sector, industry, SIC or country column in this source.")
logline("   Benchmarking an IT services firm against an undifferentiated pool")
logline("   of 4,422 banks, REITs, biotechs and retailers is not a benchmark.")
logline("   A ticker-to-sector mapping has to be acquired separately.")

close(log_con)
