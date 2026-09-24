# ---------------------------------------------------------------------------
# 04_analysis_prep.R
# MODELING LAYER. Every decision in this file is a judgment call.
#
#   Rscript R/04_analysis_prep.R
#
# This script is named for what it is. It is not cleaning. It selects columns,
# drops rows, optionally fills values, and derives ratios. Each of those is a
# choice that changes results, so each is a parameter in CFG (see 00_config.R),
# each defaults to the conservative option, and each is logged on every run.
#
# THE DEFAULT PATH INVENTS NOTHING
# --------------------------------
# An earlier version of this script filled 168,102 cells with zero to make the
# table dense. That was never necessary. Density comes from choosing columns
# companies actually report, not from filling columns they do not.
#
# Selecting the 15 core aggregates every operating company reports, then keeping
# complete rows, yields 15,732 annual rows with zero nulls and zero imputed
# values. The zero-filling only ever existed to carry 25 optional line items
# that a P&L projection does not need.
#
# So: CFG$impute_absent_as_zero defaults to FALSE. Turning it on adds those
# optional columns, and the log will tell you exactly what it cost.
#
# Outputs:
#   data/clean/fin_analysis_<freq>.csv           all complete observations
#   data/clean/fin_analysis_<freq>_balanced.csv  tickers present in all periods
#   reports/analysis_prep_log.txt
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

log_con <- file(file.path(PATHS$reports, "analysis_prep_log.txt"), open = "wt")
logline <- function(...) { m <- paste0(...); writeLines(m, log_con); message(m) }

logline("Analysis prep - ", format(Sys.time(), "%Y-%m-%d %H:%M"))
logline(strrep("=", 78))
logline("MODELING LAYER. Decisions active on this run:")
logline("  zero_revenue_to_na    : ", CFG$zero_revenue_to_na)
logline("  impute_absent_as_zero : ", CFG$impute_absent_as_zero)
logline("  min_nonzero_share     : ", CFG$min_nonzero_share)
logline("  winsor_probs          : ",
        if (is.null(CFG$winsor_probs)) "NULL (no winsorizing)"
        else paste(CFG$winsor_probs, collapse = ", "))
fmt_cfg <- function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)
logline("  min_denominator       : ", fmt_cfg(CFG$min_denominator),
        "  (balance-sheet ratios)")
logline("  min_revenue_denom     : ", fmt_cfg(CFG$min_revenue_denom),
        "  (margins)")
logline("  min_pretax_income     : ", fmt_cfg(CFG$min_pretax_income),
        "  (effective tax rate)")
logline("  tax_rate_bounds       : ",
        paste(CFG$tax_rate_bounds, collapse = " to "))
logline(strrep("=", 78))

# ---------------------------------------------------------------------------
# Column contracts
# ---------------------------------------------------------------------------
# CORE: aggregates every operating company reports. A gap here is missing
# information, never a structural zero, so these are never filled and a row
# missing any of them is dropped.
CORE <- c(
  "total_revenue", "cost_of_revenue", "gross_profit", "operating_income",
  "net_income", "total_operating_expenses", "income_before_tax",
  # income_tax_expense is 0% missing in the source, so it is a core aggregate
  # rather than an optional line item.
  "income_tax_expense",
  "total_assets", "total_liab", "total_stockholder_equity",
  "total_current_assets", "total_current_liabilities", "cash",
  "total_cash_from_operating_activities"
)

# OPTIONAL: line items a company may legitimately not have. Included only when
# CFG$impute_absent_as_zero is TRUE, and then only if the filled column keeps
# enough non-zero variation to carry information.
OPTIONAL <- c(
  "selling_general_administrative", "interest_expense",
  "depreciation", "capital_expenditures", "accounts_payable", "net_receivables",
  "inventory", "good_will", "intangible_assets", "treasury_stock",
  "long_term_debt", "issuance_of_stock", "repurchase_of_stock",
  "dividends_paid", "change_to_inventory", "effect_of_exchange_rate",
  "long_term_investments", "deferred_long_term_asset_charges",
  "short_long_term_debt", "minority_interest", "other_operating_expenses",
  "research_development", "short_term_investments", "deferred_long_term_liab",
  "discontinued_operations"
)

KEEP_IDS <- c("ticker", "period_end", "fiscal_year", "fiscal_qtr",
              "calendar_aligned", "n_periods")

# Error flags from script 02 are carried through, not dropped. Script 02 does
# the work of locating bad records; discarding the labels here would hand the
# modeling table 21 negative-revenue rows, 418 micro-caps and 3 rows where
# gross profit exceeds revenue with no way to find them again.
#
# They are carried rather than filtered because whether a shell company or an
# insolvent balance sheet belongs in a given sample depends on the question.
# Filter on them yourself, e.g.
#   filter(!flag_negative_revenue, !flag_implausible_revenue)
#
# Two of script 02's flags are deliberately NOT carried, because they are
# always FALSE by the time this table is built:
#   flag_zero_revenue        Decision 1 reinterprets these and Decision 2
#                            drops them, so 0 of 983 survive. The flag still
#                            matters in fin_panel_*, where it is the evidence
#                            for why Decision 1 exists.
#   flag_nonpositive_assets  No row in the source has assets <= 0.
# Carrying an all-FALSE column would only imply a check that found nothing.
KEEP_FLAGS <- c("flag_negative_revenue", "flag_negative_cogs",
                "flag_gp_exceeds_rev", "flag_gp_identity",
                "flag_implausible_revenue",
                "flag_bs_identity", "flag_negative_equity",
                "flag_period_gap")

build <- function(freq) {
  src <- file.path(PATHS$clean, sprintf("fin_panel_%s.csv", freq))
  if (!file.exists(src)) {
    stop("Missing ", basename(src),
         ". Run Rscript R/02_clean_financials.R first.", call. = FALSE)
  }
  panel <- read_csv(src, show_col_types = FALSE, progress = FALSE)

  logline(""); logline(strrep("-", 78)); logline(freq); logline(strrep("-", 78))
  logline("  panel in: ", nrow(panel), " rows, ",
          sprintf("%.1f%%", 100 * mean(is.na(panel))), " unreported")

  core  <- intersect(CORE, names(panel))
  ids   <- intersect(KEEP_IDS, names(panel))
  flags <- intersect(KEEP_FLAGS, names(panel))
  if (length(core) < length(CORE)) {
    logline("  WARNING: core columns absent: ",
            paste(setdiff(CORE, names(panel)), collapse = ", "))
  }

  out <- panel |> select(all_of(c(ids, core, flags)))

  # --- DECISION 1: treat revenue recorded as exactly 0 as not reported -----
  # Script 02 flags these rather than altering them, because reading 0 as
  # "unreported" is an interpretation. It is applied here. A listed company
  # with exactly zero revenue is implausible, and leaving the 0 admits rows
  # whose every margin is meaningless.
  if (isTRUE(CFG$zero_revenue_to_na) && "total_revenue" %in% names(out)) {
    n_zero <- sum(out$total_revenue == 0, na.rm = TRUE)
    out <- out |>
      mutate(total_revenue = if_else(total_revenue == 0, NA_real_, total_revenue))
    logline("  DECISION 1: reinterpreted ", n_zero,
            " total_revenue == 0 values as not reported")
  } else {
    logline("  DECISION 1: skipped. total_revenue == 0 kept as a literal zero.")
  }

  # --- DECISION 2: drop rows missing a core aggregate ----------------------
  # Not imputation. A row without total_revenue has no revenue figure, and
  # inventing one would fabricate a company.
  n0 <- nrow(out)
  out <- out |> filter(if_all(all_of(core), ~ !is.na(.x)))
  logline("  DECISION 2: dropped ", n0 - nrow(out),
          " rows missing >=1 of ", length(core), " core aggregates")
  logline("              ", nrow(out), " rows remain, 0 values imputed")

  # --- DECISION 3: optional line items, off by default --------------------
  filled_cols <- character(0)
  if (isTRUE(CFG$impute_absent_as_zero)) {
    opt <- intersect(OPTIONAL, names(panel))
    add <- panel |> select(ticker, period_end, all_of(opt))
    out <- out |> left_join(add, by = c("ticker", "period_end"))

    n_fill <- sum(is.na(out[opt]))
    out <- out |> mutate(across(all_of(opt), ~ coalesce(.x, 0)))

    # Variance gate. A column that was 91% unreported becomes 91% zero: a
    # constant with noise, useless as a feature and misleading because it
    # looks dense. Those keep only the fact, as a binary indicator.
    share <- vapply(opt, function(c) mean(out[[c]] != 0), numeric(1))
    degen <- names(share)[share < CFG$min_nonzero_share]
    filled_cols <- setdiff(opt, degen)

    logline("  DECISION 3: filled ", n_fill, " absent optional cells with 0")
    if (length(degen) > 0) {
      logline("              under ",
              sprintf("%.0f%%", 100 * CFG$min_nonzero_share),
              " non-zero after filling, reduced to has_* indicators:")
      for (c in degen) {
        logline("                ", sprintf("%-34s %4.1f%% non-zero",
                                            c, 100 * share[[c]]))
      }
      out <- out |>
        mutate(across(all_of(degen), ~ .x != 0, .names = "has_{.col}")) |>
        select(-all_of(degen))
    }
    out <- out |>
      mutate(n_filled = rowSums(across(all_of(filled_cols), ~ .x == 0)))
    logline("              median filled cells per row: ",
            median(out$n_filled))
  } else {
    logline("  DECISION 3: skipped. Optional line items excluded, so nothing")
    logline("              is imputed anywhere in this table. Set")
    logline("              CFG$impute_absent_as_zero <- TRUE to include them.")
  }

  # --- DECISION 4: derived ratios -----------------------------------------
  # Guarded denominators. NA here means "denominator too small to yield a
  # meaningful percentage", which is different from a missing input.
  #
  # TWO floors, deliberately. Margins divide by revenue and use
  # CFG$min_revenue_denom ($10M). Balance-sheet ratios divide by liabilities,
  # equity or assets and keep CFG$min_denominator ($1M), because a small
  # balance sheet is normal and blanking those would cost real observations.
  out <- out |>
    mutate(
      gross_margin     = safe_ratio(gross_profit, total_revenue,
                                    CFG$min_revenue_denom),
      operating_margin = safe_ratio(operating_income, total_revenue,
                                    CFG$min_revenue_denom),
      net_margin       = safe_ratio(net_income, total_revenue,
                                    CFG$min_revenue_denom),
      ocf_margin       = safe_ratio(total_cash_from_operating_activities,
                                    total_revenue, CFG$min_revenue_denom),
      current_ratio    = safe_ratio(total_current_assets, total_current_liabilities),
      debt_to_equity   = safe_ratio(total_liab, total_stockholder_equity),
      asset_turnover   = safe_ratio(total_revenue, total_assets),
      # Pre-tax income crosses zero constantly, so a revenue-sized floor is
      # useless here: without this guard the annual panel produced a rate of
      # 1,383 and the quarterly panel one of -4,925.
      effective_tax    = {
        r <- ifelse(income_before_tax < CFG$min_pretax_income,
                    NA_real_, income_tax_expense / income_before_tax)
        ifelse(!is.na(r) & (r < CFG$tax_rate_bounds[1] |
                            r > CFG$tax_rate_bounds[2]), NA_real_, r)
      },

      # A revenue floor cannot fix a company whose P&L is an order of
      # magnitude larger than its revenue line. Two different situations
      # produce this, and both make a margin meaningless:
      #
      #   1. Holding companies. LBRDA and LBRDK are Liberty Broadband,
      #      GLIBA is GCI Liberty. Income comes from equity-method stakes,
      #      not operations. LBRDA 2017: $13.1M revenue, $2.03B net income,
      #      net margin 155.3. It clears any plausible revenue floor,
      #      because $13.1M is a perfectly normal amount of revenue.
      #
      #   2. Loss-making small caps, mostly development-stage biotech,
      #      burning many times their revenue. Same arithmetic, opposite
      #      sign.
      #
      # Both are correct filings. Neither is comparable on margin. The test
      # is symmetric because the problem is one of scale, not of sign.
      #
      # TRUE on 861 annual rows (5.5%). Marked, never removed: exclude with
      # !margin_unreliable before any margin benchmark, and say in the
      # write-up that you did.
      #
      # Measured effect of the floor plus this exclusion, annual net margin:
      #   before        min -257.66   p1 -16.06   median 0.049   max 155.34
      #   after         min   -4.98   p1  -2.46   median 0.055   max   4.83
      # The median barely moves, which is the evidence that this removes
      # noise rather than signal.
      margin_unreliable = !is.na(net_income) & !is.na(total_revenue) &
                          abs(net_income) > 5 * abs(total_revenue)
    )

  ratios <- c("gross_margin", "operating_margin", "net_margin", "ocf_margin",
              "current_ratio", "debt_to_equity", "asset_turnover",
              "effective_tax")
  logline("  DECISION 4: derived ", length(ratios), " ratios. NA counts:")
  for (r in ratios) {
    logline("                ", sprintf("%-18s %5d", r, sum(is.na(out[[r]]))))
  }
  logline("              margin floor CFG$min_revenue_denom = ",
          format(CFG$min_revenue_denom, big.mark = ",", scientific = FALSE),
          "; balance-sheet floor CFG$min_denominator = ",
          format(CFG$min_denominator, big.mark = ",", scientific = FALSE))
  logline("  DECISION 4b: margin_unreliable TRUE on ",
          sum(out$margin_unreliable),
          " rows (|net income| > 5x revenue). Marked, not removed.")
  logline("              Holding companies and loss-making small caps.")
  logline("              Exclude with !margin_unreliable before benchmarking.")

  # --- DECISION 5: winsorizing, off by default ----------------------------
  if (!is.null(CFG$winsor_probs)) {
    out <- out |> mutate(across(all_of(ratios), winsorize, .names = "{.col}_w"))
    logline("  DECISION 5: added winsorized *_w variants at ",
            paste(CFG$winsor_probs, collapse = "/"))
  } else {
    logline("  DECISION 5: skipped. Outliers left intact. Set")
    logline("              CFG$winsor_probs <- c(0.01, 0.99) to clamp them.")
  }

  # Verify the promise: no nulls among the source columns of this table.
  hard <- c(core, filled_cols)
  stopifnot(sum(is.na(out[hard])) == 0)
  logline("  VERIFIED: 0 nulls across ", length(hard), " source columns")

  # Report the errors this table still contains, so the count appears in the
  # log rather than only in whatever audit someone runs later.
  if (length(flags) > 0) {
    out <- out |> mutate(across(all_of(flags), ~ coalesce(.x, FALSE)))
    raised <- flags[vapply(flags, function(f) any(out[[f]]), logical(1))]
    if (length(raised) > 0) {
      logline("  ERRORS CARRIED THROUGH (flags retained, rows not filtered):")
      for (f in raised) {
        logline("    ", sprintf("%-28s %6d rows", f, sum(out[[f]])))
      }
      logline("    Filter these yourself if your analysis requires it.")
    }
  }

  out <- out |> arrange(ticker, period_end)
  dest <- file.path(PATHS$clean, sprintf("fin_analysis_%s.csv", freq))
  write_csv(out, dest)
  logline("  wrote ", nrow(out), " rows x ", ncol(out), " cols -> ", basename(dest))

  # Balanced panel, for anything comparing companies across equal periods.
  mx <- out |> count(ticker) |> pull(n) |> max()
  bal <- out |> group_by(ticker) |> filter(n() == mx) |> ungroup()
  write_csv(bal, file.path(PATHS$clean,
            sprintf("fin_analysis_%s_balanced.csv", freq)))
  logline("  balanced (", mx, " periods): ", nrow(bal), " rows, ",
          n_distinct(bal$ticker), " tickers")

  list(all = out, balanced = bal)
}

a <- build("annual")
q <- build("quarterly")

logline(""); logline(strrep("=", 78)); logline("SUMMARY"); logline(strrep("=", 78))
logline("fin_analysis_annual             ", nrow(a$all), " rows, ",
        n_distinct(a$all$ticker), " tickers")
logline("fin_analysis_annual_balanced    ", nrow(a$balanced), " rows")
logline("fin_analysis_quarterly          ", nrow(q$all), " rows, ",
        n_distinct(q$all$ticker), " tickers")
logline("fin_analysis_quarterly_balanced ", nrow(q$balanced), " rows")
logline("")
logline("Reproducibility: this output is a function of the CFG parameters")
logline("logged at the top of this file. Change one and rerun to see the cost.")

close(log_con)
