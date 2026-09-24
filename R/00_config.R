# ---------------------------------------------------------------------------
# 00_config.R
# Shared paths, packages, parameters, and helpers.
# Source this at the top of every other script.
#
# All parameters live in the single CFG list, grouped by which layer of the
# pipeline uses them.
#
# LAYER BOUNDARY, READ THIS BEFORE EDITING
# ----------------------------------------
#   CLEANING (script 02)  Makes the data faithfully represent reality.
#                         Types, keys, validity, demonstrable errors.
#                         Imputes NOTHING. Drops no columns. Nulls stay null,
#                         because an unreported figure is a fact about the data.
#
#   RESHAPING (script 03) Same information, long format. No NAs exist here at
#                         all: an unreported line item is an absent row.
#
#   MODELING (script 04)  Imputation, column selection, winsorizing, features.
#                         Every one of these is a judgment call, so they live
#                         there, off by default, and each is logged.
#
# Putting a modeling choice inside a file called "clean" hides it from everyone
# downstream. That is the one rule not to break.
# ---------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(readr); library(dplyr); library(tidyr); library(stringr)
  library(purrr); library(lubridate); library(janitor)
})

# ---------------------------------------------------------------------------
# DATA PROVENANCE. Read this before drawing any conclusion from these outputs.
# ---------------------------------------------------------------------------
# This pipeline does NOT process Arkamark data. Arkamark has provided no
# proprietary data. The six source CSVs are a public Kaggle dataset of filed
# financial statements for roughly 4,400 listed companies, used as a stand-in.
#
# The data is real, not synthetic. The tickers are actual companies (ACN is
# Accenture, AZO is AutoZone, IVC is Invacare) and the figures are their real
# filings. So findings from it are true statements about those companies.
#
# They are not statements about Arkamark. Any margin, ratio or trend produced
# here describes a pool of unrelated public companies, and carries over to
# Arkamark only as far as someone can argue those companies are comparable.
#
# State this on any chart, slide or README built from these outputs.
# ---------------------------------------------------------------------------
DATA_PROVENANCE <- paste(
  "SOURCE: public Kaggle dataset, ~4,400 listed companies' filed statements.",
  "NOT Arkamark data. Real figures, wrong companies. Substitute, not synthetic."
)

# --- repo root, resolved from this file's own location ----------------------
.locate_self <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  fa <- grep("^--file=", args, value = TRUE)
  if (length(fa) > 0) {
    p <- file.path(dirname(sub("^--file=", "", fa[1])), "00_config.R")
    if (file.exists(p)) return(normalizePath(p))
  }
  for (i in seq_len(sys.nframe())) {
    o <- sys.frame(i)$ofile
    if (!is.null(o) && nzchar(o)) return(normalizePath(o))
  }
  for (p in c("R/00_config.R", "00_config.R", "../R/00_config.R")) {
    if (file.exists(p)) return(normalizePath(p))
  }
  stop("Cannot locate 00_config.R. Run from the repo root.", call. = FALSE)
}

ROOT <- dirname(dirname(.locate_self()))

PATHS <- list(
  raw_fin = file.path(ROOT, "data"),              # where the 6 source CSVs live
  clean   = file.path(ROOT, "data", "clean"),
  reports = file.path(ROOT, "reports")
)
invisible(lapply(PATHS[c("clean", "reports")], dir.create,
                 recursive = TRUE, showWarnings = FALSE))

# Raw files have lived in both data/ and data/raw/ during this project, so
# look in both rather than depending on one.
RAW_DIRS <- c(PATHS$raw_fin, file.path(ROOT, "data", "raw"))

find_raw <- function(file) {
  hits <- file.path(RAW_DIRS, file)
  hit  <- hits[file.exists(hits)]
  if (length(hit) == 0) {
    stop("Cannot find raw file '", file, "' in:\n  ",
         paste(RAW_DIRS, collapse = "\n  "),
         "\n\nIf you switched to a branch that predates the data commit, run:\n",
         "  git checkout main -- data/", call. = FALSE)
  }
  hit[1]
}

message("Repo root: ", ROOT)

# --- statement file map ----------------------------------------------------
FIN_FILES <- tibble::tribble(
  ~statement,  ~frequency,   ~file,
  "income",    "annual",     "incomeStatementHistory_annually.csv",
  "income",    "quarterly",  "incomeStatementHistory_quarterly.csv",
  "balance",   "annual",     "balanceSheetHistory_annually.csv",
  "balance",   "quarterly",  "balanceSheetHistory_quarterly.csv",
  "cashflow",  "annual",     "cashflowStatement_annually.csv",
  "cashflow",  "quarterly",  "cashflowStatement_quarterly.csv"
)

# ---------------------------------------------------------------------------
# CFG: every tunable parameter in the pipeline.
# ---------------------------------------------------------------------------
CFG <- list(

  # === CLEANING (scripts 01 and 02) ======================================
  # These govern reporting, validity, and error detection. None of them
  # impute or alter a reported value.

  # Reporting threshold for the EDA sparse-column callout in script 01.
  sparse_threshold = 0.65,

  # Script 02 no longer drops columns for sparsity at any setting; see
  # reports/cleaning_decisions.md. Retained so script 01's report can flag
  # them, and so this rename does not silently change behavior.
  drop_sparse = FALSE,

  # A row whose every financial measure is 0 or NA is not an observation of a
  # company-period. It is an empty record. 343 of these exist.
  drop_empty_rows = TRUE,

  # Relative tolerance for accounting identity checks.
  identity_tol = 0.001,

  # Expected days between consecutive periods, used to detect rows whose
  # frequency label is wrong. 49 "annual" pairs sit outside the annual window,
  # one only 31 days apart.
  period_days = list(annual = c(330, 400), quarterly = c(80, 100)),

  # Revenue below this is implausible for a listed company and usually signals
  # a unit error or a shell. Flagged, never dropped.
  implausible_revenue = 1e6,

  # Revenue recorded as exactly 0 is a "not reported" placeholder in this
  # source (983 annual rows, 1,111 quarterly). Script 02 only FLAGS it, via
  # flag_zero_revenue, because converting to NA is an interpretation.
  #
  # This parameter is read by script 04 ONLY, where that interpretation is
  # applied and logged. TRUE because a listed company with exactly zero revenue
  # is implausible, and leaving the 0 in place admits rows whose every margin is
  # meaningless into the modeling table.
  zero_revenue_to_na = TRUE,

  # === MODELING (script 04 only) =========================================
  # Every field below encodes a judgment call. All default to the
  # conservative option so nothing is silently applied.

  impute_absent_as_zero = FALSE,  # fill not-applicable line items with 0
  min_nonzero_share     = 0.25,   # below this, a filled column is a constant
  winsor_probs          = NULL,   # e.g. c(0.01, 0.99); NULL = no winsorizing
  min_denominator       = 1e6,    # floor for ratio denominators
  min_pretax_income     = 1e7,    # floor for effective tax rate
  tax_rate_bounds       = c(-0.5, 1.0)
)

# --- helpers ---------------------------------------------------------------

read_fin_raw <- function(file) {
  readr::read_csv(
    find_raw(file),
    col_types = readr::cols(
      stock    = readr::col_character(),
      endDate  = readr::col_date(format = "%Y-%m-%d"),
      .default = readr::col_double()
    ),
    progress = FALSE
  )
}

#' Identifier and derived-calendar columns. Never financial measures, so they
#' must be excluded from any "does this row contain data" test. Counting
#' fiscal_year as information is what defeated the empty-row check before.
ID_COLS <- c("ticker", "period_end", "statement", "frequency",
             "fiscal_year", "fiscal_qtr", "fiscal_month",
             "calendar_aligned", "period_gap_days", "period_index",
             "n_periods", "balance_gap")

#' The financial measure columns of a table: everything that is not an
#' identifier, a derived calendar field, or a flag.
measure_cols <- function(df) {
  setdiff(names(df)[vapply(df, is.numeric, logical(1))], ID_COLS) |>
    setdiff(grep("^flag_", names(df), value = TRUE))
}

#' Count of populated (non-missing, non-zero) financial measures per row.
row_information <- function(df) {
  m <- measure_cols(df)
  if (length(m) == 0) return(rep(0L, nrow(df)))
  num <- df[m]
  rowSums(!is.na(num) & num != 0)
}

missing_profile <- function(df) {
  df |>
    summarise(across(everything(), ~ mean(is.na(.x)))) |>
    pivot_longer(everything(), names_to = "column", values_to = "pct_missing") |>
    arrange(desc(pct_missing))
}

#' Ratio guarded against a denominator too small to produce a meaningful
#' percentage. A MODELING helper: never called from script 02.
safe_ratio <- function(numerator, denominator, min_denom = CFG$min_denominator) {
  ifelse(is.na(denominator) | abs(denominator) < min_denom,
         NA_real_, numerator / denominator)
}

winsorize <- function(x, probs = CFG$winsor_probs) {
  if (is.null(probs)) return(x)
  lims <- quantile(x, probs = probs, na.rm = TRUE, names = FALSE)
  pmin(pmax(x, lims[1]), lims[2])
}

log_step <- function(...) message(format(Sys.time(), "[%H:%M:%S] "), ...)

