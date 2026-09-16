# ---------------------------------------------------------------------------
# 01_eda_financials.R
# Profiles the six raw financial statement CSVs and writes a text report to
# reports/eda_financials.txt. Run this before cleaning, and re-run it after
# you change anything upstream.
#
#   Rscript R/01_eda_financials.R          (from the repo root)
#   Rscript 01_eda_financials.R            (from inside R/ - also works)
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
         "  Rscript R/01_eda_financials.R", call. = FALSE)
  }
  source(hit[1], local = FALSE)
})

out_path <- file.path(PATHS$reports, "eda_financials.txt")
con <- file(out_path, open = "wt")
say <- function(...) writeLines(paste0(...), con)
rule <- function(char = "-") say(strrep(char, 78))

say("Arkamark 1A - EDA on raw financial statement files")
say("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M"))

# ---------------------------------------------------------------------------
# 1. Per-file profile
# ---------------------------------------------------------------------------
profiles <- FIN_FILES |>
  mutate(data = map(file, read_fin_raw))

for (i in seq_len(nrow(profiles))) {
  row <- profiles[i, ]
  df  <- row$data[[1]]

  rule("=")
  say(row$file, "  (", row$statement, " / ", row$frequency, ")")
  rule("=")
  say("rows: ", nrow(df), "   columns: ", ncol(df))
  say("distinct tickers: ", n_distinct(df$stock))
  say("date range: ", min(df$endDate, na.rm = TRUE), " to ",
      max(df$endDate, na.rm = TRUE))
  say("unparsed dates: ", sum(is.na(df$endDate)))

  # --- key integrity -------------------------------------------------------
  dup_keys <- df |> count(stock, endDate) |> filter(n > 1)
  say("duplicate (stock, endDate) keys: ", nrow(dup_keys))
  if (nrow(dup_keys) > 0) {
    say("  affected tickers: ", paste(dup_keys$stock, collapse = ", "))
  }
  say("fully identical duplicate rows: ", sum(duplicated(df)))

  # --- panel depth ---------------------------------------------------------
  depth <- df |> count(stock, name = "n_periods") |> count(n_periods)
  say("periods per ticker:")
  for (j in seq_len(nrow(depth))) {
    say("  ", depth$n_periods[j], " period(s): ", depth$n[j], " tickers")
  }

  # --- fiscal calendar -----------------------------------------------------
  month_mix <- df |>
    mutate(m = month(endDate)) |>
    count(m) |>
    arrange(desc(n))
  say("period-end months (top 4): ",
      paste0(month.abb[month_mix$m[1:4]], "=", month_mix$n[1:4], collapse = ", "))

  # --- missingness ---------------------------------------------------------
  miss <- missing_profile(df) |> filter(pct_missing > 0)
  say("columns with any missing values: ", nrow(miss))
  sparse <- miss |> filter(pct_missing > CFG$sparse_threshold)
  if (nrow(sparse) > 0) {
    say("columns above the ", sprintf("%.0f%%", 100 * CFG$sparse_threshold),
        " sparse threshold:")
    for (j in seq_len(nrow(sparse))) {
      say("  ", sprintf("%-38s %5.1f%%", sparse$column[j],
                        100 * sparse$pct_missing[j]))
    }
  }
  say("full missingness table:")
  for (j in seq_len(nrow(miss))) {
    say("  ", sprintf("%-38s %5.1f%%", miss$column[j], 100 * miss$pct_missing[j]))
  }

  # --- empty rows ----------------------------------------------------------
  num <- df |> select(where(is.numeric))
  empty_rows <- sum(rowSums(!is.na(num) & num != 0) == 0)
  say("rows where every numeric field is 0 or NA: ", empty_rows)

  say("")
}

# ---------------------------------------------------------------------------
# 2. Cross-file checks
# ---------------------------------------------------------------------------
rule("=")
say("CROSS-FILE CHECKS")
rule("=")

get_df <- function(stmt, freq) {
  profiles |> filter(statement == stmt, frequency == freq) |> pull(data) |> pluck(1)
}

for (freq in c("annual", "quarterly")) {
  inc <- get_df("income", freq)
  bs  <- get_df("balance", freq)
  cf  <- get_df("cashflow", freq)

  say("")
  say("--- ", freq, " ---")
  say("ticker sets identical across the three statements: ",
      identical(sort(unique(inc$stock)), sort(unique(bs$stock))) &&
      identical(sort(unique(inc$stock)), sort(unique(cf$stock))))
  say("income-only tickers: ", length(setdiff(inc$stock, bs$stock)))
  say("balance-only tickers: ", length(setdiff(bs$stock, inc$stock)))

  # Gross profit identity: totalRevenue - costOfRevenue = grossProfit
  gp_gap <- with(inc, totalRevenue - costOfRevenue - grossProfit)
  say("grossProfit identity violations (>$1k): ",
      sum(abs(gp_gap) > 1000, na.rm = TRUE), " of ", sum(!is.na(gp_gap)))

  # Balance sheet identity, with and without minority interest
  tol  <- abs(bs$totalAssets) * CFG$identity_tol
  gap1 <- abs(bs$totalAssets - (bs$totalLiab + bs$totalStockholderEquity))
  gap2 <- abs(bs$totalAssets - (bs$totalLiab + bs$totalStockholderEquity +
                                coalesce(bs$minorityInterest, 0)))
  say("A = L + E violations: ", sum(gap1 > tol, na.rm = TRUE),
      "  |  A = L + E + MI violations: ", sum(gap2 > tol, na.rm = TRUE),
      "  of ", sum(!is.na(gap1)))

  # Revenue placeholders
  say("totalRevenue == 0: ", sum(inc$totalRevenue == 0, na.rm = TRUE),
      "  |  totalRevenue < 0: ", sum(inc$totalRevenue < 0, na.rm = TRUE))

  # Sign conventions worth knowing before you build a P&L
  sign_report <- function(x, label) {
    say(sprintf("  %-32s negative: %6d   positive: %6d",
                label, sum(x < 0, na.rm = TRUE), sum(x > 0, na.rm = TRUE)))
  }
  say("sign conventions:")
  sign_report(inc$interestExpense, "interestExpense")
  sign_report(cf$capitalExpenditures, "capitalExpenditures")
  sign_report(cf$dividendsPaid, "dividendsPaid")

  # ebit vs operatingIncome: the dataset often copies one into the other
  say("rows where ebit != operatingIncome: ",
      sum(inc$ebit != inc$operatingIncome, na.rm = TRUE), " of ", nrow(inc))

  # Margin distribution, unguarded, to show why safe_ratio() exists
  gm_raw <- inc$grossProfit / inc$totalRevenue
  gm_raw <- gm_raw[is.finite(gm_raw)]
  qs <- quantile(gm_raw, c(0, .01, .5, .99, 1), na.rm = TRUE)
  say("raw gross margin quantiles (0/1/50/99/100): ",
      paste(sprintf("%.2f", qs), collapse = "  "))
  say("raw gross margin outside [-1, 1]: ", sum(gm_raw < -1 | gm_raw > 1))
}

close(con)
message("Wrote ", out_path)
