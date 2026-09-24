# ---------------------------------------------------------------------------
# 05_data_dictionary.R
# DOCUMENTATION LAYER. Emits reports/data_dictionary.md from data/clean/.
#
#   Rscript R/05_data_dictionary.R
#
# WHY THIS SCRIPT EXISTS
# ----------------------
# R/README.md once stated that fin_analysis_annual.csv was "15 columns, zero
# nulls". By 2026-09-17 the file had 37 columns and 8,874 blank cells, because
# script 04 was re-run with the ratio block active and nobody updated the prose.
# The claim was true when written and false two days later.
#
# A hand-maintained description of a machine-generated file drifts the moment
# the file is regenerated. So this description is generated too. Run it after
# script 04 and the dictionary cannot be stale.
#
# Anything in reports/data_dictionary.md is measured, not asserted. Judgment
# calls belong in reports/cleaning_decisions.md, which is written by a person
# and signed by a person.
#
# DO NOT HAND-EDIT reports/data_dictionary.md. Edit this script instead.
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

# ---------------------------------------------------------------------------
# Which layer produced each file, and therefore what a null in it means.
# Keyed by filename prefix, longest match wins.
# ---------------------------------------------------------------------------
LAYER_MAP <- list(
  list(prefix = "fin_analysis",
       layer  = "MODELING (04)",
       nulls  = paste("Only in derived ratios, where a guard declined to divide.",
                      "Every input to a blank ratio is present in the same row."),
       use    = "Margin work, ratios, cross-company comparison."),
  list(prefix = "fin_long",
       layer  = "RESHAPING (03)",
       nulls  = "None by construction. An unreported line item is an absent row.",
       use    = "Grouping, aggregating, pivoting a custom subset."),
  list(prefix = "fin_coverage",
       layer  = "RESHAPING (03)",
       nulls  = "None.",
       use    = "Which line items companies actually report, and how often."),
  list(prefix = "fin_panel",
       layer  = "CLEANING (02)",
       nulls  = paste("Expected and meaningful. A null means the company did not",
                      "report that figure. Do not read a high null rate here as a",
                      "defect in the pipeline."),
       use    = "Building a P&L, and any audit question. Widest column set."),
  list(prefix = "fin_income",
       layer  = "CLEANING (02)",
       nulls  = "Expected. Unreported figures are preserved as nulls.",
       use    = "Auditing a single statement's values."),
  list(prefix = "fin_balance",
       layer  = "CLEANING (02)",
       nulls  = "Expected. Unreported figures are preserved as nulls.",
       use    = "Auditing a single statement's values."),
  list(prefix = "fin_cashflow",
       layer  = "CLEANING (02)",
       nulls  = "Expected. Unreported figures are preserved as nulls.",
       use    = "Auditing a single statement's values.")
)

classify <- function(fname) {
  hits <- Filter(function(m) startsWith(fname, m$prefix), LAYER_MAP)
  if (length(hits) == 0) {
    return(list(layer = "UNCLASSIFIED",
                nulls = "Not described in LAYER_MAP in R/05_data_dictionary.R.",
                use   = "Unknown. Add it to LAYER_MAP."))
  }
  hits[[which.max(vapply(hits, function(m) nchar(m$prefix), integer(1)))]]
}

# ---------------------------------------------------------------------------
# Formatting helpers
# ---------------------------------------------------------------------------

fmt1 <- function(v) {
  if (length(v) != 1 || is.na(v)) return("")
  a <- abs(v)
  if (a >= 1e12) sprintf("%.2fT", v / 1e12)
  else if (a >= 1e9)  sprintf("%.2fB", v / 1e9)
  else if (a >= 1e6)  sprintf("%.2fM", v / 1e6)
  else if (a >= 1e3)  sprintf("%.1fK", v / 1e3)
  else if (a == 0)    "0"
  else sprintf("%.4g", v)
}

pct <- function(x) sprintf("%.1f%%", 100 * x)

# Markdown table cells cannot contain a raw pipe.
esc <- function(s) gsub("|", "\\\\|", as.character(s), fixed = TRUE)

# ---------------------------------------------------------------------------
# Per-column description
# ---------------------------------------------------------------------------

describe_column <- function(x, name) {
  n       <- length(x)
  n_miss  <- sum(is.na(x))
  share   <- if (n > 0) n_miss / n else 0
  present <- x[!is.na(x)]

  if (is.logical(x)) {
    type <- "logical"
    note <- if (length(present) > 0) {
      sprintf("TRUE on %d rows (%s)", sum(present), pct(mean(present)))
    } else "all missing"

  } else if (inherits(x, "Date")) {
    type <- "date"
    note <- if (length(present) > 0) {
      sprintf("%s to %s", min(present), max(present))
    } else "all missing"

  } else if (is.numeric(x)) {
    type <- "numeric"
    note <- if (length(present) > 0) {
      sprintf("min %s / median %s / max %s",
              fmt1(min(present)), fmt1(stats::median(present)), fmt1(max(present)))
    } else "all missing"

  } else {
    type <- "character"
    note <- if (length(present) > 0) {
      u <- unique(present)
      sprintf("%s distinct, e.g. %s",
              format(length(u), big.mark = ","),
              paste(utils::head(u, 2), collapse = ", "))
    } else "all missing"
  }

  data.frame(column = name, type = type, missing = pct(share),
             summary = note, stringsAsFactors = FALSE)
}

# ---------------------------------------------------------------------------
# Emit
# ---------------------------------------------------------------------------

files <- sort(list.files(PATHS$clean, pattern = "\\.csv$", full.names = TRUE))

if (length(files) == 0) {
  stop("No CSVs in ", PATHS$clean,
       ".\nRun scripts 02, 03 and 04 first.", call. = FALSE)
}

out_path <- file.path(PATHS$reports, "data_dictionary.md")
con <- file(out_path, open = "wt")
w <- function(...) writeLines(paste0(...), con)

w("# Data dictionary")
w("")
w("**Generated by `R/05_data_dictionary.R` on ",
  format(Sys.time(), "%Y-%m-%d %H:%M"), ". Do not hand-edit.**")
w("")
w("Every number below was measured from the files in `data/clean/` at the time")
w("this ran. If a figure here disagrees with prose elsewhere in the repo, this")
w("file is right and the prose is stale.")
w("")
w("Judgment calls are not documented here. They live in")
w("[`cleaning_decisions.md`](cleaning_decisions.md), which a person signs.")
w("")
w("## Provenance")
w("")
w(DATA_PROVENANCE)
w("")
w("## Pipeline parameters active at generation time")
w("")
w("These come from `CFG` in `R/00_config.R`. They shape everything below.")
w("")
w("| Parameter | Value |")
w("|---|---|")
flat <- function(v) {
  if (is.null(v)) return("NULL")
  paste(format(v, scientific = FALSE, trim = TRUE), collapse = ", ")
}
for (nm in names(CFG)) w("| `", nm, "` | ", esc(flat(CFG[[nm]])), " |")
w("")

# --- overview table --------------------------------------------------------
w("## Files at a glance")
w("")
w("| File | Layer | Rows | Cols | Blank cells | Rows with any blank |")
w("|---|---|---:|---:|---:|---:|")

tables <- list()

for (f in files) {
  fname <- basename(f)
  df <- readr::read_csv(f, show_col_types = FALSE, progress = FALSE,
                        guess_max = 100000)
  tables[[fname]] <- df

  n_rows  <- nrow(df)
  n_blank <- sum(vapply(df, function(c) sum(is.na(c)), integer(1)))
  rows_any <- if (n_rows > 0) sum(Reduce(`|`, lapply(df, is.na))) else 0L
  meta <- classify(sub("\\.csv$", "", fname))

  w("| `", fname, "` | ", meta$layer, " | ",
    format(n_rows, big.mark = ","), " | ", ncol(df), " | ",
    format(n_blank, big.mark = ","), " | ",
    format(rows_any, big.mark = ","), " (",
    if (n_rows > 0) pct(rows_any / n_rows) else "0.0%", ") |")
}

w("")
w("> A high blank rate in a CLEANING (02) file is correct behaviour, not a")
w("> defect. Those files preserve unreported figures as nulls on purpose.")
w("> Use a MODELING (04) file to fit anything.")
w("")

# --- per file --------------------------------------------------------------
w("---")
w("")
w("## Files in detail")

for (fname in names(tables)) {
  df   <- tables[[fname]]
  meta <- classify(sub("\\.csv$", "", fname))

  w("")
  w("### `", fname, "`")
  w("")
  w("- **Layer:** ", meta$layer)
  w("- **Use it for:** ", meta$use)
  w("- **What a null means here:** ", meta$nulls)
  w("- **Shape:** ", format(nrow(df), big.mark = ","), " rows x ",
    ncol(df), " columns")

  if ("ticker" %in% names(df)) {
    w("- **Tickers:** ", format(length(unique(df$ticker)), big.mark = ","))
  }
  if ("period_end" %in% names(df) && inherits(df$period_end, "Date")) {
    pe <- df$period_end[!is.na(df$period_end)]
    if (length(pe) > 0) w("- **Period range:** ", min(pe), " to ", max(pe))
  }

  # Columns carrying nulls, called out before the full table.
  miss <- vapply(df, function(c) mean(is.na(c)), numeric(1))
  nulls <- sort(miss[miss > 0], decreasing = TRUE)
  w("")
  if (length(nulls) == 0) {
    w("**No nulls in any column.**")
  } else {
    w("**Columns carrying nulls (", length(nulls), " of ", ncol(df), "):** ",
      paste0("`", names(nulls), "` ", pct(nulls), collapse = ", "))
  }

  w("")
  w("| Column | Type | Missing | Summary |")
  w("|---|---|---:|---|")
  for (nm in names(df)) {
    d <- describe_column(df[[nm]], nm)
    w("| `", d$column, "` | ", d$type, " | ", d$missing, " | ",
      esc(d$summary), " |")
  }
}

w("")
w("---")
w("")
w("Regenerate with `Rscript R/05_data_dictionary.R` after any change to")
w("scripts 02, 03 or 04. If you edited this file by hand, your edit is gone.")

close(con)
message("Wrote ", out_path, " (", length(files), " files described)")

