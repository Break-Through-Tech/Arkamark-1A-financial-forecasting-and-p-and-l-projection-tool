"""
Arkamark 1A - Exploratory Data Analysis
=======================================

A guided tour of the cleaned financial statement data, in Python.

    pip install pandas matplotlib numpy
    python eda.py

Run it from the repo root. It reads data/clean/fin_analysis_annual.csv,
saves nine charts into reports/figures/, and writes reports/eda_python.md.

WHAT THIS IS FOR
----------------
This is the teaching version of the EDA. Every section prints an explanation
of what the chart shows and what it means for our project, so you can read the
output instead of interpreting the charts yourself.

If you have never opened this dataset before, run this first.

WHY PYTHON WHEN THE PIPELINE IS R
---------------------------------
The R pipeline produces the data. This script only reads it. Nothing here
modifies, cleans or writes back to data/clean/ - it is read-only by design, so
you cannot break the pipeline by running it or editing it.
"""

from __future__ import annotations

import os
import sys
import textwrap

import matplotlib
matplotlib.use("Agg")  # no display needed; we only save files
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

DATA = os.path.join("data", "clean", "fin_analysis_annual.csv")
PANEL = os.path.join("data", "clean", "fin_panel_annual.csv")
FIGDIR = os.path.join("reports", "figures")
REPORT = os.path.join("reports", "eda_python.md")

# Colors. Checked for colorblind separation, so please do not swap them for
# a default matplotlib cycle.
BLUE, ORANGE, GREEN, RED = "#2a78d6", "#eb6834", "#1baf7a", "#d03b3b"
INK, MUTED, GRID = "#11141a", "#848b96", "#e8eaee"

plt.rcParams.update({
    "figure.dpi": 130,
    "savefig.dpi": 130,
    "savefig.bbox": "tight",
    "font.size": 9,
    "font.family": "sans-serif",
    "axes.edgecolor": MUTED,
    "axes.labelcolor": INK,
    "axes.titlesize": 11,
    "axes.titleweight": "semibold",
    "axes.titlecolor": INK,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "text.color": INK,
    "xtick.color": MUTED,
    "ytick.color": MUTED,
    "grid.color": GRID,
    "figure.facecolor": "white",
    "axes.facecolor": "white",
})

_report_lines: list[str] = []
_section_no = 0


def say(text: str) -> None:
    """Print a wrapped paragraph to the console and record it for the report."""
    clean = " ".join(text.split())
    print(textwrap.fill(clean, width=78))
    print()
    _report_lines.append(clean + "\n")


def section(title: str) -> None:
    global _section_no
    _section_no += 1
    head = f"{_section_no}. {title}"
    print("\n" + "=" * 78)
    print(head.upper())
    print("=" * 78)
    _report_lines.append(f"\n## {head}\n")


def save(fig, name: str, caption: str = "") -> None:
    """Save a figure and note it in the report."""
    os.makedirs(FIGDIR, exist_ok=True)
    path = os.path.join(FIGDIR, name)
    fig.savefig(path)
    plt.close(fig)
    print(f"   [saved] {path}")
    rel = os.path.join("figures", name)
    _report_lines.append(f"\n![{caption or name}]({rel})\n")
    if caption:
        _report_lines.append(f"*{caption}*\n")


def bar_labels(ax, bars, fmt="{:,.0f}", pad=3):
    """Put the value on top of each bar. Charts should be readable without
    counting gridlines."""
    for b in bars:
        h = b.get_height()
        ax.annotate(fmt.format(h), (b.get_x() + b.get_width() / 2, h),
                    ha="center", va="bottom", xytext=(0, pad),
                    textcoords="offset points", fontsize=8, color=INK)


# ---------------------------------------------------------------------------
# Load
# ---------------------------------------------------------------------------

def load():
    if not os.path.exists(DATA):
        sys.exit(
            f"Cannot find {DATA}\n\n"
            "Run this from the repo root, and generate the data first:\n"
            "  Rscript R/02_clean_financials.R\n"
            "  Rscript R/03_tidy_long.R\n"
            "  Rscript R/04_analysis_prep.R"
        )
    df = pd.read_csv(DATA, parse_dates=["period_end"], low_memory=False)
    # The flag columns come out of R as TRUE/FALSE strings sometimes.
    for c in [c for c in df.columns if c.startswith("flag_")] + ["margin_unreliable"]:
        if c in df.columns and df[c].dtype == object:
            df[c] = df[c].astype(str).str.upper().isin(["TRUE", "T", "1"])
    return df


FLAGS = [
    "flag_bs_identity", "flag_negative_equity", "flag_implausible_revenue",
    "flag_period_gap", "flag_negative_revenue", "flag_gp_identity",
    "flag_negative_cogs", "flag_gp_exceeds_rev",
]


def clean_subset(df):
    """The rows safe to benchmark on: no error flags, no unreliable margins.

    This is the filter to use in your own analysis. It is not applied to the
    file itself, because deleting rows is a choice each analysis makes for
    itself.
    """
    keep = ~df["margin_unreliable"]
    for f in FLAGS:
        if f in df.columns:
            keep &= ~df[f]
    return df[keep]


# ---------------------------------------------------------------------------
# Sections
# ---------------------------------------------------------------------------

def s_orientation(df):
    section("What am I looking at")
    say("""This file is one row per company per fiscal year. It is NOT Arkamark
        data. Arkamark has given us none. These are filed financial statements
        for real listed companies from a public Kaggle dataset, standing in
        until Arkamark's own figures arrive. ACN is Accenture, AZO is
        AutoZone. Anything we find here is true about those companies and says
        nothing about Arkamark without an argument that they are comparable.""")
    say(f"""The file has {len(df):,} rows covering {df['ticker'].nunique():,}
        companies and {df.shape[1]} columns. Every money figure is in whole US
        dollars, so 4202000000 means $4.2 billion.""")

    g = clean_subset(df)
    say(f"""{len(g):,} of those rows ({100 * len(g) / len(df):.0f}%) survive
        the recommended filter, which drops rows carrying an error flag or
        marked margin_unreliable. Use that subset for anything you plan to
        report.""")

    print(df[["ticker", "fiscal_year", "total_revenue", "gross_margin",
              "operating_margin"]].head(5).to_string(index=False))
    print()


def s_coverage(df):
    section("How much history do we have")
    counts = df["fiscal_year"].value_counts().sort_index()
    per_co = df.groupby("ticker").size().value_counts().sort_index()

    fig, (a1, a2) = plt.subplots(1, 2, figsize=(10, 3.4))
    b = a1.bar(counts.index.astype(str), counts.values, color=BLUE, width=.65)
    bar_labels(a1, b)
    a1.set_title("Rows per fiscal year")
    a1.set_ylim(0, counts.max() * 1.18)
    a1.tick_params(axis="x", rotation=45)

    b2 = a2.bar([f"{i}" for i in per_co.index], per_co.values, color=GREEN, width=.65)
    bar_labels(a2, b2)
    a2.set_title("Companies by number of years reported")
    a2.set_xlabel("fiscal years present")
    a2.set_ylim(0, per_co.max() * 1.18)
    fig.tight_layout()
    save(fig, "01_coverage.png", "Coverage: four years, and that is the ceiling.")

    top = per_co.idxmax()
    say(f"""{per_co.max():,} of {df['ticker'].nunique():,} companies have
        exactly {top} fiscal years. Nothing has more.""")
    say("""THIS IS THE BIGGEST CONSTRAINT ON THE PROJECT. The brief asks for a
        two-year forecast. You cannot fit a time-series model per company on
        four points. Whatever we build has to pool information across
        companies, or forecast at an aggregate level, or both. Say this out
        loud in the presentation rather than letting a reviewer find it.""")
    say("""The small counts at either end are fiscal years that end in odd
        months rather than December. Exclude them from year-on-year
        comparisons.""")


def s_size(df):
    section("How big are these companies")
    rev = df.loc[df["total_revenue"] > 0, "total_revenue"]

    fig, ax = plt.subplots(figsize=(7.5, 3.4))
    ax.hist(np.log10(rev), bins=45, color=BLUE, edgecolor="white", linewidth=.4)
    ax.set_title("Distribution of annual revenue")
    ax.set_xlabel("revenue (log scale)")
    ax.set_ylabel("company-years")
    ticks = [5, 6, 7, 8, 9, 10, 11, 12]
    ax.set_xticks(ticks)
    ax.set_xticklabels(["$100K", "$1M", "$10M", "$100M", "$1B", "$10B", "$100B", "$1T"])
    ax.axvline(np.log10(rev.median()), color=RED, linestyle="--", linewidth=1.3)
    ax.annotate(f"median ${rev.median() / 1e6:,.0f}M",
                (np.log10(rev.median()), ax.get_ylim()[1] * .92),
                color=RED, fontsize=8, ha="left", xytext=(6, 0),
                textcoords="offset points")
    ax.grid(axis="y", linewidth=.6)
    ax.set_axisbelow(True)
    save(fig, "02_revenue.png", "Revenue on a log scale. The raw scale is unreadable.")

    say(f"""Revenue runs from under a million dollars to
        ${rev.max() / 1e9:,.0f} billion. The median company-year books
        ${rev.median() / 1e6:,.0f} million.""")
    say("""WHY THE LOG SCALE. On a normal axis every bar would be crushed
        against zero by a handful of giants. Taking log10 turns 'ten times
        bigger' into 'one step right', which is the only way a distribution
        spanning six orders of magnitude is readable. Use a log scale whenever
        your data spans orders of magnitude, and always label the ticks in
        real units like this rather than leaving them as 6, 7, 8.""")
    say("""This spread is also why a single pooled average is meaningless here,
        and why the pipeline refuses to compute a margin when revenue is tiny.""")


def s_missing(df):
    section("Where the blanks are")
    miss = (df.isna().mean() * 100).sort_values(ascending=False)
    miss = miss[miss > 0]

    fig, ax = plt.subplots(figsize=(7.5, max(2.2, .38 * len(miss) + 1)))
    bars = ax.barh(miss.index[::-1], miss.values[::-1], color=ORANGE, height=.62)
    for b, v in zip(bars, miss.values[::-1]):
        ax.annotate(f"{v:.1f}%", (v, b.get_y() + b.get_height() / 2),
                    va="center", xytext=(4, 0), textcoords="offset points",
                    fontsize=8, color=INK)
    ax.set_title("Percent missing, columns with any blanks")
    ax.set_xlim(0, miss.max() * 1.2)
    ax.set_xlabel("% of rows")
    save(fig, "03_missing.png", "All blanks sit in derived ratios, never in raw figures.")

    say(f"""{df.shape[1] - len(miss)} of {df.shape[1]} columns have no blanks
        whatsoever: every raw financial figure, every flag, every key. All the
        blanks are in the {len(miss)} derived ratio columns.""")
    say("""THE IMPORTANT IDEA. A blank ratio here is a refusal to divide, not a
        missing input. Every input to a blank margin is present in the same
        row. The pipeline declines to divide when the denominator is too small
        to produce a meaningful percentage, because a margin computed on
        $40,000 of revenue is noise with a percent sign on it.""")
    if "effective_tax" in miss.index:
        say(f"""effective_tax is the extreme case at {miss['effective_tax']:.1f}%.
            Roughly three quarters of those blanks are companies that lost
            money that year, and a tax rate on a loss is meaningless. Do not
            describe this column as 'missing data' in the write-up. Describe it
            as not applicable.""")
    say("""DO NOT fill these with a mean or a median. In financial statements a
        blank usually means the line item does not apply to that company.
        Filling it invents a company that does not exist.""")


def s_flags(df):
    section("What the error flags caught")
    counts = pd.Series({f: int(df[f].sum()) for f in FLAGS if f in df.columns})
    counts = counts.sort_values()
    n_flags = df[[f for f in FLAGS if f in df.columns]].sum(axis=1)

    fig, (a1, a2) = plt.subplots(1, 2, figsize=(10.5, 3.6),
                                 gridspec_kw={"width_ratios": [1.6, 1]})
    bars = a1.barh(counts.index, counts.values, color=RED, height=.62)
    for b, v in zip(bars, counts.values):
        a1.annotate(f"{v:,}", (v, b.get_y() + b.get_height() / 2), va="center",
                    xytext=(4, 0), textcoords="offset points", fontsize=8, color=INK)
    a1.set_title("Rows carrying each flag")
    a1.set_xlim(0, counts.max() * 1.25)

    dist = n_flags.value_counts().sort_index()
    b2 = a2.bar(dist.index.astype(str), dist.values, color=BLUE, width=.6)
    bar_labels(a2, b2)
    a2.set_title("Flags per row")
    a2.set_xlabel("number of flags")
    a2.set_ylim(0, dist.max() * 1.18)
    fig.tight_layout()
    save(fig, "04_flags.png", "Flagged rows are marked and kept, never deleted.")

    say(f"""{dist.get(0, 0):,} rows carry no flag at all. The rest carry one or
        more. Nothing is deleted: the cleaning layer marks problems and leaves
        the decision to you, because deleting rows is invisible and permanent
        and you may be asking a different question than the person who
        cleaned.""")
    say("""TWO OF THESE ARE NOT ERRORS. flag_negative_equity describes a real
        financial condition, normal in heavily leveraged companies.
        flag_implausible_revenue is a judgement about whether shells belong in
        your sample. The other six are arithmetic that cannot be true, like
        gross profit exceeding revenue.""")
    if "flag_bs_identity" in counts.index:
        by_year = df.groupby("fiscal_year")["flag_bs_identity"].mean() * 100
        stable = by_year[by_year.index.isin([2016, 2017, 2018, 2019])]
        say(f"""UNEXPLAINED, AND UNCLAIMED. flag_bs_identity fires on
            {counts['flag_bs_identity']:,} rows. Assets do not equal
            liabilities plus equity. The rate is flat across years
            ({', '.join(f'{v:.1f}%' for v in stable)}), which points at a
            convention in the source data rather than an event. Nobody has
            checked whether it clusters by size or company type. This is a
            finding sitting unclaimed in our own output.""")


def s_margins(df):
    section("What a normal margin looks like")
    g = clean_subset(df)

    fig, axes = plt.subplots(1, 2, figsize=(10.5, 3.6))
    for ax, col, color, lo, hi, label in [
        (axes[0], "gross_margin", BLUE, -0.5, 1.0, "Gross margin"),
        (axes[1], "operating_margin", ORANGE, -1.0, 0.6, "Operating margin"),
    ]:
        v = g[col].dropna().clip(lo, hi)
        ax.hist(v, bins=36, color=color, edgecolor="white", linewidth=.4)
        med = g[col].median()
        ax.axvline(med, color=INK, linestyle="--", linewidth=1.3)
        ax.annotate(f"median {med:.1%}", (med, ax.get_ylim()[1] * .93),
                    fontsize=8, ha="left", xytext=(5, 0), textcoords="offset points")
        ax.set_title(label)
        ax.set_xlabel("share of revenue")
        ax.xaxis.set_major_formatter(lambda x, _: f"{x:.0%}")
        ax.grid(axis="y", linewidth=.6)
        ax.set_axisbelow(True)
    axes[0].set_ylabel("company-years")
    fig.tight_layout()
    save(fig, "05_margins.png", "Clean subset. End bars include everything beyond the axis.")

    say(f"""On the clean subset the median company keeps
        {g['gross_margin'].median():.1%} of revenue after direct costs, and
        {g['operating_margin'].median():.1%} after all operating costs.""")
    say(f"""ALWAYS REPORT THE MEDIAN HERE, NOT THE MEAN. On the clean subset
        the gross margin mean is {g['gross_margin'].mean():.1%} against a
        median of {g['gross_margin'].median():.1%}. Both distributions have a
        long left tail of loss-makers that drags a mean around. On the
        UNFILTERED table a mean is off by orders of magnitude.""")
    say("""The pile-up at 100% gross margin is not an error. It is the
        companies reporting zero cost of revenue: banks, insurers, REITs and
        some software firms. They genuinely have no COGS line. Exclude them
        before benchmarking a services firm.""")


def s_size_effect(df):
    section("The finding: margins move with company size")
    g = clean_subset(df).copy()
    edges = [1e7, 1e8, 1e9, 1e10, 1e15]
    labels = ["$10M-100M", "$100M-1B", "$1B-10B", "over $10B"]
    g["band"] = pd.cut(g["total_revenue"], bins=edges, labels=labels, right=False)
    tab = g.groupby("band", observed=True).agg(
        n=("ticker", "size"),
        gross=("gross_margin", "median"),
        operating=("operating_margin", "median"),
    ).dropna()

    x = np.arange(len(tab))
    fig, ax = plt.subplots(figsize=(7.5, 3.6))
    b1 = ax.bar(x - .19, tab["gross"], .36, label="Gross margin", color=BLUE)
    b2 = ax.bar(x + .19, tab["operating"], .36, label="Operating margin", color=ORANGE)
    bar_labels(ax, b1, "{:.1%}")
    bar_labels(ax, b2, "{:.1%}")
    ax.set_xticks(x, tab.index.astype(str))
    ax.set_title("Median margin by revenue band")
    ax.set_ylabel("share of revenue")
    ax.yaxis.set_major_formatter(lambda v, _: f"{v:.0%}")
    ax.set_ylim(0, max(tab["gross"]) * 1.25)
    ax.legend(frameon=False, loc="upper right")
    ax.grid(axis="y", linewidth=.6)
    ax.set_axisbelow(True)
    save(fig, "06_size_effect.png", "Gross margin falls with size; operating margin rises.")

    print(tab.assign(
        gross=lambda d: (d["gross"] * 100).round(1),
        operating=lambda d: (d["operating"] * 100).round(1),
    ).to_string())
    print()
    say(f"""Gross margin falls from {tab['gross'].iloc[0]:.1%} to
        {tab['gross'].iloc[-1]:.1%} as companies get bigger, while operating
        margin rises from {tab['operating'].iloc[0]:.1%} to
        {tab['operating'].iloc[-1]:.1%}. They move in opposite directions.""")
    say("""WHY THIS MATTERS FOR US. Part of it is real operating leverage:
        overhead spread over more revenue. Part of it is composition, since
        smaller firms here are more often service and software businesses that
        report little or no cost of revenue. Either way, benchmarking a firm
        against the whole pool is wrong twice over, once for sector and once
        for size. This is the first result in the project that is an actual
        finding rather than data housekeeping.""")


def s_scatter(df):
    section("Size against profitability, one dot per company-year")
    g = clean_subset(df)
    sub = g[(g["total_revenue"] > 1e7) & g["operating_margin"].notna()]

    fig, ax = plt.subplots(figsize=(7.5, 4))
    ax.scatter(np.log10(sub["total_revenue"]), sub["operating_margin"].clip(-1, 1),
               s=5, alpha=.16, color=BLUE, linewidths=0)
    ax.axhline(0, color=MUTED, linewidth=.9)
    bins = np.arange(7, 12.5, .5)
    mids, meds = [], []
    for lo, hi in zip(bins[:-1], bins[1:]):
        m = sub[(np.log10(sub["total_revenue"]) >= lo) & (np.log10(sub["total_revenue"]) < hi)]
        if len(m) > 30:
            mids.append((lo + hi) / 2)
            meds.append(m["operating_margin"].median())
    ax.plot(mids, meds, color=ORANGE, linewidth=2.2, label="median by size", zorder=3)
    ax.scatter(mids, meds, color=ORANGE, s=22, zorder=4)
    ax.set_xticks([7, 8, 9, 10, 11, 12])
    ax.set_xticklabels(["$10M", "$100M", "$1B", "$10B", "$100B", "$1T"])
    ax.set_title("Operating margin against revenue")
    ax.set_xlabel("revenue (log scale)")
    ax.set_ylabel("operating margin")
    ax.yaxis.set_major_formatter(lambda v, _: f"{v:.0%}")
    ax.legend(frameon=False, loc="lower right")
    save(fig, "07_scatter.png", "Each dot is one company-year. Orange is the running median.")

    say("""HOW TO READ THIS. Each faint dot is one company in one year. With
        twelve thousand overlapping points a scatter turns into a smudge, so
        two things fix it: low opacity, which turns density into darkness, and
        the orange running median, which is the signal you actually want.""")
    say("""The spread narrows as revenue grows. Small companies range from
        heavy losses to high profits; large ones cluster in a tight band near
        ten percent. Big companies are more predictable, which is convenient,
        because forecasting is easier where variance is low.""")
    n_clip = int((sub["operating_margin"] < -1).sum())
    say(f"""THAT SOLID LINE OF DOTS ALONG THE BOTTOM is not a data artifact.
        It is {n_clip:,} company-years whose operating margin is worse than
        -100%, squashed onto the axis by the clip. Companies spending more than
        twice their revenue. They are real rows and they are all small. If we
        had not clipped, the y-axis would run to -800% and the rest of the
        chart would be an unreadable stripe. Clipping is the right call here,
        but say that you did it.""")


def s_comparables(df):
    section("Picking a peer group by hand")
    tickers = {
        "ACN": "Accenture", "CTSH": "Cognizant", "INFY": "Infosys",
        "EPAM": "EPAM Systems", "DXC": "DXC Technology", "LDOS": "Leidos",
        "BAH": "Booz Allen", "CACI": "CACI", "SAIC": "SAIC",
        "IT": "Gartner", "G": "Genpact", "ICFI": "ICF International",
        "EXLS": "ExlService", "WNS": "WNS Holdings",
    }
    g = clean_subset(df)
    rows = []
    for t, name in tickers.items():
        s = g[g["ticker"] == t]
        if len(s) and s["gross_margin"].notna().any():
            rows.append({
                "ticker": t, "company": name, "years": len(s),
                "revenue_bn": s["total_revenue"].median() / 1e9,
                "gross": s["gross_margin"].median(),
                "operating": s["operating_margin"].median(),
            })
    peers = pd.DataFrame(rows).sort_values("gross")
    if peers.empty:
        say("None of the chosen tickers survived the filter. Skipping.")
        return

    fig, ax = plt.subplots(figsize=(7.5, .34 * len(peers) + 1.6))
    y = np.arange(len(peers))
    ax.barh(y, peers["gross"], .58, color=BLUE, label="Gross margin")
    ax.scatter(peers["operating"], y, color=ORANGE, s=34, zorder=3,
               label="Operating margin")
    uni = g["gross_margin"].median()
    ax.axvline(uni, color=RED, linestyle="--", linewidth=1.2)
    ax.annotate(f"all companies {uni:.0%}", (uni, len(peers) - .3), color=RED,
                fontsize=8, ha="left", xytext=(4, 0), textcoords="offset points")
    ax.set_yticks(y, [f"{r.ticker}  {r.company}" for r in peers.itertuples()])
    ax.set_title("Professional services peers, median margins")
    ax.xaxis.set_major_formatter(lambda v, _: f"{v:.0%}")
    ax.legend(frameon=False, loc="lower right")
    ax.grid(axis="x", linewidth=.6)
    ax.set_axisbelow(True)
    save(fig, "08_peers.png", "Hand-picked peer group against the full universe.")

    print(peers.assign(
        revenue_bn=lambda d: d["revenue_bn"].round(2),
        gross=lambda d: (d["gross"] * 100).round(1),
        operating=lambda d: (d["operating"] * 100).round(1),
    ).to_string(index=False))
    print()
    say(f"""Peer median gross margin is {peers['gross'].median():.1%} against
        {uni:.1%} for the whole universe. Using the pooled number would
        overstate gross margin by about
        {abs(uni - peers['gross'].median()) * 100:.0f} percentage points.""")
    say("""WHY THIS IS HAND-PICKED. There is no sector, industry, SIC or
        country column anywhere in this source, so a peer group cannot be
        selected programmatically. These 14 tickers were chosen by eye. That is
        a weakness and it belongs in the limitations section. Somebody should
        validate the list against SIC codes from yfinance and write down the
        inclusion rule they used.""")


def s_cost_structure(df):
    section("Where each revenue dollar goes")
    if not os.path.exists(PANEL):
        say(f"Skipping: {PANEL} not found. Run Rscript R/02_clean_financials.R.")
        return
    p = pd.read_csv(PANEL, usecols=lambda c: c in {
        "ticker", "period_end", "selling_general_administrative"}, low_memory=False)
    p["period_end"] = pd.to_datetime(p["period_end"])
    g = clean_subset(df).merge(p, on=["ticker", "period_end"], how="left")
    g = g[(g["total_revenue"] > 0) & g["selling_general_administrative"].notna()]

    parts = pd.Series({
        "Cost of revenue": (g["cost_of_revenue"] / g["total_revenue"]).median(),
        "SG&A": (g["selling_general_administrative"] / g["total_revenue"]).median(),
        "Other operating": ((g["total_operating_expenses"] - g["cost_of_revenue"]
                             - g["selling_general_administrative"])
                            / g["total_revenue"]).median(),
    })

    fig, ax = plt.subplots(figsize=(7, 2.6))
    bars = ax.barh(parts.index[::-1], parts.values[::-1], .55,
                   color=[GREEN, ORANGE, BLUE])
    for b, v in zip(bars, parts.values[::-1]):
        ax.annotate(f"{v:.1%}", (v, b.get_y() + b.get_height() / 2), va="center",
                    xytext=(5, 0), textcoords="offset points", fontsize=9, color=INK)
    ax.set_xlim(0, parts.max() * 1.25)
    ax.set_title(f"Median share of revenue, n={len(g):,}")
    ax.xaxis.set_major_formatter(lambda v, _: f"{v:.0%}")
    save(fig, "09_cost_structure.png",
         "Independent medians. Shown as separate bars because they do not sum.")

    say(f"""Median cost of revenue is {parts['Cost of revenue']:.1%} of revenue,
        SG&A is {parts['SG&A']:.1%}, and the unexplained operating residual is
        {parts['Other operating']:.1%}. These three ratios are what the P&L
        engine needs.""")
    say(f"""WHY THREE BARS AND NOT A STACKED BAR. These are independent
        medians and they do not sum to 100%. The median company for cost of
        revenue is not the median company for SG&A. A stacked bar would imply
        they add up and would be wrong. This is a small honesty decision that
        reviewers notice.""")
    say("""The 'other operating' residual exists because total operating
        expenses do not decompose into COGS plus SG&A plus R&D on about half
        the rows. Carry it explicitly so the projected statement always ties
        out instead of quietly losing money.""")


def s_next():
    section("What to do with this")
    say("""FIVE OPEN ITEMS, none of them owned yet. Each is bounded and each
        produces something presentable.""")
    for i, (who, what) in enumerate([
        ("Evaluation", "Work out why the balance sheet fails on 13% of rows. "
                       "Check whether it clusters by size, year-end month or company type."),
        ("P&L engine", "Validate the hand-picked peer list against SIC codes "
                       "and write down the inclusion rule."),
        ("Data pipeline", "Write 05_audit_identities.R so the accounting "
                          "identity checks run on every build instead of ad hoc."),
        ("Modeling", "Defend or lower the $10M pretax floor on effective_tax. "
                     "Test $1M and $5M and pick one on evidence."),
        ("Forecasting", "Get the Favorita sales data into the repo. Without "
                        "train.csv there is no forecasting half of this project."),
    ], 1):
        line = f"  {i}. [{who}] {what}"
        print(textwrap.fill(" ".join(line.split()), width=78,
                            subsequent_indent="     "))
        _report_lines.append(f"{i}. **{who}** - {what}\n")
    print()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    df = load()
    _report_lines.append("# Arkamark 1A - EDA\n")
    _report_lines.append(
        f"Generated by `eda.py` on {pd.Timestamp.now():%Y-%m-%d %H:%M}. "
        "Read-only: this script never modifies `data/clean/`.\n")

    for fn in (s_orientation, s_coverage, s_size, s_missing, s_flags,
               s_margins, s_size_effect, s_scatter, s_comparables,
               s_cost_structure):
        fn(df)
    s_next()

    os.makedirs("reports", exist_ok=True)
    with open(REPORT, "w", encoding="utf-8") as fh:
        fh.write("\n".join(_report_lines))

    print("=" * 78)
    print(f"Charts  -> {FIGDIR}/")
    print(f"Write-up -> {REPORT}")
    print("=" * 78)


if __name__ == "__main__":
    main()
