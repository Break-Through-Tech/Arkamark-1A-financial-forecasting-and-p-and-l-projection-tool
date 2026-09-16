# ---------------------------------------------------------------------------
# 02_clean_financials.R
# Cleans the six financial statement CSVs and writes tidy outputs to
# data/clean/. Every rule here is traceable to a finding in
# reports/eda_financials.txt.
#
#   Rscript R/02_clean_financials.R
#
# Outputs:
#   data/clean/fin_<statement>_<frequency>.csv   one per input file
#   data/clean/fin_panel_annual.csv              income + balance + cashflow joined
#   data/clean/fin_panel_quarterly.csv
#   reports/cleaning_log.txt                     what was changed and why
# ---------------------------------------------------------------------------

# Find 00_config.R regardless of the current working directory.
local({
  args <- commandArgs(trailingOnly = FALSE)
  fa <- grep("^--file=", args, value = TRUE)
  here <- if (length(fa) > 0) dirname(sub("^--file=", "", fa[1])) else NULL
  cands <- c(if (!is.null(here)) file.path(here, "00_config.R"),
             "R/00_config.R", "00_config.R", "../R/00_config.R")
  hit <- cands[file.exists(cands)]
  if (length(hit) == 0) {
    stop("Cannot find 00_config.R. Open the repo folder in RStudio, or run:\n",
         "  Rscript R/02_clean_financials.R", call. = FALSE)
  }
  source(hit[1], local = FALSE)
})

log_con <- file(file.path(PATHS$reports, "cleaning_log.txt"), open = "wt")
logline <- function(...) {
  msg <- paste0(...)
  writeLines(msg, log_con)
  message(msg)
}

logline("Arkamark 1A cleaning log - ", format(Sys.time(), "%Y-%m-%d %H:%M"))
logline(strrep("=", 78))

# ===========================================================================
# Cleaning steps
# ===========================================================================

#' Step 1. Structural cleanup.
#' snake_case names, typed date, derived fiscal calendar fields.
clean_structure <- function(df, statement, frequency) {
  df |>
    janitor::clean_names() |>
    rename(ticker = stock, period_end = end_date) |>
    mutate(
      statement     = statement,
      frequency     = frequency,
      fiscal_year   = year(period_end),
      fiscal_month  = month(period_end),
      fiscal_qtr    = quarter(period_end),
      # Off-calendar fiscal year ends are legitimate here (EDU ends in May,
      # DRI in late May). Flag them rather than forcing them onto Dec 31.
      calendar_aligned = fiscal_month == 12L
    ) |>
    relocate(ticker, period_end, statement, frequency,
             fiscal_year, fiscal_qtr, fiscal_month, calendar_aligned)
}

#' Step 2. Drop rows that carry no information.
#' Found 153 such rows in the annual balance sheet, 1 in annual cashflow.
drop_empty <- function(df, label) {
  if (!CFG$drop_empty_rows) return(df)
  keep <- row_information(df) > 0
  n <- sum(!keep)
  if (n > 0) logline("  [", label, "] dropped ", n, " all-zero/all-NA rows")
  df[keep, ]
}

#' Step 3. Resolve duplicate (ticker, period_end) keys.
#' The quarterly files contain 6 such rows. Three pairs are byte-identical;
#' three pairs are a real record paired with a zero-filled stub. Keeping the
#' row with the most populated fields handles both cases correctly.
dedupe_keys <- function(df, label) {
  before <- nrow(df)
  out <- df |>
    mutate(.info = row_information(df)) |>
    arrange(ticker, period_end, desc(.info)) |>
    distinct(ticker, period_end, .keep_all = TRUE) |>
    select(-.info)
  n <- before - nrow(out)
  if (n > 0) logline("  [", label, "] resolved ", n, " duplicate (ticker, period) keys")
  out
}

#' Step 4. Convert placeholder zeros to NA.
#' totalRevenue == 0 appears 983 times in the annual income statement. These
#' are almost certainly unreported rather than genuinely zero, and leaving
#' them as 0 silently poisons every margin you compute downstream.
fix_placeholders <- function(df, label) {
  if (!CFG$zero_revenue_to_na || !"total_revenue" %in% names(df)) return(df)
  n <- sum(df$total_revenue == 0, na.rm = TRUE)
  out <- df |> mutate(total_revenue = if_else(total_revenue == 0, NA_real_, total_revenue))
  if (n > 0) logline("  [", label, "] set ", n, " zero total_revenue values to NA")
  out
}

#' Step 5. Report (and optionally drop) sparse columns.
#' Nothing is dropped unless CFG$drop_sparse is TRUE. Sparsity is not the same
#' as uselessness: research_development is 66% missing because most of these
#' companies genuinely do not report R&D, which is itself a signal.
handle_sparse <- function(df, label) {
  miss <- missing_profile(df) |> filter(pct_missing > CFG$sparse_threshold)
  if (nrow(miss) == 0) return(df)
  logline("  [", label, "] sparse columns (>",
          sprintf("%.0f%%", 100 * CFG$sparse_threshold), " missing): ",
          paste0(miss$column, " ", sprintf("%.0f%%", 100 * miss$pct_missing),
                 collapse = ", "))
  if (CFG$drop_sparse) {
    logline("  [", label, "] dropping them (CFG$drop_sparse = TRUE)")
    df <- df |> select(-any_of(miss$column))
  }
  df
}

#' Step 6. Normalize sign conventions into explicit magnitude columns.
#' In this dataset interest_expense, capital_expenditures and dividends_paid
#' are all stored as negatives. The originals are kept; new *_abs columns make
#' the intent unambiguous when these feed a P&L build-up.
normalize_signs <- function(df) {
  sign_cols <- intersect(
    c("interest_expense", "capital_expenditures", "dividends_paid",
      "repurchase_of_stock"),
    names(df)
  )
  if (length(sign_cols) == 0) return(df)
  df |> mutate(across(all_of(sign_cols), abs, .names = "{.col}_abs"))
}

#' Step 7. Add validation flags instead of deleting suspect rows.
#' Forecasting work needs to know which records failed an accounting identity;
#' it does not need those records silently removed.
add_validation_flags <- function(df, statement) {
  if (statement == "income" && all(c("total_revenue", "cost_of_revenue", "gross_profit") %in% names(df))) {
    df <- df |> mutate(
      flag_gp_identity = abs(total_revenue - cost_of_revenue - gross_profit) > 1000,
      flag_neg_revenue = !is.na(total_revenue) & total_revenue < 0
    )
  }
  if (statement == "balance" && all(c("total_assets", "total_liab", "total_stockholder_equity") %in% names(df))) {
    # Minority interest sits outside total_stockholder_equity in this dataset:
    # including it cuts identity failures from 5,546 to 2,361 on the annual file.
    df <- df |> mutate(
      balance_gap = total_assets -
        (total_liab + total_stockholder_equity + coalesce(minority_interest, 0)),
      flag_bs_identity = abs(balance_gap) > abs(total_assets) * CFG$identity_tol
    )
  }
  df
}

#' Step 8. Panel completeness.
#' Max depth in this dataset is 4 periods per ticker: 4 fiscal years annually,
#' or 4 quarters (one year) quarterly. 143 tickers have fewer than 4 annual
#' periods. Anything modeled on a 2-year horizon needs to know this.
add_panel_flags <- function(df) {
  df |>
    group_by(ticker) |>
    mutate(
      n_periods    = n(),
      period_index = dense_rank(period_end)
    ) |>
    ungroup() |>
    # complete_panel compares each ticker against the deepest panel in the
    # file, so it must be computed after ungrouping.
    mutate(complete_panel = n_periods == max(n_periods, na.rm = TRUE))
}

# ===========================================================================
# Run the pipeline over all six files
# ===========================================================================

clean_one <- function(statement, frequency, file) {
  label <- paste0(statement, "/", frequency)
  logline("")
  logline(strrep("-", 78))
  logline(file)
  logline(strrep("-", 78))

  raw <- read_fin_raw(file)
  logline("  read ", nrow(raw), " rows x ", ncol(raw), " cols")

  out <- raw |>
    clean_structure(statement, frequency) |>
    drop_empty(label) |>
    dedupe_keys(label) |>
    fix_placeholders(label) |>
    handle_sparse(label) |>
    normalize_signs() |>
    add_validation_flags(statement) |>
    add_panel_flags()

  logline("  wrote ", nrow(out), " rows x ", ncol(out), " cols")

  dest <- file.path(PATHS$clean, sprintf("fin_%s_%s.csv", statement, frequency))
  readr::write_csv(out, dest)
  out
}

cleaned <- FIN_FILES |>
  mutate(data = pmap(list(statement, frequency, file), clean_one))

# ===========================================================================
# Build joined panels
# ===========================================================================
# The three statements share the (ticker, period_end) key, so a P&L model can
# work off one wide table. Suffixes keep net_income from colliding between the
# income statement and the cash flow statement.

build_panel <- function(freq) {
  pick <- function(stmt) {
    cleaned |>
      filter(statement == stmt, frequency == freq) |>
      pull(data) |> pluck(1) |>
      select(-statement, -frequency)
  }
  inc <- pick("income")
  bs  <- pick("balance")  |> select(-any_of(c("fiscal_year", "fiscal_qtr", "fiscal_month",
                                              "calendar_aligned", "n_periods",
                                              "period_index", "complete_panel")))
  cf  <- pick("cashflow") |> select(-any_of(c("fiscal_year", "fiscal_qtr", "fiscal_month",
                                              "calendar_aligned", "n_periods",
                                              "period_index", "complete_panel")))

  panel <- inc |>
    full_join(bs, by = c("ticker", "period_end"), suffix = c("", "_bs")) |>
    full_join(cf, by = c("ticker", "period_end"), suffix = c("", "_cf"))

  # Derived P&L ratios, guarded against near-zero denominators.
  panel <- panel |>
    mutate(
      gross_margin     = safe_ratio(gross_profit, total_revenue),
      operating_margin = safe_ratio(operating_income, total_revenue),
      net_margin       = safe_ratio(net_income, total_revenue),
      sga_ratio        = safe_ratio(selling_general_administrative, total_revenue),
      # Pre-tax income crosses zero constantly, so this needs a positive-only
      # floor plus a hard clamp. Without it the annual panel produced an
      # effective tax rate of 1,383 and the quarterly panel one of -4,925.
      effective_tax    = {
        r <- ifelse(is.na(income_before_tax) |
                      income_before_tax < CFG$min_pretax_income,
                    NA_real_,
                    income_tax_expense / income_before_tax)
        ifelse(r < CFG$tax_rate_bounds[1] | r > CFG$tax_rate_bounds[2],
               NA_real_, r)
      }
    ) |>
    # Separate mutate() on purpose: across() resolves its column selection
    # before the current mutate() runs, so it cannot see columns created in
    # that same call. Merging these two blocks throws "column doesn't exist".
    mutate(
      across(c(gross_margin, operating_margin, net_margin, sga_ratio),
             winsorize, .names = "{.col}_w")
    ) |>
    arrange(ticker, period_end)

  dest <- file.path(PATHS$clean, sprintf("fin_panel_%s.csv", freq))
  readr::write_csv(panel, dest)
  logline("")
  logline("panel ", freq, ": ", nrow(panel), " rows x ", ncol(panel), " cols -> ", dest)
  panel
}

panel_annual    <- build_panel("annual")
panel_quarterly <- build_panel("quarterly")

# ===========================================================================
# Closing summary
# ===========================================================================
logline("")
logline(strrep("=", 78))
logline("SUMMARY")
logline(strrep("=", 78))
logline("annual panel:    ", nrow(panel_annual), " rows, ",
        n_distinct(panel_annual$ticker), " tickers, ",
        min(panel_annual$period_end, na.rm = TRUE), " to ",
        max(panel_annual$period_end, na.rm = TRUE))
logline("quarterly panel: ", nrow(panel_quarterly), " rows, ",
        n_distinct(panel_quarterly$ticker), " tickers, ",
        min(panel_quarterly$period_end, na.rm = TRUE), " to ",
        max(panel_quarterly$period_end, na.rm = TRUE))
logline("")
logline("KNOWN LIMITATION: no ticker has more than 4 periods in either file.")
logline("Annual gives 4 fiscal years; quarterly gives 4 quarters, i.e. one year.")
logline("A two-year forward projection built on 4 annual points is extrapolation,")
logline("not time series forecasting. Cross-sectional margin benchmarking is the")
logline("defensible use of this data until real Arkamark history is available.")

close(log_con)

