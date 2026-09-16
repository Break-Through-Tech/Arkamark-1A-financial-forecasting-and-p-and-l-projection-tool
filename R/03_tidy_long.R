# ---------------------------------------------------------------------------
# 03_tidy_long.R
# RESHAPING LAYER. Same information as script 02, no NAs anywhere.
#
#   Rscript R/03_tidy_long.R
#
# THE POINT OF THIS SCRIPT
# ------------------------
# The wide panel from script 02 is 19.7% null, and that number caused three
# rounds of argument about what to fill and what to drop. The argument was
# misplaced. The nullity is an artifact of the LAYOUT, not a defect in the data.
#
# A wide table forces every company to have a column for every line item any
# company reports. A staffing firm has no inventory, so it gets an inventory
# cell, and that cell has to hold something. NA is the honest answer and it is
# also useless to most tools.
#
# In long format the problem does not exist. One row per reported figure:
#
#   ticker  period_end  statement  line_item      value
#   ACN     2019-08-31  income     total_revenue  43215000000
#   ACN     2019-08-31  income     gross_profit   13040000000
#
# An unreported line item is simply an absent row. There is nothing to impute
# and nothing to drop. This is the faithful representation of ragged reporting,
# and it is the right input for anything that groups, joins, or aggregates.
#
# Use this file when you want to:
#   - count how many companies report a given line item
#   - compute a statistic per line item without deciding what absence means
#   - join against a sector mapping once you have one
#   - pivot to exactly the wide subset one analysis needs, rather than all of it
#
# Outputs:
#   data/clean/fin_long_annual.csv
#   data/clean/fin_long_quarterly.csv
#   data/clean/fin_coverage.csv        reporting rate per line item
#   reports/tidy_long_log.txt
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

log_con <- file(file.path(PATHS$reports, "tidy_long_log.txt"), open = "wt")
logline <- function(...) { m <- paste0(...); writeLines(m, log_con); message(m) }

logline("Tidy long reshape - ", format(Sys.time(), "%Y-%m-%d %H:%M"))
logline(strrep("=", 78))

# ---------------------------------------------------------------------------

to_long <- function(freq) {
  parts <- FIN_FILES |>
    filter(frequency == freq) |>
    pull(statement) |>
    map(function(stmt) {
      src <- file.path(PATHS$clean, sprintf("fin_%s_%s.csv", stmt, freq))
      if (!file.exists(src)) {
        stop("Missing ", basename(src),
             ". Run Rscript R/02_clean_financials.R first.", call. = FALSE)
      }
      df <- read_csv(src, show_col_types = FALSE, progress = FALSE)
      meas <- measure_cols(df)

      df |>
        select(ticker, period_end, fiscal_year, statement, all_of(meas)) |>
        pivot_longer(all_of(meas), names_to = "line_item", values_to = "value") |>
        # This single filter is what makes the format NA-free. An unreported
        # figure becomes an absent row, which is what it actually is.
        filter(!is.na(value))
    })

  long <- bind_rows(parts) |> arrange(ticker, period_end, statement, line_item)

  stopifnot(sum(is.na(long$value)) == 0)

  logline("")
  logline(freq, ":")
  logline("  ", nrow(long), " reported figures")
  logline("  ", n_distinct(long$ticker), " tickers x ",
          n_distinct(long$line_item), " line items x ",
          n_distinct(long$period_end), " period ends")
  logline("  NAs: 0 (verified)")

  # What a wide layout of the same information would have cost, for contrast.
  cells <- n_distinct(long$ticker) * n_distinct(long$line_item) *
           4  # max periods per ticker in this source
  logline("  a fully wide layout would need ~", format(cells, big.mark = ","),
          " cells to hold ", format(nrow(long), big.mark = ","), " figures")

  dest <- file.path(PATHS$clean, sprintf("fin_long_%s.csv", freq))
  write_csv(long, dest)
  logline("  wrote ", basename(dest))
  long
}

la <- to_long("annual")
lq <- to_long("quarterly")

# ---------------------------------------------------------------------------
# Coverage table: how many companies actually report each line item.
# ---------------------------------------------------------------------------
# This replaces the "which columns are too sparse to keep" argument with a
# number, per line item, that anyone can filter on for their own analysis
# rather than inheriting a threshold someone else picked.

coverage <- bind_rows(
  la |> mutate(frequency = "annual"),
  lq |> mutate(frequency = "quarterly")
) |>
  group_by(frequency, statement, line_item) |>
  summarise(
    n_reported     = n(),
    n_tickers      = n_distinct(ticker),
    n_nonzero      = sum(value != 0),
    pct_nonzero    = n_nonzero / n(),
    median_value   = median(value),
    .groups = "drop"
  ) |>
  group_by(frequency) |>
  mutate(pct_of_rows = n_reported / max(n_reported)) |>
  ungroup() |>
  arrange(frequency, statement, desc(pct_of_rows))

write_csv(coverage, file.path(PATHS$clean, "fin_coverage.csv"))

logline("")
logline(strrep("=", 78))
logline("COVERAGE: least-reported line items (annual)")
logline(strrep("=", 78))
worst <- coverage |> filter(frequency == "annual") |>
  arrange(pct_of_rows) |> head(12)
for (i in seq_len(nrow(worst))) {
  logline("  ", sprintf("%-36s reported %5.1f%% of rows, %5.1f%% non-zero",
                        worst$line_item[i],
                        100 * worst$pct_of_rows[i],
                        100 * worst$pct_nonzero[i]))
}

logline("")
logline("Read pct_of_rows as a reporting rate, not a defect. research_development")
logline("is low because most of these companies do no R&D, which is a fact about")
logline("them rather than a gap in the data.")
logline("")
logline("To get a wide table for one specific analysis, pivot only what you need:")
logline("")
logline("  read_csv('data/clean/fin_long_annual.csv') |>")
logline("    filter(line_item %in% c('total_revenue','gross_profit')) |>")
logline("    pivot_wider(names_from = line_item, values_from = value) |>")
logline("    drop_na()")
logline("")
logline("That yields a dense table with no filling, because you chose two")
logline("columns that companies actually report instead of all 40.")

close(log_con)
