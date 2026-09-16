# ---------------------------------------------------------------------------
# 00_config.R
# Shared paths, packages, constants, and helpers for the Arkamark 1A pipeline.
# Source this at the top of every other script:  source("R/00_config.R")
# ---------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(purrr)
  library(lubridate)
  library(janitor)
})

# --- paths -----------------------------------------------------------------
# Paths are resolved against the repo root, which is found from the location of
# this file. That means it does not matter what your working directory is:
# the repo root, the R/ folder, or anywhere else all behave the same.

.locate_self <- function() {
  # 1. Rscript passes the script path as --file=
  args <- commandArgs(trailingOnly = FALSE)
  fa <- grep("^--file=", args, value = TRUE)
  if (length(fa) > 0) {
    p <- file.path(dirname(sub("^--file=", "", fa[1])), "00_config.R")
    if (file.exists(p)) return(normalizePath(p))
  }
  # 2. source() records the file being sourced in a frame's `ofile`
  for (i in seq_len(sys.nframe())) {
    o <- sys.frame(i)$ofile
    if (!is.null(o) && nzchar(o)) return(normalizePath(o))
  }
  # 3. Fall back to searching outward from the working directory
  for (p in c("R/00_config.R", "00_config.R", "../R/00_config.R")) {
    if (file.exists(p)) return(normalizePath(p))
  }
  stop("Cannot locate 00_config.R. Run scripts from the repo root:\n",
       "  Rscript R/01_eda_financials.R", call. = FALSE)
}

ROOT <- dirname(dirname(.locate_self()))

PATHS <- list(
  raw_fin      = file.path(ROOT, "data"),           # the 6 financial CSVs
  raw_favorita = file.path(ROOT, "data", "favorita"), # Favorita CSVs, when added
  clean        = file.path(ROOT, "data", "clean"),  # cleaned output
  reports      = file.path(ROOT, "reports")         # EDA text + figures
)

invisible(lapply(PATHS[c("clean", "reports")], dir.create,
                 recursive = TRUE, showWarnings = FALSE))

message("Repo root: ", ROOT)

# --- financial statement file map ------------------------------------------
FIN_FILES <- tibble::tribble(
  ~statement,  ~frequency,   ~file,
  "income",    "annual",     "incomeStatementHistory_annually.csv",
  "income",    "quarterly",  "incomeStatementHistory_quarterly.csv",
  "balance",   "annual",     "balanceSheetHistory_annually.csv",
  "balance",   "quarterly",  "balanceSheetHistory_quarterly.csv",
  "cashflow",  "annual",     "cashflowStatement_annually.csv",
  "cashflow",  "quarterly",  "cashflowStatement_quarterly.csv"
)

# --- cleaning parameters ---------------------------------------------------
# These are the knobs. Change them here, not inside the cleaning functions,
# so every decision made about the data is visible in one place.

CFG <- list(
  # Columns missing more than this share of rows get flagged in the report.
  # They are NOT dropped automatically; see DROP_SPARSE below.
  sparse_threshold = 0.65,

  # Set TRUE to actually drop the sparse columns from the cleaned output.
  # Keep FALSE while exploring so you can see what you would be throwing away.
  drop_sparse = FALSE,

  # Rows where every numeric field is 0 or NA are placeholder records with no
  # information. 153 such rows exist in the annual balance sheet.
  drop_empty_rows = TRUE,

  # totalRevenue == 0 is used as a "not reported" placeholder in this dataset
  # (983 annual rows). A real company with genuinely zero revenue is rare
  # enough that treating these as NA is the safer default.
  zero_revenue_to_na = TRUE,

  # Relative tolerance for the accounting identity checks.
  identity_tol = 0.001,

  # Ratios are only computed when the denominator exceeds this, to stop
  # near-zero revenue from producing margins in the thousands.
  min_denominator = 1e6,

  # Winsorize derived ratios at these quantiles. Set to NULL to skip.
  winsor_probs = c(0.01, 0.99)
)

# --- helpers ---------------------------------------------------------------

#' Read one raw financial CSV with an explicit, stable column spec.
#' stock and endDate are read as character/Date; everything else as double.
read_fin_raw <- function(file) {
  readr::read_csv(
    file.path(PATHS$raw_fin, file),
    col_types = readr::cols(
      stock   = readr::col_character(),
      endDate = readr::col_date(format = "%Y-%m-%d"),
      .default = readr::col_double()
    ),
    progress = FALSE
  )
}

#' Share of missing values per column, descending.
missing_profile <- function(df) {
  df |>
    summarise(across(everything(), ~ mean(is.na(.x)))) |>
    pivot_longer(everything(), names_to = "column", values_to = "pct_missing") |>
    arrange(desc(pct_missing))
}

#' Safe ratio: returns NA when the denominator is missing or too small to
#' produce a meaningful percentage.
safe_ratio <- function(numerator, denominator, min_denom = CFG$min_denominator) {
  ifelse(is.na(denominator) | abs(denominator) < min_denom,
         NA_real_,
         numerator / denominator)
}

#' Clamp a numeric vector to its own empirical quantiles.
winsorize <- function(x, probs = CFG$winsor_probs) {
  if (is.null(probs)) return(x)
  lims <- quantile(x, probs = probs, na.rm = TRUE, names = FALSE)
  pmin(pmax(x, lims[1]), lims[2])
}

#' Count of non-missing, non-zero numeric fields in each row.
#' Used to pick the better row when a (stock, period) key is duplicated.
row_information <- function(df) {
  num <- df |> select(where(is.numeric))
  rowSums(!is.na(num) & num != 0)
}

#' Trailing rolling mean over `k` observations, base R only so the pipeline
#' does not depend on zoo or slider. Returns NA until `k` values are available.
roll_mean <- function(x, k) {
  n <- length(x)
  if (n < k) return(rep(NA_real_, n))
  cs  <- cumsum(ifelse(is.na(x), 0, x))
  out <- rep(NA_real_, n)
  out[k:n] <- (cs[k:n] - c(0, cs[seq_len(n - k)])) / k
  out
}

log_step <- function(...) {
  message(format(Sys.time(), "[%H:%M:%S] "), ...)
}

